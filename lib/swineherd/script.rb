require 'gorillib/hash/delete_multi'

module Swineherd
  module Script

    autoload :WukongScript, 'swineherd/script/wukong_script'
    autoload :PigScript,    'swineherd/script/pig_script'
    autoload :RScript,      'swineherd/script/r_script'

    module Common
      
      attr_accessor :attributes, :fs, :options

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
        @sub_options = {}

        @fs = Swineherd::FileSystem.get options.delete(:fstype)

        self.instance_eval &blk
      end

      def merge_options new_options
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

      def substitute templates
        @sub_options.merge! @options.delete_multi(
                                                  :user,
                                                  :project,
                                                  :run_number,
                                                  :epoch,
                                                  :stage
                                                  )
        templates.collect do |input|
          r = input.scan(/([^$]*)(\$(?:\{\w+\}|\w+))?/).collect do |novar, var|
            "#{novar}#{@sub_options[var.gsub(/[\$\{\}]/, '').to_sym] if var}"
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
      
    end
  end
end
