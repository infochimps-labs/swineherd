module Swineherd
  class PigScript < Stage

    def finalize
      self.source = "#{self.source}.pig.erb"
      super
    end

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

    def format_options
      @options.merge!(:x => "local") if @options[:run_mode] == :local
      
      options.select{|k,v| k != :run_mode}.map do |param,val|
        case val
        when nil then "--#{param}"
        else "--#{param}=#{val}"
        end
      end.join(' ')
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

    def cmd
      super
      "pig #{pig_args(@options)} #{script}"
    end

  end
end
