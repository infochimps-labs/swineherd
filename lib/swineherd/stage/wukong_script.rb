require 'pathname'

module Swineherd
  class WukongScript < Stage

    def format_script_options
      case @stage_options[:run_mode]
      when :local
        @options.merge! :run => "local"
      when :hadoop
        @options.merge! :run => nil
      end
    end

    #
    # Don't treat wukong scripts as templates
    #
    def script
      @source
    end

    def script_cmd
      "ruby #{script}.rb #{format_options} #{inputs.join(',')} #{outputs.join(',')}"
    end
  end
end
