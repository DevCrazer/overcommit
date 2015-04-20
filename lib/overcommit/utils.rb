require 'pathname'
require 'overcommit/subprocess'

module Overcommit
  # Utility functions for general use.
  module Utils
    # Helper class for doing quick constraint validations on version numbers.
    #
    # This allows us to execute code based on the git version.
    class Version < Gem::Version
      # Overload comparison operators so we can conveniently compare this
      # version directly to a string in code.
      %w[< <= > >= == !=].each do |operator|
        define_method operator do |version|
          case version
          when String
            super(Gem::Version.new(version))
          else
            super(version)
          end
        end
      end
    end

    class << self
      def script_path(script)
        File.join(Overcommit::HOME, 'libexec', script)
      end

      # Returns an absolute path to the root of the repository.
      #
      # We do this ourselves rather than call `git rev-parse --show-toplevel` to
      # solve an issue where the .git directory might not actually be valid in
      # tests.
      #
      # @return [String]
      def repo_root
        @repo_root ||=
          begin
            git_dir = Pathname.new(File.expand_path('.')).enum_for(:ascend).find do |path|
              File.exist?(File.join(path, '.git'))
            end

            unless git_dir
              raise Overcommit::Exceptions::InvalidGitRepo, 'no .git directory found'
            end

            git_dir.to_s
          end
      end

      # Returns an absolute path to the .git directory for a repo.
      #
      # @param repo_dir [String] root directory of git repo
      # @return [String]
      def git_dir(repo_dir = repo_root)
        @git_dir ||=
          begin
            git_dir = File.expand_path('.git', repo_dir)

            # .git could also be a file that contains the location of the git directory
            unless File.directory?(git_dir)
              git_dir = File.read(git_dir)[/^gitdir: (.*)$/, 1]

              # Resolve relative paths
              unless git_dir.start_with?('/')
                git_dir = File.expand_path(git_dir, repo_dir)
              end
            end

            git_dir
          end
      end

      # Shamelessly stolen from:
      # stackoverflow.com/questions/1509915/converting-camel-case-to-underscore-case-in-ruby
      def snake_case(str)
        str.gsub(/::/, '/').
            gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
            gsub(/([a-z\d])([A-Z])/, '\1_\2').
            tr('-', '_').
            downcase
      end

      # Converts a string containing underscores/hyphens/spaces into CamelCase.
      def camel_case(str)
        str.split(/_|-| /).map { |part| part.sub(/^\w/) { |c| c.upcase } }.join
      end

      # Returns a list of supported hook types (pre-commit, commit-msg, etc.)
      def supported_hook_types
        Dir[File.join(HOOK_DIRECTORY, '*')].
          select { |file| File.directory?(file) }.
          reject { |file| File.basename(file) == 'shared' }.
          map { |file| File.basename(file).gsub('_', '-') }
      end

      # Returns a list of supported hook classes (PreCommit, CommitMsg, etc.)
      def supported_hook_type_classes
        supported_hook_types.map do |file|
          file.split('-').map(&:capitalize).join
        end
      end

      # @param cmd [String]
      # @return [true,false] whether a command can be found given the current
      #   environment path.
      def in_path?(cmd)
        # ENV['PATH'] doesn't include the repo root, but that is a valid
        # location for executables, so we want to add it to the list of places
        # we are checking for the executable.
        paths = [repo_root] + ENV['PATH'].split(File::PATH_SEPARATOR)
        exts  = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        paths.each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return true if File.executable?(exe)
          end
        end
        false
      end

      # Return the parent command that triggered this hook run
      def parent_command
        `ps -ocommand= -p #{Process.ppid}`.chomp
      end

      # Execute a command in a subprocess, capturing exit status and output from
      # both standard and error streams.
      #
      # This is intended to provide a centralized place to perform any checks or
      # filtering of the command before executing it.
      #
      # @param args [Array<String>]
      # @return [Overcommit::Subprocess::Result] status, stdout, and stderr
      def execute(args)
        if args.include?('|')
          raise Overcommit::Exceptions::InvalidCommandArgs,
                'Cannot pipe commands with the `execute` helper'
        end

        Subprocess.spawn(args)
      end

      # Execute a command in a subprocess, returning immediately.
      #
      # This provides a convenient way to execute long-running processes for
      # which we do not need to know the result.
      #
      # @param args [Array<String>]
      # @return [ChildProcess] detached process spawned in the background
      def execute_in_background(args)
        if args.include?('|')
          raise Overcommit::Exceptions::InvalidCommandArgs,
                'Cannot pipe commands with the `execute_in_background` helper'
        end

        Subprocess.spawn_detached(args)
      end

      # Calls a block of code with a modified set of environment variables,
      # restoring them once the code has executed.
      def with_environment(env)
        old_env = {}
        env.each do |var, value|
          old_env[var] = ENV[var.to_s]
          ENV[var.to_s] = value
        end

        yield
      ensure
        old_env.each { |var, value| ENV[var.to_s] = value }
      end

      # Returns whether a file is a broken symlink.
      #
      # @return [true,false]
      def broken_symlink?(file)
        # JRuby's implementation of File.exist? returns true for broken
        # symlinks, so we need use File.size?
        File.symlink?(file) && File.size?(file).nil?
      end

      # Convert a glob pattern to an absolute path glob pattern rooted from the
      # repository root directory.
      #
      # @param glob [String]
      # @return [String]
      def convert_glob_to_absolute(glob)
        File.join(repo_root, glob)
      end

      # Return whether a pattern matches the given path.
      #
      # @param pattern [String]
      # @param path [String]
      def matches_path?(pattern, path)
        File.fnmatch?(pattern, path,
                      File::FNM_PATHNAME | # Wildcard doesn't match separator
                      File::FNM_DOTMATCH   # Wildcards match dotfiles
        )
      end
    end
  end
end
