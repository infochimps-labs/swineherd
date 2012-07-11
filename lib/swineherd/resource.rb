
# require 'fileutils'
# require 'tmpdir'
# require 'uri'
# require 'stringio'
# require 'securerandom'

require 'multi_json'
require 'formatador'
require 'posix-spawn'
require 'ostruct'

require 'gorillib/pathname'
require 'gorillib/model'
require 'gorillib/builder'
require 'gorillib/type/url'
require 'gorillib/hash/keys'
require "gorillib/metaprogramming/delegation"
require "gorillib/io/system_helpers"
require "gorillib/enumerable/sum"
require 'gorillib/logger/log'

require 'swineherd/error'

require 'swineherd/resource/command_runner'

require 'swineherd/resource/simple_units'
require 'swineherd/resource/asset'
require 'swineherd/resource/file_resource'

require 'swineherd/machine'
require 'swineherd/executor'

require 'swineherd/run_stats'

require 'swineherd/project'

class Pathname
  def self.join(*args)
    new.join(*args)
  end
end

module Swineherd

  # data locations
  Pathname.register_default_paths(
    :data_dir      => '/tmp/data',
    :mini_dir      => '/tmp/mini',
    #
    :log_dir       => [:data_dir, 'log'],
    :ripd_dir      => [:data_dir, 'ripd'],
    :rawd_dir      => [:data_dir, 'rawd'],
    #
    :shrd_dir      => File.expand_path('../..', File.dirname(__FILE__)),
    :shrd_examples => [:shrd_dir, 'examples'],
    )

  # Executable programs
  Pathname.register_default_paths(
    :bzip2_exe   => 'bzip2',
    :bunzip2_exe => 'bunzip2',
    :gzip_exe    => 'gzip',
    :gunzip_exe  => 'gunzip',
    :zip_exe     => 'zip',
    :unzip_exe   => 'unzip',
    :tar_exe     => 'tar',
    #
    :cp_exe      => 'cp'
    )

  # transports we understand
  FILESYSTEMS = Hash.new{|h,k| h[k] = {} } unless defined?(SCHEMES) # autovivifying
  FILESYSTEMS.merge!(
    file:   {},
    hdfs:   {},
    s3n:    {},
    s3hdfs: {},
  )
  
end
