require 'swineherd-fs'
require 'forwardable'

module Swineherd
  class StageDelegator
    extend Forwardable

    def_delegators(:@dsl_handler,
                   :merge_options,
                   :merge_options_soft,
                   :env)

    def initialize child
      @dsl_handler = child
    end
  end

  class Stage

    def initialize(source,
                   options = {},
                   attributes = {},
                   &blk)
      @parent = StageDelegator.new self
      @source = source
      @options = options.dup
      @attributes = attributes
      @stage_options = {}

      @fs = Swineherd::FileSystem.get @options.delete(:fstype)
      @finalized = false
      @blk = blk

    end

    def merge_options new_options
      @options.merge! new_options
    end

    def merge_options_soft new_options
      @options.merge!(new_options) {|k,old_v,new_v| old_v}
    end

    def status
      dirs = old_dirs(:output_templates)

      ## fixme: This does not take into account the possibility of
      ## multiple output directories with some successes and some
      ## incompletes. In that case, we'll mark this as
      ## incomplete. (That's fine when we only have one output
      ## directory.)

      return :incomplete if dirs.index nil

      dirs.each do |output|
        success_dir = File.join output, "_SUCCESS"

        if @fs.exists? output 
          return :failed unless @fs.exists? success_dir
        else
          return :incomplete
        end
      end

      return :complete
    end

    def inputs
      sort_options
      last_stages = @stage_options[:last_stages]
      input_directories = old_dirs :input_templates, {
        :stage =>
        last_stages.size > 1 ? "{#{last_stages.join ','}}" : last_stages.first,
      }
    end
    
    def outputs
      return substitute :output_templates
    end

    #
    # Allows for setting the environment the script will be run in
    #
    def env
      ENV
    end

    def write_success_flag
      outputs.each do |d|
        @fs.open(File.join(d, "_SUCCESS"), "w") do |s|
          s.write("")
        end
      end
    end

    protected

    attr_accessor :attributes, :options, :source
    attr_reader :run_mode

    def finalize
      return if @finalized

      @parent.instance_eval &@blk if @blk

      @finalized = true

      sort_options
    end

    def script
      @attributes.merge!(:inputs => inputs, :outputs => outputs)
        .merge! @stage_options
      @script ||= Template.new(@source, @attributes).substitute!
    end

    def cmd
      finalize
    end

    def sort_options
      is_a_stage_option = lambda do |k,v|
        [:user,
         :project,
         :run_number,
         :epoch,
         :stage,
         :last_stages,
         :input_templates,
         :output_templates].index(k)
      end

      @stage_options.merge!(@options.select(&is_a_stage_option))
      @options.reject!(&is_a_stage_option)
    end

    def old_dirs template_type, overrides = {}
      sort_options
      patterns = substitute template_type, overrides.merge(:epoch => '[0-9]+')

      return patterns.map do |p|
        matching_inputs = @fs.ls(File.dirname p).select do |dir|
          Regexp.new(p).match dir
        end
        if matching_inputs then
          matching_inputs.sort.last
        elsif template_type == :input_templates
          raise("stage #{@stage_options[:stage]} couldn't find input "         \
                "directory directory matching #{p}")
        end
      end
    end

    def substitute template_type, overrides = {}
      sort_options
      options = @stage_options.merge overrides
      options[template_type].collect do |input|
        r = input.scan(/([^$]*)(\$(?:\{\w+\}|\w+))?/).collect do |novar, var|
          "#{novar}#{options[var.gsub(/[\$\{\}]/, '').to_sym] if var}"
        end
        
        r.inject :+
      end
    end
    
  end
end
