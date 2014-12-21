require 'spec_helper'

describe Overcommit::Hook::PreCommit::Jscs do
  let(:config)  { Overcommit::ConfigurationLoader.default_configuration }
  let(:context) { double('context') }
  subject { described_class.new(config, context) }

  before do
    subject.stub(:applicable_files).and_return(%w[file1.js file2.js])
  end

  context 'when no configuration is found' do
    before do
      result = double('result')
      result.stub(:success? => false,
                  :status => 1,
                  :stderr => 'Configuration file some-path/.jscs.json was not found.')
      subject.stub(:execute).and_return(result)
    end

    it { should warn }
  end

  context 'when jscs exits unsucessfully' do
    let(:result) { double('result') }

    before do
      result.stub(:success? => false, :stderr => '', :status => 2)
      subject.stub(:execute).and_return(result)
    end

    context 'and it reports an error' do
      before do
        result.stub(:stdout).and_return([
          'file1.js: line 1, col 4, ruleName: Missing space after `if` keyword'
        ].join("\n"))

        subject.stub(:modified_lines_in_file).and_return([2, 3])
      end

      it { should fail_hook }
    end
  end
end
