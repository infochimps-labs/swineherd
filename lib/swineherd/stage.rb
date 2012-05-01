require 'swineherd-fs'
require 'forwardable'

module Swineherd
  class StageDelegator
    extend Forwardable

    def_delegators(:@dsl_handler,
                   :merge_options,
                   :merge_options_soft,
                   :merge_attributes,
                   :env)

    def initialize child
      @dsl_handler = child
    end
  end

  class Stage

    ## These options are used by the stage and are not passed directly
    ## to scripts. Instead, they are pulled out and used to generate
    ## options sent to scripts
    @@stage_option_keys = [
                           :user,
                           :project,
                           :run_number,
                           :run_mode,
                           :epoch,
                           :stage,
                           :last_stages,
                           :input_templates,
                           :output_templates,
                           :hadoop_home,
                          ]

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
      @blk = blk

      @parent.instance_eval &@blk if @blk
      sort_options
    end

    def merge_options new_options
      @options.merge! new_options
      sort_options
    end

    def merge_options_soft new_options
      @options.merge!(new_options) {|k,old_v,new_v| old_v}
      sort_options true
    end

    def merge_attributes attributes
      @attributes.merge! attributes
    end

    def status
      output_dirs = old_dirs(:output_templates, [@stage_options[:stage]])
      input_dirs = old_dirs(:input_templates, @stage_options[:last_stages])

      return :no_inputs if
        input_dirs.size != (@stage_options[:input_templates].size *
                            [@stage_options[:last_stages].size,1].max)

      if output_dirs.size == 0 then
        return :incomplete
      elsif output_dirs.size < @stage_options[:output_templates].size then
        return :failed
      end
      
      output_dirs.each do |output|
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
      input_directories = old_dirs(:input_templates,
                                   @stage_options[:last_stages])
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

    def cmd
      format_options
      script_cmd
    end

    protected

    attr_accessor :options
    attr_reader :source
    
    def format_options
      format_script_options
      options.map do |param,val|
        case val
        when nil then "--#{param}"
        else "--#{param}=#{val}"
        end
      end.join(' ')
    end

    def sort_options soft = false
      is_a_stage_option = lambda { |k,v| @@stage_option_keys.index(k) }
      
      @stage_options.merge!(@options.select(&is_a_stage_option)) do |k,old,new|
        soft ? old : new
      end
      @options.reject!(&is_a_stage_option)
    end

    def script
      @attributes.merge!(:inputs => inputs, :outputs => outputs)
        .merge! @stage_options

      # saving this to avoid garbage-collecting Template's temp file...
      @template_save = Template.new(source, @attributes)
      @script ||= @template_save.substitute!
    end

    #
    # Temporarily overrides into @stage_options and treat templates
    # like regular expressions to match files.
    #
    def find_matching_files template_type, overrides
      # FIXME: assuming epoch occurs in leaf directory name. This may
      # not be true in general, but swineherd-fs does not have support
      # for globbing, and the most straightforward way to remove the
      # above assumption is to put globbing in there.

      substitute(template_type, overrides).map do |pattern|
        @fs.ls(File.dirname(pattern)).map do |dir|
          path = dir.split(':', 2)[-1]
          path if Regexp.new(pattern).match path
        end.compact.sort.last
      end.compact
    end

    def old_dirs template_type, stages
      if stages.size > 0
        stages.map do |stage|
          find_matching_files template_type, :stage => stage, :epoch => '[0-9]+'
        end.flatten.compact
      else
        find_matching_files template_type, :epoch => '[0-9]+'
      end
    end

    def substitute template_type, overrides = {}
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
