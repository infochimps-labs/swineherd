require File.expand_path('../spec_helper', File.dirname(__FILE__))

require 'swineherd/template'

describe Swineherd::Template do
  let(:demo_pig_script_filename){ ROOT_PATH('spec/fixtures/demo_pig_script_filename.pig.erb') }
  let(:demo_pig_script){ Swineherd::Template.new(demo_pig_script_filename, :multigraph => 'my_multigraph', :reduce_tasks => 'reduce_tasks', :degree_distribution => 'my_degree_distribution' ) }
  subject{ demo_pig_script }

  it 'should work' do
    demo_pig_script.should be_a(Swineherd::Template)
  end

  # context '#contents' do
  #   it 'autovivifies from its template' do
  #     subject.content.should =~ /graph   = LOAD .*my_degree_distribution';/
  #    end
  # end

end
