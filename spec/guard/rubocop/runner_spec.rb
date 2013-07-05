# coding: utf-8

require 'spec_helper.rb'

describe Guard::Rubocop::Runner do
  subject(:runner) { Guard::Rubocop::Runner.new(options) }
  let(:options) { {} }

  describe '#run' do
    subject { super().run(paths) }
    let(:paths) { ['spec/spec_helper.rb'] }

    before do
      runner.stub(:system)
    end

    it 'executes rubocop' do
      runner.should_receive(:system) do |*args|
        args.first.should == 'rubocop'
      end
      runner.run
    end

    context 'when RuboCop exited with 0 status' do
      before do
        runner.stub(:system).and_return(true)
      end
      it { should be_true }
    end

    context 'when RuboCop exited with non 0 status' do
      before do
        runner.stub(:system).and_return(false)
      end
      it { should be_false }
    end

    shared_examples 'notifies', :notifies do
      it 'notifies' do
        runner.should_receive(:notify)
        runner.run
      end
    end

    shared_examples 'does not notify', :does_not_notify do
      it 'does not notify' do
        runner.should_not_receive(:notify)
        runner.run
      end
    end

    shared_examples 'notification' do |expectations|
      context 'when passed' do
        before do
          runner.stub(:system).and_return(true)
        end

        if expectations[:passed]
          include_examples 'notifies'
        else
          include_examples 'does not notify'
        end
      end

      context 'when failed' do
        before do
          runner.stub(:system).and_return(false)
        end

        if expectations[:failed]
          include_examples 'notifies'
        else
          include_examples 'does not notify'
        end
      end
    end

    context 'when :notification option is true' do
      let(:options) { { notification: true } }
      include_examples 'notification', { passed: true, failed: true }
    end

    context 'when :notification option is :failed' do
      let(:options) { { notification: :failed } }
      include_examples 'notification', { passed: false, failed: true }
    end

    context 'when :notification option is false' do
      let(:options) { { notification: false } }
      include_examples 'notification', { passed: false, failed: false }
    end
  end

  describe '#build_command' do
    subject(:build_command) { runner.build_command(paths) }
    let(:options) { { cli: %w(--debug --rails) } }
    let(:paths) { %w(file1.rb file2.rb) }

    context 'when :cli option includes formatter for console' do
      let(:options) { { cli: %w(--format simple) } }

      it 'does not add args for the default formatter for console' do
        build_command[0..2].should_not == %w(rubocop --format progress)
      end
    end

    context 'when :cli option does not include formatter for console' do
      let(:options) { { cli: %w(--format simple --out simple.txt) } }

      it 'adds args for the default formatter for console' do
        build_command[0..2].should == %w(rubocop --format progress)
      end
    end

    it 'adds args for JSON formatter ' do
      build_command[3..4].should == %w(--format json)
    end

    it 'adds args for output file path of JSON formatter ' do
      build_command[5].should == '--out'
      build_command[6].should_not be_empty
    end

    it 'adds args specified by user' do
      build_command[7..8].should == %w(--debug --rails)
    end

    it 'adds the passed paths' do
      build_command[9..-1].should == %w(file1.rb file2.rb)
    end

    context 'when the value of :cli option is a string' do
      let(:options) { { cli: '--debug --rails' } }

      it 'handles' do
        build_command[7..8].should == %w(--debug --rails)
      end
    end
  end

  describe '#args_specified_by_user' do
    context 'when :cli option is nil' do
      let(:options) { { cli: nil } }

      it 'returns empty array' do
        runner.args_specified_by_user.should == []
      end
    end

    context 'when :cli option is an array' do
      let(:options) { { cli: ['--out', 'output file.txt'] } }

      it 'just returns the array' do
        runner.args_specified_by_user.should == ['--out', 'output file.txt']
      end
    end

    context 'when :cli option is a string' do
      let(:options) { { cli: '--out "output file.txt"' } }

      it 'returns an array from String#shellsplit' do
        runner.args_specified_by_user.should == ['--out', 'output file.txt']
      end
    end

    context 'when :cli option is other types' do
      let(:options) { { cli: { key: 'value' } } }

      it 'raises error' do
        expect { runner.args_specified_by_user }.to raise_error
      end
    end
  end

  describe '#include_formatter_for_console?' do
    subject(:include_formatter_for_console?) { runner.include_formatter_for_console?(args) }

    context 'when the passed args include a -f/--format' do
      context 'but does not include an -o/--output' do
        let(:args) { %w(--format simple --debug) }

        it 'returns true' do
          include_formatter_for_console?.should be_true
        end
      end

      context 'and include an -o/--output just after the -f/--format' do
        let(:args) { %w(--format simple --out simple.txt) }

        it 'returns false' do
          include_formatter_for_console?.should be_false
        end
      end

      context 'and include an -o/--output after the -f/--format across another arg' do
        let(:args) { %w(--format simple --debug --out simple.txt) }

        it 'returns false' do
          include_formatter_for_console?.should be_false
        end
      end
    end

    context 'when the passed args include multiple -f/--format' do
      context 'and all -f/--format have associated -o/--out' do
        let(:args) { %w(--format simple --out simple.txt --format emacs --out emacs.txt) }

        it 'returns false' do
          include_formatter_for_console?.should be_false
        end
      end

      context 'and any -f/--format has associated -o/--out' do
        let(:args) { %w(--format simple --format emacs --out emacs.txt) }

        it 'returns true' do
          include_formatter_for_console?.should be_true
        end
      end

      context 'and no -f/--format has associated -o/--out' do
        let(:args) { %w(--format simple --format emacs) }

        it 'returns true' do
          include_formatter_for_console?.should be_true
        end
      end
    end

    context 'when the passed args do not include -f/--format' do
      let(:args) { %w(--debug) }

      it 'returns false' do
        include_formatter_for_console?.should be_false
      end
    end
  end

  describe '#json_file_path' do
    it 'is not world readable' do
      File.world_readable?(runner.json_file_path).should be_false
    end
  end

  shared_context 'JSON file', :json_file do
    before do
      json = <<-END
        {
          "metadata": {
            "rubocop_version": "0.9.0",
            "ruby_engine": "ruby",
            "ruby_version": "2.0.0",
            "ruby_patchlevel": "195",
            "ruby_platform": "x86_64-darwin12.3.0"
          },
          "files": [{
              "path": "lib/foo.rb",
              "offences": []
            }, {
              "path": "lib/bar.rb",
              "offences": [{
                  "severity": "convention",
                  "message": "Line is too long. [81/79]",
                  "cop_name": "LineLength",
                  "location": {
                    "line": 546,
                    "column": 80
                  }
                }, {
                  "severity": "warning",
                  "message": "Unreachable code detected.",
                  "cop_name": "UnreachableCode",
                  "location": {
                    "line": 15,
                    "column": 9
                  }
                }
              ]
            }
          ],
          "summary": {
            "offence_count": 2,
            "target_file_count": 2,
            "inspected_file_count": 2
          }
        }
      END
      File.write(runner.json_file_path, json)
    end
  end

  describe '#result', :json_file do
    it 'parses JSON file' do
      runner.result[:summary][:offence_count].should == 2
    end
  end

  describe '#notify' do
    before do
      runner.stub(:result).and_return(
        {
          summary: {
            offence_count: 4,
            target_file_count: 3,
            inspected_file_count: 2
          }
        }
      )
    end

    it 'notifies summary' do
      Guard::Notifier.should_receive(:notify) do |message, options|
        message.should == '2 files inspected, 4 offences detected'
      end
      runner.notify(true)
    end

    it 'notifies with title "RuboCop results"' do
      Guard::Notifier.should_receive(:notify) do |message, options|
        options[:title].should == 'RuboCop results'
      end
      runner.notify(true)
    end

    context 'when passed' do
      it 'shows success image' do
        Guard::Notifier.should_receive(:notify) do |message, options|
          options[:image].should == :success
        end
        runner.notify(true)
      end
    end

    context 'when failed' do
      it 'shows failed image' do
        Guard::Notifier.should_receive(:notify) do |message, options|
          options[:image].should == :failed
        end
        runner.notify(false)
      end
    end
  end

  describe '#summary_text' do
    before do
      runner.stub(:result).and_return(
        {
          summary: {
            offence_count: offence_count,
            target_file_count: target_file_count,
            inspected_file_count: inspected_file_count
          }
        }
      )
    end

    subject(:summary_text) { runner.summary_text }

    let(:offence_count)        { 0 }
    let(:target_file_count)    { 0 }
    let(:inspected_file_count) { 0 }

    context 'when no files are inspected' do
      let(:inspected_file_count) { 0 }
      it 'includes "0 files"' do
        summary_text.should include '0 files'
      end
    end

    context 'when a file is inspected' do
      let(:inspected_file_count) { 1 }
      it 'includes "1 file"' do
        summary_text.should include '1 file'
      end
    end

    context 'when 2 files are inspected' do
      let(:inspected_file_count) { 2 }
      it 'includes "2 files"' do
        summary_text.should include '2 files'
      end
    end

    context 'when no offences are detected' do
      let(:offence_count) { 0 }
      it 'includes "no offences"' do
        summary_text.should include 'no offences'
      end
    end

    context 'when an offence is detected' do
      let(:offence_count) { 1 }
      it 'includes "1 offence"' do
        summary_text.should include '1 offence'
      end
    end

    context 'when 2 offences are detected' do
      let(:offence_count) { 2 }
      it 'includes "2 offences"' do
        summary_text.should include '2 offences'
      end
    end
  end

  describe '#failed_paths', :json_file do
    it 'returns file paths which have offences' do
      runner.failed_paths.should == ['lib/bar.rb']
    end
  end
end
