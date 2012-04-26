require 'time'
require 'gorillib/datetime/flat'
require 'gorillib/hash/delete_multi'

module Swineherd
  class Workflow
    attr_accessor :workdir, :outputs, :output_counts
    
    #
    # Create a new workflow and new namespace for this workflow
    #
    def initialize options = {}, &blk
      @options = options
      @options.merge! :epoch => Time.now.to_flat

      @stage_options = options.delete_multi(
                                            :project,
                                            :script_dir,
                                            :input_templates,
                                            :output_templates,
                                            :intermediate_templates
                                            )

      @output_counts = Hash.new{|h,k| h[k] = 0}
      @outputs       = Hash.new{|h,k| h[k] = []}
      namespace @stage_options[:project] do
        self.instance_eval(&blk)
      end
    end

    #
    # Get next logical output of taskname by incrementing internal counter
    #
    def next_output taskname
      raise "No working directory specified." unless @workdir
      @outputs[taskname] << "#{@workdir}/#{@project}/#{taskname}-#{@output_counts[taskname]}"
      @output_counts[taskname] += 1
      latest_output(taskname)
    end

    #
    # Get latest output of taskname
    #
    def latest_output taskname
      @outputs[taskname].last
    end

    #
    # Runs workflow starting with taskname
    #
    def run taskname
      Log.info "Launching workflow task #{@stage_options[:project]}:#{taskname} ..."
      Rake::Task["#{@stage_options[:project]}:#{taskname}"].invoke
      Log.info "Workflow task #{@stage_options[:project]}:#{taskname} finished"
    end

    #
    # Describes the dependency tree of all tasks belonging to self
    #
    def describe
      Rake::Task.tasks.each do |t|
        Log.info("Task: #{t.name} [#{t.inspect}]") if t.name =~ /#{@stage_options[:project]}/
      end
    end

    def run_stage script, name

      ## See if we've already run this stage.
      script.outputs.each do |output|
        success_dir = File.join output, "_SUCCESS"
        if script.fs.exists? success_dir then
          Log.info "I see #{success_dir}. skipping stage."
          return
        elsif script.fs.exists? output then
          Log.info("#{output} exists and does not have a _SUCCESS flag. "       \
                   "I'm assuming this is the result of a failed hadoop job "    \
                   "and exiting.")
          exit -1
        end
      end
      
      ## determine whether this is a local or hadoop job
      mode = script.options[:mode] || :hadoop
      command = case mode
                when :local then :local_cmd
                when :hadoop then :cmd
                end

      ## run the job
      sh (script.send command) do |ok, status|
        ok or raise "#{mode.to_s.capitalize} mode script failed with exit status #{status}"
      end

    end

    def wukong_stage definition, &blk
      case definition
      when (Symbol || String)
        name = definition
        input_templates = @stage_options[:input_templates]
      when Hash
        name = definition.keys.first
        input_templates = @stage_options[:intermediate_templates]
      end

      script = WukongScript.new(File.join(@stage_options[:script_dir],
                                          "#{name.to_s}.rb"),
                                input_templates,
                                @stage_options[:intermediate_templates],
                                @options,
                                &blk)
      
      task definition do
        run_stage script, name
      end
    end
  end
end
