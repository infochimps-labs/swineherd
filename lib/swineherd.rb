require 'rubygems'
require 'configliere' ; Configliere.use(:commandline, :env_var, :define)
require 'rake'
require 'gorillib/logger/log'

module Swineherd
  autoload :Template,     'swineherd/template'
  autoload :FileSystem,   'swineherd/filesystem'
  autoload :Stage,        'swineherd/stage'
  autoload :StageImpl,    'swineherd/stage'
  autoload :Workflow,     'swineherd/workflow'
  
  # For rake 0.9 compatibility
  include Rake::DSL if defined?(Rake::DSL)
end
