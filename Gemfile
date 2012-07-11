source "http://rubygems.org"

gem 'configliere',    :path => '../configliere'
gem 'gorillib',       :path => '../gorillib'

gem   'multi_json',  ">= 1.1"
gem   'oj',          ">= 1.2"
gem   'json',                    :platform => :jruby

gem   'erubis',      ">= 2.7"
# gem   'right_aws',   ">= 3.0.4"
gem   'formatador'
gem   'posix-spawn'
gem   'addressable'

# Only gems that you want listed as development dependencies in the gemspec
group :development do
  gem 'bundler',     "~> 1.1"
  gem 'rake'
end

# Gems you would use if hacking on this gem (rather than with it)
group :support do
  gem 'jeweler',     ">= 1.6"
  gem 'pry'
  #
  gem 'yard',        ">= 0.7"
  gem 'RedCloth',    ">= 4.2"
  gem 'redcarpet',   ">= 2.1"
end

# Gems for testing and coverage
group :test do
  gem 'rspec',       "~> 2.8"
  gem 'simplecov',   ">= 0.5", :platform => :ruby_19
  #
  gem 'guard',       ">= 1.0"
  gem 'guard-rspec', ">= 0.6"
  gem 'guard-yard'
  gem 'guard-process'
  #
  if RUBY_PLATFORM.include?('darwin')
    gem 'rb-fsevent', ">= 0.9"
  end
end
