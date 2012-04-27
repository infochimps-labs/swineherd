require 'gorillib/hash/delete_multi'
require 'forwardable'

module Swineherd
  class Stage
    extend Forwardable

    def_delegators(:@dsl_handler,
                   :merge_options,
                   :merge_options_soft,
                   :outputs,
                   :inputs,
                   :status,
                   :cmd)
    
    def initialize(cls,
                   source,
                   options = {},
                   attributes = {},
                   &blk)

      @dsl_handler = cls.new self, source, options, attributes, &blk

    end
  end

  class StageImpl

    def initialize(parent,
                   source,
                   options = {},
                   attributes = {},
                   &blk)
      @source = source
      @options = options.dup
      @attributes = attributes
      @stage_options = {}

      @fs = Swineherd::FileSystem.get @options.delete(:fstype)
      @finalized = false
      @parent = parent
      @blk = blk

    end

    def merge_options new_options
      @options.merge! new_options
    end

    def merge_options_soft new_options
      @options.merge!(new_options) {|k,old_v,new_v| old_v}
    end

    def status
      outputs.each do |output|
        success_dir = File.join output, "_SUCCESS"

        if @fs.exists? success_dir then
          return :complete
        elsif @fs.exists? output then
          return :failed
        else
          return :incomplete
        end
      end
    end

    def inputs
      sort_options
      return substitute :input_templates
    end

    def outputs
      sort_options
      return substitute :output_templates
    end

    protected

    attr_accessor :attributes, :options
    attr_reader :run_mode

    def finalize
      return if @finalized

      @parent.instance_eval &@blk if @blk

      @finalized = true

      sort_options
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

    def cmd
      finalize
    end

    def sort_options
      @stage_options.merge! @options.delete_multi(
                                                  :user,
                                                  :project,
                                                  :run_number,
                                                  :epoch,
                                                  :stage,
                                                  :input_templates,
                                                  :output_templates
                                                  )
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
      @stage_options[template_type].collect do |input|
        r = input.scan(/([^$]*)(\$(?:\{\w+\}|\w+))?/).collect do |novar, var|
          "#{novar}#{@stage_options[var.gsub(/[\$\{\}]/, '').to_sym] if var}"
        end

        r.inject :+
      end
    end
    
  end
end
