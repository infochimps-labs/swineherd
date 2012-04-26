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

      @flow_options = options.delete_multi(
                                            :project,
                                            :script_dir,
                                            :input_templates,
                                            :output_templates,
                                            :intermediate_templates
                                            )

      @output_counts = Hash.new{|h,k| h[k] = 0}
      @outputs       = Hash.new{|h,k| h[k] = []}
      @task_scripts = {}
      namespace @flow_options[:project] do
        self.instance_eval(&blk)
      end

      self.finalize
      
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
      Log.info "Launching workflow task #{@flow_options[:project]}:#{taskname} ..."
      Rake::Task["#{@flow_options[:project]}:#{taskname}"].invoke
      Log.info "Workflow task #{@flow_options[:project]}:#{taskname} finished"
    end

    #
    # Describes the dependency tree of all tasks belonging to self
    #
    def describe
      Rake::Task.tasks.each do |t|
        Log.info("Task: #{t.name} [#{t.inspect}]") if t.name =~ /#{@flow_options[:project]}/
      end
    end

    def finalize

      ## Sort task names into two non-exhaustive and overlapping
      ## categories:
      ##
      ## 1. those that have prerequisites
      ##
      ## 2. those that are prerequisites
      remove_scope = lambda {|name| name.split(":").last.to_sym}
      all_tasks = Rake::Task.tasks.map(&:name).map(&remove_scope)
      
      are_prerequisites = Rake::Task.tasks.map do |t| t.prerequisites
      end.flatten.map(&remove_scope)

      have_prerequisites = Rake::Task.tasks.map do |t|
        t if t.prerequisites.size == 0
      end.compact.map(&:name).map(&remove_scope)

      ## The output templates of tasks that are prerequisites for
      ## others default to the flow intermediate templates.
      are_prerequisites.each do |task_name|
        @task_scripts[task_name].
          output_templates_soft @flow_options[:intermediate_templates] 
      end

      ## The input templates of tasks that have prerequisites default
      ## to the flow intermediate templates.
      have_prerequisites.each do |task_name|
        @task_scripts[task_name].
          input_templates_soft @flow_options[:intermediate_templates] 
      end

      ## Tasks that are not prerequisites have output templates that
      ## default to the flow output templates.
      (all_tasks - are_prerequisites).each do |task_name|
          @task_scripts[task_name].
            output_templates_soft @flow_options[:output_templates] 
      end

      ## Tasks that do not have prerequisites have input templates
      ## that default to the flow input templates.
      (all_tasks - have_prerequisites).each do |task_name|
        @task_scripts[task_name].
          input_templates_soft @flow_options[:input_templates] 
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
      when Hash
        name = definition.keys.first
      end

      script = WukongScript.new(File.join(@flow_options[:script_dir],
                                          "#{name.to_s}.rb"),
                                @options,
                                &blk)

      @task_scripts[name] = script
      
      task definition do
        run_stage script, name
      end
    end
  end
end
