source "http://rubygems.org"

gem 'gorillib',       :path => '../gorillib'
gem 'configliere',    "~> 0.4.8"

gem 'multi_json',     "~> 1.1"
gem 'yajl-ruby',      "~> 1.1", :platform => :mri
gem 'json',                     :platform => :jruby
gem     'erubis',     ">= 2.7"
gem     'right_aws',  ">= 3.0.4"

group :development do
  gem 'bundler',     "~> 1"
  gem 'jeweler',     "~> 1.6"
  gem 'pry'
end

group :docs do
  gem 'yard',        ">= 0.7"
  gem 'RedCloth',    "~> 4.2"
  gem 'redcarpet',   "~> 2.1"
end

group :test do
  gem 'rspec',       "~> 2.8"
  gem 'guard',       ">= 1.0"
  gem 'guard-rspec', ">= 0.6"
  gem 'guard-yard'
  gem 'guard-process'

  if RUBY_PLATFORM.include?('darwin')
    gem 'growl',      ">= 1"
    gem 'rb-fsevent', ">= 0.9"
  end
end
