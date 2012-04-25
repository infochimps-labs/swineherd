module Swineherd
  module Script

    autoload :WukongScript, 'swineherd/script/wukong_script'
    autoload :PigScript,    'swineherd/script/pig_script'
    autoload :RScript,      'swineherd/script/r_script'

    module Common
      
      attr_accessor :attributes

      def initialize(source,
                     input = [],
                     output = [],
                     options = {},
                     attributes = {},
                     &blk)
        @source = source
        @input_templates = input
        @output_templates = output
        @options = options
        @attributes = attributes
        @fs = Swineherd::FileSystem.get options[:fstype]

        self.instance_eval &blk
      end

      def options new_options
        @options.merge! new_options
      end

      def input_templates input
        @input_templates = input
      end

      def output_templates output
        @output_templates = output
      end

      #
      # Allows for setting the environment the script will be run in
      #
      def env
        ENV
      end

      def script
        @script ||= Template.new(@source, @attributes).substitute!
      end

      #
      # So we can reuse ourselves
      #
      def refresh!
        @script = nil
        @outputs = []
        @inputs  = []
      end

      #
      # This depends on the type of script
      #
      def cmd
        raise "Override this in subclass!"
      end

      #
      # Override this in subclass to decide how script runs in 'local' mode
      # Best practice is that it needs to be able to run on a laptop w/o
      # hadoop.
      #
      def local_cmd
        raise "Override this in subclass!"
      end

      def substitute templates
        templates.collect do |input|
          r = input.scan(/([^$]*)(\$(?:\{\w+\}|\w+))?/).collect do |novar, var|
            "#{novar}#{@options[var.gsub(/[\$\{\}]/, '').to_sym] if var}"
          end

          r.inject :+
        end
      end
      
      def inputs
        return substitute @input_templates
      end

      
      def outputs
        return substitute @output_templates
      end
      
      #
      # Default is to run with hadoop
      #
      def run
        outputs.each do |output|
          success_dir = File.join output, "_SUCCESS"
          if @fs.exists? success_dir then
            Log.info "I see #{success_dir}. skipping stage."
            return
          end
        end

        mode = @options[:mode] || :hadoop
        command = case mode
                  when :local then local_cmd
                  when :hadoop then cmd
                  end

        sh command do |ok, status|
          ok or raise "#{mode.to_s.capitalize} mode script failed with exit status #{status}"
        end
      end
    end
  end
end
