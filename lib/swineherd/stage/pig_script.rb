module Swineherd
  class PigScript < Stage

    #
    # Not guaranteeing anything.
    #
    AVRO_PIG_MAPPING = {
      'string' => 'chararray',
      'int'    => 'int',
      'long'   => 'long',
      'float'  => 'float',
      'double' => 'double',
      'bytes'  => 'bytearray',
      'fixed'  => 'bytearray'
    }

    def source
      return "#{@source}.pig.erb"
    end

    def format_script_options
      @options.merge!(:x => "local") if @options[:run_mode] == :local
    end

    #
    # Simple utility function for mapping avro types to pig types
    #
    def self.avro_to_pig avro_type
      AVRO_PIG_MAPPING[avro_type]
    end

    #
    # Convert a generic hash of options {:foo => 'bar'} into
    # command line options for pig '-p FOO=bar'
    #
    def pig_args options
      options.map{|opt,val| "-p #{opt.to_s.upcase}=#{val}" }.join(' ')
    end

    def script_cmd
      "pig #{pig_args(@options)} #{script}"
    end

  end
end
