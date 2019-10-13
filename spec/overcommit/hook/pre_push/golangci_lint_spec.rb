# frozen_string_literal: true

require 'spec_helper'

describe Overcommit::Hook::PrePush::GolangciLint do
  let(:config)  { Overcommit::ConfigurationLoader.default_configuration }
  let(:context) { double('context') }
  subject { described_class.new(config, context) }

  context 'when golangci-lint exits successfully' do
    let(:result) { double('result') }

    before do
      result.stub(success?: true, stderr: '', stdout: '')
      subject.stub(:execute).and_return(result)
    end

    it 'passes' do
      expect(subject).to pass
    end
  end

  context 'when golangci-lint exits unsucessfully' do
    let(:result) { double('result') }

    before do
      result.stub(:success?).and_return(false)
      subject.stub(:execute).and_return(result)
    end

    context 'when golangci-lint returns an error' do
      let(:error_message) do
        'pkg1/file1.go:8:6: exported type `Test` should have comment or be unexported (golint)'
      end

      before do
        result.stub(:stdout).and_return(error_message)
        result.stub(:stderr).and_return('')
      end

      it 'fails' do
        expect(subject).to fail_hook
      end

      it 'returns valid message' do
        message = subject.run.last
        expect(message).to eq error_message
      end
    end

    context 'when a generic error message is written to stderr' do
      let(:error_message) { 'golangci-lint: command not found' }
      before do
        result.stub(:stdout).and_return('')
        result.stub(:stderr).and_return(error_message)
      end

      it 'fails' do
        expect(subject).to fail_hook
      end

      it 'returns valid message' do
        message = subject.run.last
        expect(message).to eq error_message
      end
    end
  end
end
