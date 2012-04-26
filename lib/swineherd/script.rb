require 'gorillib/hash/delete_multi'

module Swineherd
  class Script
    attr_accessor :attributes, :fs, :options
    attr_reader :run_mode
    protected :run_mode

    def initialize(source,
                   options = {},
                   attributes = {},
                   &blk)
      @source = source
      @options = options.dup
      @attributes = attributes
      @stage_options = {}

      @fs = Swineherd::FileSystem.get @options.delete(:fstype)

      self.instance_eval &blk if blk
    end

    def merge_options new_options
      @options.merge! new_options
    end

    def merge_options_soft new_options
      @options.merge!(new_options) {|k,old_v,new_v| old_v}
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

    def substitute template_type
      @stage_options.merge! @options.delete_multi(
                                                  :user,
                                                  :project,
                                                  :run_number,
                                                  :epoch,
                                                  :stage,
                                                  :input_templates,
                                                  :output_templates
                                                  )
      @stage_options[template_type].collect do |input|
        r = input.scan(/([^$]*)(\$(?:\{\w+\}|\w+))?/).collect do |novar, var|
          "#{novar}#{@stage_options[var.gsub(/[\$\{\}]/, '').to_sym] if var}"
        end

        r.inject :+
      end
    end
    
    def inputs
      return substitute :input_templates
    end

    def outputs
      return substitute :output_templates
    end
    
  end
end
