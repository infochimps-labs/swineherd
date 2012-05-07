source "http://rubygems.org"

gem 'configliere',    :git => File.expand_path('../configliere/.git', File.dirname(__FILE__))
gem 'gorillib',       :git => File.expand_path('../gorillib/.git', File.dirname(__FILE__)),    :branch => 'version_1'

gem     'multi_json', "~> 1.1"
gem     'json'
gem     'erubis',     ">= 2.7"
gem     'right_aws',  ">= 3.0.4"

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem   'bundler',    "~> 1"
  gem   'pry'
  gem   'jeweler',    "~> 1.6"
end

group :docs do
  gem   'yard',       "~> 0.7"
  gem   'redcarpet',  "~> 2.1"
  gem   'RedCloth'
end

group :test do
  gem   'rspec',      "~> 2.5"
  if RUBY_PLATFORM.include?('darwin')
    gem 'rb-fsevent', "~> 0.9"
    # gem 'growl',      "~> 1"
    # gem 'ruby_gntp'
  end

  gem   'guard',      "~> 1"
  gem   'guard-rspec'
  gem   'guard-yard'
  gem   'guard-process'

  gem 'simplecov',  ">= 0.5",   :platform => :ruby_19
end
