module Swineherd
  module HttpResource

    Pathname.register_default_paths(
      :wget_exe    => 'wget',
      )


    class Recursive
      include Gorillib::Model

      field :name,  Symbol,   :doc => "a descriptive handle for this resource"
      field :url,   Url,      :doc => "URL to begin fetching from"

      field :log_file,  Pathname, :default => ->{ Pathname.path_to(:log_dir, name.to_s, "#{name}.log") }, :doc => "destination log file", :tester => true
      field :recursive, :boolean, :default => true,  :doc => "recursively fetch pages", :tester => true
      field :rec_level, Integer,  :default => 2,     :doc => "level to recurse to (must also set `:recursive => true` for this to matter)", :tester => true

      def fetch_command
        cmd = [ Pathname.relpath_to(:wget_exe) ]
        cmd << '-r'              if recursive?
        cmd << '-l' << rec_level if rec_level?
        cmd << '--no-parent'
        cmd << '--no-clobber'
        cmd << '--no-verbose'
        cmd << '-a' << log_file
        cmd << url
        cmd << {}
        cmd
      end

      def ripd_dir
        Pathname.new("/tmp/ripd")
      end

      def fetch(options={})
        *argv, opts = fetch_command
        opts.merge!(options.slice(:noop))
        opts.reverse_merge!(:chdir => ripd_dir)
        #
        Log.debug("fetch '#{url}' into '#{ripd_dir}': #{argv.join(" ")} #{opts.inspect}")
        log_file.dirname.mkpath
        ripd_dir.mkpath
        Swineherd::Resource.run_command(argv, opts)
        ripd_dir
      end

      def self.make(name, url, attrs={})
        receive(attrs.merge(:name => name, :url => url))
      end

    end

  end
end
