module Swineherd
  module Resource

    FileAsset.class_eval do
      include Swineherd::Resource::Bundle

      # Decorate the resource with methods appropriate for its bundle type
      def bundleize(bundle_type = nil)
        bundle_type ||= self.filetype  or raise Swineherd::ResourceActionError, "Cannot identify #{self} -- #{extname} doesn't match a known type"
        bundle_info =  self.class.file_type_info(bundle_type) or raise Swineherd::ResourceActionError, "Tried to bundlize #{self} as #{bundle_type.inspect}, which is not a bundle type"
        extend Swineherd::Resource::Bundle
        bundle_info[:mixins].each{|mixin| extend(mixin) }
        self
      end
    end

    #
    # Some code taken from UnixUtils -- https://github.com/seamusabshere/unix_utils/blob/master/lib/unix_utils.rb
    #
    module Bundle
      extend Gorillib::Concern

      def unbundled_path()   Pathname.new(path.to_s.gsub(fileext_re(file_type), '')) ; end
      def bundled_path(kind) Pathname.new("#{path}.#{fileext_for(kind)}")       ; end

      def unbundle(options={})
        into = options[:into].nil? ? unbundled_name : Pathname.normalize(options[:into])
        into.check_absent!(options[:exists]) or return into
        #
        *argv, opts = unbundle_command(into, options)
        opts.merge!(options.slice(:noop))
        Log.debug("unbundling '#{path}' (#{filetype}) into '#{into}': #{argv.join(" ")} #{opts.inspect}")
        into.dirname.mkpath
        Swineherd::Resource.run_command(argv, opts)
        into
      end

      # @param kind
      def bundle(kind, options={})
        into = options[:into].nil? ? bundled_name(kind) : normalize(options[:into])
        into.check_absent!(options[:exists]) or return into
        #
        *argv, opts = into.bundleize(kind).bundle_command(path, options)
        opts.merge!(options.slice(:noop))
        Log.debug("bundling '#{path}' into '#{into}' (#{kind}): #{argv.join(" ")} #{opts.inspect}")
        into.dirname.mkpath
        Swineherd::Resource.run_command(argv, opts)
        into
      end

      def bundle?() true ; end

      module Bzip
        extend Gorillib::Concern
        FILE_TYPE_INFO[:bzip][:mixins] = self
        def file_type() :bzip ; end
        def unbundle_command(into, options) [relpath_to(:bunzip2_exe), '--stdout', '--keep', path, { write_to: into }] ; end
        def bundle_command(from, options)   [relpath_to(:bzip2_exe),   '--stdout', '--keep', from, { write_to: path }] ; end
      end

      module Gzip
        extend Gorillib::Concern
        FILE_TYPE_INFO[:gzip][:mixins] = [self]
        def file_type() :gzip ; end
        def unbundle_command(into, options) [relpath_to(:gunzip_exe), '--stdout', path, { write_to: into }] ; end
        def bundle_command(from, options)   [relpath_to(:gzip_exe),   '--stdout', from, { write_to: path    }] ; end
      end

      module Zip
        extend Gorillib::Concern
        FILE_TYPE_INFO[:zip][:mixins] = [self]
        def file_type() :zip ; end
        def unbundle_command(into, options) [relpath_to(:unzip_exe), '-qq', '-n', path, '-d',  into, {}] ; end
        def bundle_command(from, options)   [relpath_to(:zip_exe),   '-rq', path, from.basename,     { chdir: from.dirname }] ; end
      end

      module Tar
        extend Gorillib::Concern
        FILE_TYPE_INFO[:tar][:mixins] = [self]
        def file_type() :tar ; end
        def unbundle_command(into, options) ; [relpath_to(:tar_exe), '-xf', path, '-C', into.dirname,                {}] ; end
        def bundle_command(from, options)   ; [relpath_to(:tar_exe), '-cf', path, '-C', from.dirname, from.basename, {}] ; end
      end

      module TarGzip
        extend Gorillib::Concern
        FILE_TYPE_INFO[:tar_gzip][:mixins] = [Tar, self]
        def file_type() :tar_gzip ; end
        def unbundle_command(into, options) ; super.insert(1, '-z') ; end
        def bundle_command(from, options)   ; super.insert(1, '-z') ; end
      end

      module TarBzip
        extend Gorillib::Concern
        FILE_TYPE_INFO[:tar_bzip][:mixins] = [Tar, self]
        def file_type() :tar_bzip ; end
        def unbundle_command(into, options) ; super.insert(1, '-j') ; end
        def bundle_command(from, options)   ; super.insert(1, '-j') ; end
      end

    end

  end
end
