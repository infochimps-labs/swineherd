require 'pathname'

module Swineherd
  class WukongScript < Stage

    def format_options
      command = case @options[:run_mode]
                when :local
                  @options.merge! :run => "local"
                when :hadoop
                  @options.merge! :run => nil
                end
      
      options.select{|k,v| k != :run_mode}.map do |param,val|
        case val
        when nil then "--#{param}"
        else "--#{param}=#{val}"
        end
      end.join(' ')
    end

    #
    # Don't treat wukong scripts as templates
    #
    def script
      @source
    end

    def cmd
      super
      "ruby #{script}.rb #{format_options} #{inputs.join(',')} #{outputs.join(',')}"
    end
  end
end
