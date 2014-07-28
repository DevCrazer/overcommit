module Overcommit::Hook::PreCommit
  # Runs `travis-lint` against any modified Travis CI files.
  class TravisLint < Base
    def run
      unless in_path?('travis-lint')
        return :warn, 'Run `gem install travis-lint`'
      end

      result = execute(%w[travis-lint] + applicable_files)
      return :pass if result.success?

      [:fail, result.stdout.strip]
    end
  end
end
