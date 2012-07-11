module Swineherd
  class FileAsset < Asset
    include Gorillib::Model

    field :path,        Pathname, position: 1
    field :host,        String
    field :scheme,      Symbol

    delegate :basename, :dirname, :extname, :corename, :size, :open, :to_path, to: :path
    delegate :exist? , :directory?, :file?, :symlink?, :readable?, :writable?, :executable?, to: :path
    def absent?() not path.exist? ; end
    def bytesize() size ; end

    # Info about different file formats
    FILETYPE_INFO = Hash.new{|h,k| h[k] = Hash.new } unless defined?(FILETYPE_INFO) # autovivifying

    FILETYPE_INFO.merge!(
      tar:      { fileext: 'tar',     fileext_re: /\.(tar)$/,          compressed: false,  container: true, },
      tar_gzip: { fileext: 'tar.gz',  fileext_re: /\.(tar\.gz|tgz)$/,  compressed: true,   container: true,  },
      tar_bzip: { fileext: 'tar.bz2', fileext_re: /\.(tar\.bz2|tbz)$/, compressed: true,   container: true, },
      bzip:     { fileext: 'bz2',     fileext_re: /\.(bz2)$/,          compressed: true, },
      gzip:     { fileext: 'gz',      fileext_re: /\.(gz)$/,           compressed: true, },
      zip:      { fileext: 'zip',     fileext_re: /\.(zip)$/,          compressed: true, },
      )
    def self.filetype_info(kind) FILETYPE_INFO[kind]                ; end
    def filetype_info()          self.class.filetype_info(filetype) ; end
    #
    def self.fileext_re(kind)    filetype_info(kind)[:fileext_re] ; end
    def self.fileext(kind)       filetype_info(kind)[:fileext]    ; end
    def compressed?(kind)        filetype_info(kind)[:compressed] ; end
    def container?(kind)         filetype_info(kind)[:container]  ; end
    #
    def compressed?()            filetype_info[:compressed]       ; end
    def container?()             filetype_info[:container]        ; end

    def filetype
      case extname
      when /\.tar\.bz2$/, /\.tbz$/   then :tar_bzip
      when /\.tar\.gz$/,  /\.tgz$/   then :tar_gzip
      when /\.zip$/                  then :zip
      when /\.gz$/                   then :gzip
      when /\.bz2$/                  then :bzip
      else nil
      end
    end

    def relpath_to(*args)
      Pathname.relpath_to(*args)
    end

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

    def self.table_fields() [:name, :path, :mb, :filetype, :compressed?] ; end
    def table_attributes
      super.tap{|attrs| attrs[:mb] = attrs[:mb].to_f.round(0) }
    end
  end

  class DirectoryAsset < FileAsset
  end

end
