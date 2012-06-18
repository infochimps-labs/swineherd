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

    def relpath_to(*args)
      self.class.relative_path_to(*args)
    end


    def absent?() not exist? ; end

    def check_absent!(on_exists=:fail)
      return true if absent?
      case on_exists
      when :force      then true
      when :skip       then false
      else raise Swineherd::ResourceExistsError, "Resource '#{self}' already exists"
      end
    end

    def check_exists!(on_absent=:fail)
      return true if exist?
      case on_absent
      when :skip       then false
      else raise Swineherd::ResourceAbsentError, "Resource '#{self}' is absent"
      end
    end

    def file_kind
      case extname
      when /\.tar\.bz2$/, /\.tbz$/   then :tar_bzip
      when /\.tar\.gz$/,  /\.tgz$/   then :tar_gzip
      when /\.zip$/                  then :zip
      when /\.gz$/                   then :gzip
      when /\.bz2$/                  then :bzip
      else nil
      end
    end

    def file_kind!
      file_kind or raise Swineherd::ResourceActionError, "Cannot identify #{self} -- #{extname} doesn't match a known type"
    end

    # Decorate the resource with methods appropriate for its bundle type
    def bundleize(bundle_type = nil)
      bundle_type ||= self.file_kind!
      bundle_info =  BUNDLE_KINDS[bundle_type] or raise Swineherd::ResourceActionError, "Tried to bundlize #{self} as #{bundle_type.inspect}, which is not a bundle type"
      extend Swineherd::Resource::Bundle
      bundle_info[:mixins].each{|mixin| extend(mixin) }
      self
    end
  end

  class DirectoryResource < FileResource
  end

end
