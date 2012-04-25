require 'pathname'

module Swineherd::Script
  class WukongScript
    include Common

    def wukong_args options
      options.map{|param,val| "--#{param}=#{val}" }.join(' ')
    end

    #
    # Don't treat wukong scripts as templates
    #
    def script
      @source
    end

    def cmd
      Log.info("Launching Wukong script in hadoop mode")
      "ruby #{script} #{wukong_args(@options)} --run #{inputs.join(',')} #{output.join(',')}"
    end

    def local_cmd
      #inputs = inputs.map{|path| path += File.directory?(path) ? "/*" : ""}.join(',')
      Log.info("Launching Wukong script in local mode")
      "ruby #{script} #{wukong_args(@options)} --run=local #{inputs} #{output.join(',')}"
    end

  end
end
