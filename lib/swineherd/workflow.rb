module Swineherd
  class Workflow
    attr_accessor :workdir, :outputs, :output_counts
    
    #
    # Create a new workflow and new namespace for this workflow
    #
    def initialize options = {}, &blk
      @options = options
      @project = options[:project]
      @script_dir = options[:script_dir]
      @input_templates = options[:input_templates]
      @output_templates = options[:output_templates]
      @intermediate_templates = options[:intermediate_templates]

      @output_counts = Hash.new{|h,k| h[k] = 0}
      @outputs       = Hash.new{|h,k| h[k] = []}
      namespace @project do
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
      Log.info "Launching workflow task #{@project}:#{taskname} ..."
      Rake::Task["#{@project}:#{taskname}"].invoke
      Log.info "Workflow task #{@project}:#{taskname} finished"
    end

    #
    # Describes the dependency tree of all tasks belonging to self
    #
    def describe
      Rake::Task.tasks.each do |t|
        Log.info("Task: #{t.name} [#{t.inspect}]") if t.name =~ /#{@project}/
      end
    end

    def wukong_stage definition, &blk
      case definition
      when (Symbol || String)
        name = definition
        input_templates = @input_templates
      when Hash
        name = definition.keys.first
        input_templates = @intermediate_templates
      end

      script = WukongScript.new(File.join(@script_dir,
                                          "#{name.to_s}.rb"),
                                input_templates,
                                @intermediate_templates,
                                @options,
                                &blk)
      
      task definition do
        script.run
      end
    end
  end
end
