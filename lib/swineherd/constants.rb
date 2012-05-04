module SwineHerd

  # These options are pulled out of the hash sent to Workflow before
  # the hash is sent to each stage.
  module WorkflowOptions
    SCRIPT_DIR = :script_dir
    INPUT_TEMPLATES = :input_templates
    OUTPUT_TEMPLATES = :output_templates
    INTERMEDIATE_TEMPLATES = :intermediate_templates
  end

  # These options are pulled out of the hash sent to Workflow before
  # the rest of the options are sent to the script.
  module StageOptions
      USER = :user
      PROJECT = :project
      RUN_NUMBER = :run_number
      RUN_MODE = :run_mode
      EPOCH = :epoch
      STAGE = :stage
      LAST_STAGES = :last_stages
      INPUT_TEMPLATES = :input_templates
      OUTPUT_TEMPLATES = :output_templates
      HADOOP_HOME = :hadoop_home
      FSTYPE = :fstype
      IN_FSTYPE = :in_fstype
      OUT_FSTYPE = :out_fstype
  end

  module SharedOptions
    PROJECT = :project
    EPOCH = :epoch
  end

  module PigOptions
    INPUTS = :inputs
    OUTPUTS = :outputs
  end

  module AllOptions
    include WorkflowOptions
    include SharedOptions
    include StageOptions
    include PigOptions
  end

end
