require 'posix/spawn'

# require 'fileutils'
# require 'tmpdir'
# require 'uri'
# require 'stringio'
# require 'securerandom'

require 'gorillib/some'
require 'gorillib/model'
require 'gorillib/builder'

require 'swineherd/error'
require 'swineherd/resource/spawn'
require 'swineherd/resource/bundle'

require 'gorillib/type/url'
require 'swineherd/resource/http_resource'

require 'swineherd/project'

class Pathname
  def self.join(*args)
    new.join(*args)
  end
end

module Swineherd
  Pathname.register_default_paths(
    :log_dir  => '/tmp/data/log',
    :ripd_dir => '/tmp/data/ripd',
    :rawd_dir => '/tmp/data/rawd',
    :mraw_dir => '/tmp/data/mraw',
    #
    :full_dir => '/tmp/data/full',
    :mini_dir => '/tmp/data/mini',
    )

end
