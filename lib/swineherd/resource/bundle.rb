module Swineherd
  module Resource

    Pathname.register_default_paths(
      :bzip2_exe   => 'bzip2',
      :bunzip2_exe => 'bunzip2',
      :gzip_exe    => 'gzip',
      :gunzip_exe  => 'gunzip',
      :zip_exe     => 'zip',
      :unzip_exe   => 'unzip',
      :tar_exe     => 'tar',
      )

    #
    # Some code taken from UnixUtils -- https://github.com/seamusabshere/unix_utils/blob/master/lib/unix_utils.rb
    #
    module Bundle
      extend Gorillib::Concern

      BUNDLE_KINDS = {} unless defined?(Swineherd::Resource::Bundle::BUNDLE_KINDS)

      def fileext_re(kind)  BUNDLE_KINDS[kind][:fileext_re] ; end
      def fileext_for(kind) BUNDLE_KINDS[kind][:fileext]    ; end
      def unbundled_name()   self.class.new(self.to_s.gsub(fileext_re(file_type), '')) ; end
      def bundled_name(kind) self.class.new("#{self}.#{fileext_for(kind)}")       ; end

      def unbundle(options={})
        into = options[:into].nil? ? unbundled_name : normalize(options[:into])
        into.check_absent!(options[:exists]) or return into
        #
        *argv, opts = unbundle_command(into, options)
        opts.merge!(options.slice(:noop))
        Log.debug("unbundling '#{self}' (#{file_kind}) into '#{into}': #{argv.join(" ")} #{opts.inspect}")
        into.dirname.mkpath
        Swineherd::Resource.run_command(argv, opts)
        into
      end

      # @param kind
      def bundle(kind, options={})
        into = options[:into].nil? ? bundled_name(kind) : normalize(options[:into])
        into.check_absent!(options[:exists]) or return into
        #
        *argv, opts = into.bundleize(kind).bundle_command(self, options)
        opts.merge!(options.slice(:noop))
        Log.debug("bundling '#{self}' into '#{into}' (#{kind}): #{argv.join(" ")} #{opts.inspect}")
        into.dirname.mkpath
        Swineherd::Resource.run_command(argv, opts)
        into
      end

      def bundle?() true ; end

      module Bzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:bzip] = { :fileext => 'bz2', :fileext_re => /\.(bz2)/, :mixins => [self]}
        def file_type() :bzip ; end
        def unbundle_command(into, options)
          cmd = [relpath_to(:bunzip2_exe), '--stdout', '--keep', self]
          [*cmd, { :write_to => into }]
        end
        def bundle_command(from, options)
          cmd = [relpath_to(:bzip2_exe),   '--stdout', '--keep', from]
          [*cmd, { :write_to => self }]
        end
      end

      module Gzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:gzip] = { :fileext => 'gz', :fileext_re => /\.(gz)/, :mixins => [self]}
        def file_type() :gzip ; end
        def unbundle_command(into, options) [relpath_to(:gunzip_exe), '--stdout', self, { :write_to => into }] ; end
        def bundle_command(from, options)   [relpath_to(:gzip_exe),   '--stdout', from, { :write_to => self    }] ; end
      end

      module Zip
        extend Gorillib::Concern
        BUNDLE_KINDS[:zip] = { :fileext => 'zip', :fileext_re => /\.(zip)/, :mixins => [self]}
        def file_type() :zip ; end
        def unbundle_command(into, options) [relpath_to(:unzip_exe), '-qq', '-n', self, '-d',  into, {}] ; end
        def bundle_command(from, options)   [relpath_to(:zip_exe),   '-rq', self, from.basename,     { :chdir => from.dirname }] ; end
      end

      module Tar
        extend Gorillib::Concern
        BUNDLE_KINDS[:tar] = { :fileext => 'tar', :fileext_re => /\.(tar)/, :mixins => [self]}
        def file_type() :tar ; end
        def unbundle_command(into, options) ; [relpath_to(:tar_exe), '-xf', self, '-C', into.dirname,                {}] ; end
        def bundle_command(from, options)   ; [relpath_to(:tar_exe), '-cf', self, '-C', from.dirname, from.basename, {}] ; end
      end

      module TarGzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:tar_gzip] = { :fileext => 'tar.gz', :fileext_re => /\.(tar\.gz|tgz)/, :mixins => [Tar, self]}
        def file_type() :tar_gzip ; end
        def unbundle_command(into, options) ; super.insert(1, '-z') ; end
        def bundle_command(from, options)   ; super.insert(1, '-z') ; end
      end

      module TarBzip
        extend Gorillib::Concern
        BUNDLE_KINDS[:tar_bzip] = { :fileext => 'tar.bz2', :fileext_re => /\.(tar\.bz2|tbz)/, :mixins => [Tar, self]}
        def file_type() :tar_bzip ; end
        def unbundle_command(into, options) ; super.insert(1, '-j') ; end
        def bundle_command(from, options)   ; super.insert(1, '-j') ; end
      end

    end

  end
end
