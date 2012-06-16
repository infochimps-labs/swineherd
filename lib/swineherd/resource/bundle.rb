module Swineherd
  module Resource

    # :force, :noop, :preserve, and :verbose

    
    #
    # Some code taken from UnixUtils -- https://github.com/seamusabshere/unix_utils/blob/master/lib/unix_utils.rb
    #
    module Bundle
      extend Gorillib::Concern

      BUNDLE_KINDS = {}
      
      module Bzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:bzip] = { :fileext => 'bz2', :fileext_re => /\.(bz2)/, :mixins => [self]}
        def file_type() :bzip ; end
        def unbundle_command(into) ['bunzip2',         '--stdout', self.to_s,   { :write_to => into.to_s }] ; end
        def bundle_command(from)    ['bzip2', '--keep', '--stdout', from.to_s, { :write_to => self.to_s    }] ; end
      end

      module Gzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:gzip] = { :fileext => 'gz', :fileext_re => /\.(gz)/, :mixins => [self]}
        def file_type() :gzip ; end
        def unbundle_command(into) ['gunzip',          '--stdout', self.to_s,   { :write_to => into.to_s }] ; end
        def bundle_command(from)   ['gzip',            '--stdout', from.to_s, { :write_to => self.to_s    }] ; end
      end

      module Zip
        extend Gorillib::Concern
        BUNDLE_KINDS[:zip] = { :fileext => 'zip', :fileext_re => /\.(zip)/, :mixins => [self]}
        def file_type() :zip ; end
        def unbundle_command(into) ['unzip', '-qq', '-n', self.to_s, '-d',       into.to_s, {}] ; end
        def bundle_command(from)   ['zip',   '-rq', self.to_s, from.basename.to_s, { :chdir => from.dirname.to_s }] ; end
      end

      module Tar
        extend Gorillib::Concern
        BUNDLE_KINDS[:tar] = { :fileext => 'tar', :fileext_re => /\.(tar)/, :mixins => [self]}
        def file_type() :tar ; end
        def unbundle_command(into) ; ['tar', '-xf', self.to_s, '-C', into.dirname.to_s, {}] ; end
        def bundle_command(from)   ; ['tar', '-cf', self.to_s, '-C', from.dirname.to_s, from.basename.to_s, {}] ; end
      end

      module TarGzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:tar_gzip] = { :fileext => 'tar.gz', :fileext_re => /\.(tar\.gz|tgz)/, :mixins => [Tar, self]}
        def file_type() :tar_gzip ; end
        def unbundle_command(into) ; super.insert(1, '-z') ; end
        def bundle_command(from)   ; super.insert(1, '-z') ; end
      end

      module TarBzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:tar_bzip] = { :fileext => 'tar.bz2', :fileext_re => /\.(tar\.bz2|tbz)/, :mixins => [Tar, self]}
        def file_type() :tar_bzip ; end
        def unbundle_command(into) ; super.insert(1, '-j') ; end
        def bundle_command(from)   ; super.insert(1, '-j') ; end
      end

      module NotCompressed
        def unbundle_command(into)
          
        end
      end

      def absent?() not exist? ; end

      def check_absent!(on_exists=:fail)
        return true if absent?
        case on_exists
        when :force, :clobber then true
        when :skip, :preserve then false
        else raise Swineherd::ResourceExistsError, "Resource '#{self}' already exists"
        end
      end

      def check_exists!(on_absent=:fail)
        return true if exist?
        case on_absent
        when :skip            then false
        else raise Swineherd::ResourceAbsentError, "Resource '#{self}' is absent"
        end
      end

      def fileext_re(kind)  BUNDLE_KINDS[kind][:fileext_re] ; end
      def fileext_for(kind) BUNDLE_KINDS[kind][:fileext]    ; end
      def unbundled_name()   self.class.new(self.to_s.gsub(fileext_re(file_type), '')) ; end
      def bundled_name(kind) self.class.new("#{self.to_s}.#{fileext_for(kind)}")       ; end
      
      def unbundle(options={})
        into = options[:into].nil? ? unbundled_name : normalize(options[:into])
        into.check_absent!(options[:on_exists]) or return into
        #
        *argv, opts = unbundle_command(into)
        opts.merge!(options.slice(:dry_run))
        Log.debug("unbundling '#{self}' (#{file_kind}) into '#{into}': #{argv.join(" ")} #{opts.inspect}")
        into.dirname.mkpath
        Swineherd::Resource.run_command(argv, opts)
        into
      end

      # @param kind
      def bundle(kind, options={})
        into = options[:into].nil? ? bundled_name(kind) : normalize(options[:into])
        into.check_absent!(options[:on_exists]) or return into
        #
        *argv, opts = into.bundleize(kind).bundle_command(self)
        opts.merge!(options.slice(:dry_run))
        Log.debug("bundling '#{self}' into '#{into}' (#{kind}): #{argv.join(" ")} #{opts.inspect}")
        into.dirname.mkpath
        Swineherd::Resource.run_command(argv, opts)
        into
      end

      # Decorate the resource with methods appropriate for its bundle type
      def bundleize(bundle_type = nil)
        bundle_type ||= self.file_kind     
        bundle_info =  BUNDLE_KINDS[bundle_type] or raise Swineherd::ResourceActionError, "Tried to bundlize #{self} as #{bundle_type.inspect}, which is not a bundle type"
        bundle_info[:mixins].each{|mixin| extend(mixin) }
        self
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

      def bundled?
        not bundle_type.nil?
      end

    end

  end
end
