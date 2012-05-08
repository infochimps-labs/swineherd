require 'rubygems'
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name        = "swineherd"
  gem.homepage    = "http://github.com/infochimps-labs/swineherd"
  gem.license     = "Apache 2.0"
  gem.summary     = %Q{Flexible workflow glue.}
  gem.description = %Q{Swineherd gives a humane, coherent, and filesystem-abstract interface to otherwise-horrible runners (looking at you, java-anything).}
  gem.email       = "coders@infochimps.com"
  gem.authors     = [
    "Jacob Perkins (@ganglion)",   "Travis Dempsey (@kornypoet)", "Philip (flip) Kromer (@mrflip)",
    "Kurt Bollacker (@bollacker)", "Josh Bronson (@joshbronson)",
  ]

  # include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  gem.add_development_dependency 'rspec', '> 2.7.0'
  gem.add_development_dependency 'watchr', '> 0.7'
  gem.add_development_dependency "yard", "~> 0.6.0"
  gem.add_development_dependency "jeweler", "~> 1.5.2"
  gem.add_development_dependency "rcov", ">= 0"
  gem.add_dependency 'configliere'
  gem.add_dependency 'gorillib'
  gem.add_dependency 'erubis'
  gem.add_dependency 'right_aws'
end
Jeweler::RubygemsDotOrgTasks.new


require 'yard'
YARD::Rake::YardocTask.new
