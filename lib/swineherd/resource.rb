# require 'posix/spawn'

# require 'fileutils'
# require 'tmpdir'
# require 'uri'
# require 'stringio'
# require 'securerandom'

require 'gorillib/pathname'
require 'gorillib/model'
require 'gorillib/builder'
require 'gorillib/type/url'
require 'gorillib/hash/keys'
require "gorillib/metaprogramming/delegation"
require "gorillib/io/system_helpers"
require "gorillib/enumerable/sum"

require 'formatador'

require 'swineherd/error'

require 'swineherd/resource/simple_units'

require 'swineherd/resource/spawn'
require 'swineherd/resource/asset'
require 'swineherd/resource/file_resource'

require 'swineherd/machine'
require 'swineherd/executor'

require 'swineherd/resource/command'

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
    :log_dir  => '/tmp/data/log',
    :ripd_dir => '/tmp/data/ripd',
    :rawd_dir => '/tmp/data/rawd',
    :mraw_dir => '/tmp/data/mraw',
    #
    :full_dir => '/tmp/data/full',
    :mini_dir => '/tmp/data/mini',
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
