require 'swineherd-fs'
require 'forwardable'
require 'swineherd/constants'

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

    include SwineHerd::AllOptions

    def initialize(source,
                   options = {},
                   attributes = {},
                   &blk)
      @parent = StageDelegator.new self
      @source = source
      @options = options.dup
      @attributes = attributes
      @stage_options = {}

      @blk = blk

      @parent.instance_eval &@blk if @blk
      sort_options
      @out_fs = Swineherd::FileSystem.get (@stage_options[OUT_FSTYPE] ||
                                           @stage_options[FSTYPE])
      @in_fs = Swineherd::FileSystem.get (@stage_options[IN_FSTYPE] ||
                                          @stage_options[FSTYPE])
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
      output_dirs = old_dirs(OUTPUT_TEMPLATES,
                             [@stage_options[STAGE]],
                             @out_fs)
      input_dirs = old_dirs(INPUT_TEMPLATES,
                            @stage_options[LAST_STAGES],
                            @in_fs)

      # just a quick check. This is not sufficient if an input
      # template is designed to match more than one input. However, if
      # we see less inputs than templates, it should be safe to assume
      # that we should fail.
      if input_dirs.size < (@stage_options[INPUT_TEMPLATES].size *
                            [@stage_options[LAST_STAGES].size,1].max) then
        puts input_dirs.size
        puts @stage_options[INPUT_TEMPLATES].size
        puts [@stage_options[LAST_STAGES].size,1].max
        return :no_inputs
      end

      if output_dirs.size == 0 then
        return :incomplete
      elsif output_dirs.size < @stage_options[OUTPUT_TEMPLATES].size then
        return :failed
      end
      
      output_dirs.each do |output|
        success_dir = File.join output, "_SUCCESS"
        
        if @out_fs.exists? output
          return :failed unless @out_fs.exists? success_dir
        else
          return :incomplete
        end
      end

      return :complete
        
    end

    def inputs
      input_directories = old_dirs(INPUT_TEMPLATES,
                                   @stage_options[LAST_STAGES],
                                   @in_fs)
    end
    
    def outputs
      return substitute OUTPUT_TEMPLATES
    end

    #
    # Allows for setting the environment the script will be run in
    #
    def env
      ENV
    end

    def write_success_flag
      outputs.each do |d|
        # For stages that do things like write to HDFS, create the
        # directory before writing the success flag.
        @out_fs.mkdir_p d
        @out_fs.open(File.join(d, "_SUCCESS"), "w") do |s|
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
      is_a_stage_option = lambda do |k,v|
        SwineHerd::StageOptions.constants.map do |key|
          SwineHerd::StageOptions.const_get key
        end.index k
      end
      
      @stage_options.merge!(@options.select(&is_a_stage_option)) do |k,old,new|
        soft ? old : new
      end
      @options.reject!(&is_a_stage_option)
    end

    def script
      @attributes.merge!(INPUTS => inputs, OUTPUTS => outputs)
        .merge! @stage_options

      # saving this to avoid garbage-collecting Template's temp file...
      @template_save = Template.new(source, @attributes)
      @script ||= @template_save.substitute!
    end

    #
    # Temporarily overrides into @stage_options and treat templates
    # like regular expressions to match files.
    #
    def find_matching_files template_type, fs, overrides
      # FIXME: assuming epoch occurs in leaf directory name. This may
      # not be true in general, but swineherd-fs does not have support
      # for globbing, and the most straightforward way to remove the
      # above assumption is to put globbing in there.

      substitute(template_type, overrides).map do |pattern|
        require 'pp'; puts "!!!"; pp pattern, File.dirname(pattern), fs.ls(File.dirname(pattern))
        fs.ls(File.dirname(pattern)).map do |dir|
          path = /(?:file:|hdfs:\/\/[^\/]*)?(.*)/.match(dir)[1]
          pp path

          # FIXME: hacks below. This is necessary because the output
          # of swineherd's ls is not compatible with the values that
          # hadoop will accept for inputs and outputs.
          path = "s3n://#{path}" if fs.class == Swineherd::S3FileSystem
          path if Regexp.new(pattern.sub(/s3n?:\/\//,'')).match path
        end.compact.sort.last
      end.compact
    end

    def old_dirs template_type, stages, fs
      if stages.size > 0
        stages.map do |stage|
          find_matching_files template_type, fs, STAGE => stage, EPOCH => '[0-9]+'
        end.flatten.compact
      else
        find_matching_files template_type, fs, EPOCH => '[0-9]+'
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
