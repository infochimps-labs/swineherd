module Swineherd
  class StreamScript < Stage

    def format_script_options
    end

    #
    # Don't treat wukong scripts as templates
    #
    def script
      @source
    end

    def script_cmd
      part_fields = @options[:part_fields] || 1
      sort_fields = @options[:sort_fields] || 1

      job_name = ("#{@stage_options[:project]}:#{@stage_options[:stage]}:" \
                  "#{@stage_options[:epoch]}")

      hadoop = File.join @stage_options[:hadoop_home] || '', "bin/hadoop"
      stream_jar = File.join(@stage_options[:hadoop_home] || '',
                             "contrib/streaming/hadoop-*streaming*.jar")

      return <<EOF
#{hadoop} \
    jar         #{stream_jar} \
    $@ \
    -D   num.key.fields.for.partition="#{part_fields}" \
    -D 	 stream.num.map.output.key.fields="#{sort_fields}" \
    -D   stream.map.output.field.separator="'/t'" \
    -D   mapred.text.key.partitioner.options="-k1,#{part_fields}" \
    -D   mapred.job.name="`basename $0`-#{job_name}" \
    -partitioner org.apache.hadoop.mapred.lib.KeyFieldBasedPartitioner \
    -mapper  	 "#{@options[:map_script]}" \
    -reducer	 "#{@options[:reduce_script]}" \
    -input       "#{inputs.join ','}" \
    -output  	 "#{outputs.join ','}"
EOF
    end
  end
end
