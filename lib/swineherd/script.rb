module Swineherd
  module Script

    autoload :WukongScript, 'swineherd/script/wukong_script'
    autoload :PigScript,    'swineherd/script/pig_script'
    autoload :RScript,      'swineherd/script/r_script'

    module Common
      
      attr_accessor :options, :attributes
      
      def initialize(source,
                     input_templates = [],
                     output_templates = [],
                     options = {},
                     attributes ={})
        @source = source
        @input_templates = input_templates
        @output_templates = output_templates
        @options = options
        @attributes = attributes
      end

      #
      # Allows for setting the environment the script will be ran in
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
            "#{novar}#{@options[var.gsub(/[\$\{\}]/, '')] if var}"
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
        mode = options[:mode] || :hadoop
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
