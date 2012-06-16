require 'posix/spawn'

# require 'fileutils'
# require 'tmpdir'
# require 'uri'
# require 'stringio'
# require 'securerandom'

require 'gorillib/some'
require 'gorillib/model'

require 'swineherd/error'
require 'swineherd/resource/spawn'
require 'swineherd/resource/bundle'



class Pathname
  def self.join(*args)
    new.join(*args)
  end
end

module Swineherd

  class FileResource < Pathname
    include Swineherd::Resource::Bundle
    include Gorillib::Model

    def inspect
      "#<FileResource:#{to_s}>"
    end

    def normalize(obj)
      return obj if obj.nil?
      obj.is_a?(self.class) ? obj : self.class.new(obj)
    end

    # @returns the basename without extension (using self.extname as the extension)
    def corename
      basename(self.extname)
    end
  end

end
