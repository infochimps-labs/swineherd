require 'spec_helper'
require 'swineherd/resource'
require 'swineherd/resource/command_runner'


describe Swineherd::Resource::CommandRunner do
  let(:example_input){ Pathname.path_to(:shrd_dir, 'README.md') }
  let(:fancy_command){
    described_class.new(
      Pathname.path_to(:shrd_examples, 'utils', 'test_script.rb'),
      env:   { shrd_test: 'fnord' },
      chdir: '/tmp',
      )}
  let(:wc_command){ described_class.new('wc', input_filename: example_input) }

  def run_example_script(cmd, argv=[])
    stdout, stderr, success = cmd.run(argv)
    @stdout = MultiJson.load(stdout) rescue {unparseable: stdout}
    @stderr = MultiJson.load(stderr) rescue {unparseable: stderr}
    @success = success
    p [@stdout, @stderr, @success, cmd.errors]
    [@stdout, @stderr, @success]
  end
  
  context 'attribute' do
    subject{ fancy_command }
    its('command.basename.to_s'){ should == 'test_script.rb'}
    its('env'){ should == { shrd_test: 'fnord' }}
    its('chdir'){ should == Pathname.new('/tmp') }
  end

  context 'running' do
    subject{ fancy_command }
    context 'successfully' do
      before(:all){ run_example_script(subject, ["a", "b"]) }
      it('returns stdout as 1st return var'){       @stdout['greeting'].should == "hello to stdout" }
      it('returns stderr as 2nd return var'){       @stderr['greeting'].should == "hello to stderr" }
      it('returns success=true in 3rd return var'){ @success.should be true }
      it('applies runtime args'){                   @stdout['argv'].should == ["a", "b"] }
      it('sets environment variables'){             @stdout['env']['shrd_test'].should == 'fnord' }
      it('changes directory'){                      @stdout['pwd'].should == Pathname.new('/tmp').realpath.to_s }
      it('has a successful exitstatus'){            subject.exitstatus.should == 0 }
    end

    context 'reading input' do
      it 'is an error if the input is incomplete' do
        subject.input_filename = example_input
        subject.bufsize = 10
        run_example_script(subject, ['--read_stdin=fail'])
        subject.errors.first.should =~ /Incomplete read of /
        @stdout['input'].should == '# Swine'
      end
      it 'reads from an input script if given' do
        stdout, stderr, success = wc_command.run
        p [stdout, stderr, success, wc_command.errors]
      end
    end

    context 'return value' do
      it 'is in the exitstatus attribute' do
        run_example_script(subject, ['--exitstatus=69'])
        subject.exitstatus.should == 69
      end
    end

    context 'command' do
      it 'is a pain in the ass about not accepting a string commandline, because otherwise people might use the shell-no-escaped version' do
        ->{ described_class.new('ls').run('/') }.should raise_error ArgumentError, /commandline must be an array of strings: \//
      end
    end
  end
end
