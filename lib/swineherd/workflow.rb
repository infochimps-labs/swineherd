require 'forwardable'
require 'time'
require 'gorillib/datetime/flat'
require 'gorillib/hash/delete_multi'

module Swineherd
  class WorkflowDelegator
    extend Forwardable

    def_delegators(:@dsl_handler,
                   :describe,
                   :run,
                   :stage)
    
    def initialize child
      @dsl_handler = child
    end
  end

  class Workflow

    def initialize options = {}, &blk
      @blk = blk
      @options = options
      @options.merge! :epoch => Time.now.to_flat

      @flow_options = {
        :input_templates =>
        ["/user/$user/data/$project/$stage-$epoch-$run_number"],
        :output_templates =>
        ["/user/$user/data/$project/$stage-$epoch-$run_number"],
        :intermediate_templates =>
        ["/user/$user/tmp/$project/$stage-$epoch-$run_number"],
        :project => options[:project]
      }
      @flow_options.merge! options.delete_multi(
                                                :script_dir,
                                                :input_templates,
                                                :output_templates,
                                                :intermediate_templates
                                                )
      @stage_scripts = {}
      @finalized = false
      @parent = WorkflowDelegator.new self
    end

    ## Runs workflow starting with stagename
    def run stagename
      finalize

      Log.info("Launching workflow stage "                                      \
               "#{@flow_options[:project]}:#{stagename} ...")
      Rake::Task["#{@flow_options[:project]}:#{stagename}"].invoke
      Log.info "Workflow stage #{@flow_options[:project]}:#{stagename} finished"
    end

    ## Describes the dependency tree of all stages belonging to self
    def describe
      finalize

      Rake::Task.tasks.each do |t|
        Log.info("Stage: #{t.name} [#{t.inspect}]") if
          t.name =~ /#{@flow_options[:project]}/
      end
    end


    ## Define a new stage to be run
    def stage cls, definition, &blk

      ## extract name from definition
      case definition
        when (Symbol || String)
        name = definition
      when Hash
        name = definition.keys.first
      end

      ## create the script
      @stage_scripts[name] = cls.new(File.join(@flow_options[:script_dir],
                                               "#{name.to_s}"),
                                     @options,
                                     &blk)

      ## schedule this task for running
      task definition do
        run_stage @stage_scripts[name], name
      end
    end

    private

    ## runs user block given to constructor in parent's scope and
    ## builds input and output directories.
    def finalize
      return if @finalized

      namespace @flow_options[:project] do
        @parent.instance_eval(&@blk)
      end

      ## Sort stage names into two non-exhaustive and overlapping
      ## categories:
      ##
      ## 1. those that have prerequisites
      ## 2. those that are prerequisites
      
      remove_scope = lambda {|name| name.split(":").last.to_sym}

      all_stages = Rake::Task.tasks.map(&:name).map(&remove_scope)

      are_prerequisites = Rake::Task.tasks.map do |t|
        t.prerequisites
      end.flatten.map(&remove_scope).uniq

      have_prerequisites = Rake::Task.tasks.map do |t|
        t if t.prerequisites.size != 0
      end.compact.map(&:name).map(&remove_scope).uniq

      ## Once we've determined what category a stage is in, we can
      ## determine where it should look for its inputs and write its
      ## outputs. When we launch a workflow, we want it to take input
      ## from an input directory, write output to a series of
      ## intermediate directories, and then output to an output
      ## directory:
      ##
      ## input -[stage1]-> intermediate -[stage2]-> output

      def soft_merge stage_param, flow_param
        lambda do |stage_name|
          @stage_scripts[stage_name].
            merge_options_soft(stage_param => @flow_options[flow_param])
        end
      end

      are_prerequisites.each(&soft_merge(:output_templates,
                                         :intermediate_templates))
      have_prerequisites.each(&soft_merge(:input_templates,
                                          :intermediate_templates))
      (all_stages - are_prerequisites).each(&soft_merge(:output_templates,
                                                       :output_templates))
      (all_stages - have_prerequisites).each(&soft_merge(:input_templates,
                                                        :input_templates))

      ## Make sure each stage knows about the stages that come before
      ## it. It uses this information to find the output of the last
      ## stage.

      Rake::Task.tasks.each do |task|
        stage_name = remove_scope.call task.name
        @stage_scripts[stage_name].merge_options :last_stages =>
          task.prerequisites.map(&remove_scope)
      end

      @finalized = true
    end

    ## does the actual work of running a stage. stuff happens here.
    def run_stage script, name

      ## run things on hadoop by default
      script.merge_options_soft(
                                :run_mode => :hadoop,
                                :stage => name
                                )

      ## Check to see whether we've already run this stage.
      case script.status
      when :complete
        Log.info "I see outputs for #{name}. skipping stage."
        return
      when :failed
        Log.info("output directory for #{name} exists and does not have a "     \
                 " _SUCCESS flag. I'm assuming this is the result of a failed " \
                 "run and exiting.")
        exit -1
      end

      ## run the job
      sh script.cmd do |ok, status|
        ok ?
        script.write_success_flag :
          raise("Stage #{name} failed with exit status #{status}")
      end
    end
  end
end
