require 'rspec'
require 'erubis'

ROOT_DIR = File.expand_path('..',File.dirname(__FILE__))
def ROOT_PATH(*paths)
  File.expand_path(File.join(*paths), ROOT_DIR)
end

$LOAD_PATH.unshift(ROOT_PATH('lib'))

# Configure rspec
RSpec.configure do |config|
 # config.include Cornelius::TestHelper, :example_group => {
 #   :file_path => /spec/
 # }
end
