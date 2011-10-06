module Swineherd

  #
  # Methods for dealing with hadoop distributed file system (hdfs). This class
  # requires that you run with JRuby as it makes use of the native java hadoop
  # libraries.
  #
  class HadoopFileSystem

    include Swineherd::BaseFileSystem

    attr_accessor :conf, :hdfs

    #
    # Initialize a new hadoop file system, needs path to hadoop configuration
    #
    def initialize params={}, *args
      check_and_set_environment
      @conf = Java::org.apache.hadoop.conf.Configuration.new
      uri = Java::java.net.URI.new params[:filesystem] if params[:filesystem]
      fs_params = uri ? [ uri, @conf ] : [ @conf ]
      @hdfs = Java::org.apache.hadoop.fs.FileSystem.get *fs_params
    end

    #
    # Make sure environment is sane then set up environment for use
    #
    def check_and_set_environment
      check_env
      set_env
    end

    def open path, mode="r", &blk
      HadoopFile.new(path,mode,self,&blk)
    end

    def size path
      lr(path).inject(0){|sz, f| sz += @hdfs.get_file_status(Path.new(f)).get_len}
    end

    #
    # Recursively list paths
    #
    def lr path
      paths = entries(path)
      if (paths && !paths.empty?)
        paths.map{|e| lr(e)}.flatten
      else
        path
      end
    end
    
    def rm path
      @hdfs.delete(Path.new(path), true)
      [path]
    end

    def exists? path
      @hdfs.exists(Path.new(path))
    end

    def mv srcpath, dstpath
      @hdfs.rename(Path.new(srcpath), Path.new(dstpath))
    end

    def cp srcpath, dstpath
      FileUtil.copy(@hdfs, Path.new(srcpath), @hdfs, Path.new(dstpath), false, @conf)
    end

    def mkpath path
      @hdfs.mkdirs(Path.new(path))
      path
    end

    def type path
      return "unknown" unless exists? path
      status = @hdfs.get_file_status(Path.new(path))
      return "directory" if status.is_dir?
      "file"
      # case
      # when status.isFile then
      #   return "file"
      # when status.is_directory? then
      #   return "directory"
      # when status.is_symlink? then
      #   return "symlink"
      # end
    end

    def entries dirpath
      return unless type(dirpath) == "directory"
      list = @hdfs.list_status(Path.new(dirpath))
      list.map{|path| path.get_path.to_s} rescue []
    end

    #
    # Merge all part files in a directory into one file.
    #
    def merge srcdir, dstfile
      FileUtil.copy_merge(@hdfs, Path.new(srcdir), @hdfs, Path.new(dstfile), false, @conf, "")
    end

    #
    # This is hackety. Use with caution.
    #
    def stream input, output
      require 'uri'
      input_fs_scheme  = URI.parse(input).scheme
      output_fs_scheme = URI.parse(output).scheme
      system("#{@hadoop_home}/bin/hadoop \\
       jar         #{@hadoop_home}/contrib/streaming/hadoop-*streaming*.jar                     \\
       -D          mapred.job.name=\"Stream { #{input_fs_scheme}(#{File.basename(input)}) -> #{output_fs_scheme}(#{File.basename(output)}) }\" \\
       -D          mapred.min.split.size=1000000000                                            \\
       -D          mapred.reduce.tasks=0                                                       \\
       -mapper     \"/bin/cat\"                                                                \\
       -input      \"#{input}\"                                                                \\
       -output     \"#{output}\"")
    end

    #
    # BZIP
    #
    def bzip input, output
      system("#{@hadoop_home}/bin/hadoop \\
       jar         #{@hadoop_home}/contrib/streaming/hadoop-*streaming*.jar     \\
       -D          mapred.output.compress=true                                  \\
       -D          mapred.output.compression.codec=org.apache.hadoop.io.compress.BZip2Codec  \\
       -D          mapred.reduce.tasks=1                                        \\
       -mapper     \"/bin/cat\"                                                 \\
       -reducer    \"/bin/cat\"                                                 \\
       -input      \"#{input}\"                                                 \\
       -output     \"#{output}\"")
    end

    #
    # Merges many input files into :reduce_tasks amount of output files
    #
    def dist_merge inputs, output, options = {}
      options[:reduce_tasks]     ||= 25
      options[:partition_fields] ||= 2
      options[:sort_fields]      ||= 2
      options[:field_separator]  ||= '/t'
      names = inputs.map{|inp| File.basename(inp)}.join(',')
      cmd   = "#{@hadoop_home}/bin/hadoop \\
       jar         #{@hadoop_home}/contrib/streaming/hadoop-*streaming*.jar                   \\
       -D          mapred.job.name=\"Swineherd Merge (#{names} -> #{output})\"               \\
       -D          num.key.fields.for.partition=\"#{options[:partition_fields]}\"            \\
       -D          stream.num.map.output.key.fields=\"#{options[:sort_fields]}\"             \\
       -D          mapred.text.key.partitioner.options=\"-k1,#{options[:partition_fields]}\" \\
       -D          stream.map.output.field.separator=\"'#{options[:field_separator]}'\"      \\
       -D          mapred.min.split.size=1000000000                                          \\
       -D          mapred.reduce.tasks=#{options[:reduce_tasks]}                             \\
       -partitioner org.apache.hadoop.mapred.lib.KeyFieldBasedPartitioner                    \\
       -mapper     \"/bin/cat\"                                                              \\
       -reducer    \"/usr/bin/uniq\"                                                         \\
       -input      \"#{inputs.join(',')}\"                                                   \\
       -output     \"#{output}\""
      puts cmd
      system cmd
    end

    #
    # Copy hdfs file to local filesystem
    #
    def copy_to_local srcfile, dstfile
      @hdfs.copy_to_local_file(Path.new(srcfile), Path.new(dstfile))
    end

    #
    # Copy local file to hdfs filesystem
    #
    def copy_from_local srcfile, dstfile
      @hdfs.copy_from_local_file(Path.new(srcfile), Path.new(dstfile))
    end

    def close *args
      @hdfs.close
    end

    class HadoopFile
      attr_accessor :path, :handle, :hdfs

      #
      # In order to open input and output streams we must pass around the hadoop fs object itself
      #
      def initialize path, mode, fs, &blk
        @fs   = fs
        @path = Path.new(path)
        case mode
        when "r" then
          raise "#{@fs.type(path)} is not a readable file - #{path}" unless @fs.type(path) == "file"
          @handle = @fs.hdfs.open(@path).to_io(&blk)
        when "w" then
          # Open path for writing
          raise "Path #{path} is a directory." unless (@fs.type(path) == "file") || (@fs.type(path) == "unknown")
          @handle = @fs.hdfs.create(@path).to_io.to_outputstream
          if block_given?
            yield self
            self.close # muy muy importante
          end
        end
      end

      def read
        @handle.read
      end

      def readline
        @handle.readline
      end

      def write string
        @handle.write(string.to_java_string.get_bytes)
      end

      def puts string
        write(string+"\n")
      end

      def close
        @handle.close
      end

    end

    # #
    # # Distributed streaming from input to output
    # #
    #
    # #
    # # Given an array of input dirs, stream all into output dir and remove duplicate records.
    # # Reasonable default hadoop streaming options are chosen.
    # #
    # def self.merge inputs, output, options = {}
    #   options[:reduce_tasks]     ||= 25
    #   options[:partition_fields] ||= 2
    #   options[:sort_fields]      ||= 2
    #   options[:field_separator]  ||= '/t'
    #   names = inputs.map{|inp| File.basename(inp)}.join(',')
    #   cmd   = "${HADOOP_HOME}/bin/hadoop \\
    #    jar         ${HADOOP_HOME}/contrib/streaming/hadoop-*streaming*.jar                   \\
    #    -D          mapred.job.name=\"Swineherd Merge (#{names} -> #{output})\"               \\
    #    -D          num.key.fields.for.partition=\"#{options[:partition_fields]}\"            \\
    #    -D          stream.num.map.output.key.fields=\"#{options[:sort_fields]}\"             \\
    #    -D          mapred.text.key.partitioner.options=\"-k1,#{options[:partition_fields]}\" \\
    #    -D          stream.map.output.field.separator=\"'#{options[:field_separator]}'\"      \\
    #    -D          mapred.min.split.size=1000000000                                          \\
    #    -D          mapred.reduce.tasks=#{options[:reduce_tasks]}                             \\
    #    -partitioner org.apache.hadoop.mapred.lib.KeyFieldBasedPartitioner                    \\
    #    -mapper     \"/bin/cat\"                                                              \\
    #    -reducer    \"/usr/bin/uniq\"                                                         \\
    #    -input      \"#{inputs.join(',')}\"                                                   \\
    #    -output     \"#{output}\""
    #   puts cmd
    #   system cmd
    # end
    #
    # #
    # # Concatenates a hadoop dir or file into a local file
    # #
    # def self.cat_to_local src, dest
    #   system %Q{hadoop fs -cat #{src}/[^_]* > #{dest}} unless File.exist?(dest)
    # end
    #

    #
    # Check that we are running with jruby, check for hadoop home. hadoop_home
    # is preferentially set to the HADOOP_HOME environment variable if it's set,
    # '/usr/local/share/hadoop' if HADOOP_HOME isn't defined, and
    # '/usr/lib/hadoop' if '/usr/local/share/hadoop' doesn't exist. If all else
    # fails inform the user that HADOOP_HOME really should be set.
    #
    def check_env
      begin
        require 'java'
      rescue LoadError => e
        raise "\nJava not found, are you sure you're running with JRuby?\n" + e.message
      end
      @hadoop_home = (ENV['HADOOP_HOME'] || '/usr/local/share/hadoop')
      @hadoop_home = '/usr/lib/hadoop' unless File.exist? @hadoop_home
      raise "\nHadoop installation not found, try setting HADOOP_HOME\n" unless File.exist? @hadoop_home
    end

    #
    # Place hadoop jars in class path, require appropriate jars, set hadoop conf
    #
    def set_env
      require 'java'
      @hadoop_conf = (ENV['HADOOP_CONF_DIR'] || File.join(@hadoop_home, 'conf'))
      @hadoop_conf += "/" unless @hadoop_conf.end_with? "/"
      $CLASSPATH << @hadoop_conf
      Dir["#{@hadoop_home}/hadoop*.jar", "#{@hadoop_home}/lib/*.jar"].each{|jar| require jar}

      java_import 'org.apache.hadoop.conf.Configuration'
      java_import 'org.apache.hadoop.fs.Path'
      java_import 'org.apache.hadoop.fs.FileSystem'
      java_import 'org.apache.hadoop.fs.FileUtil'
      java_import 'org.apache.hadoop.mapreduce.lib.input.FileInputFormat'
      java_import 'org.apache.hadoop.mapreduce.lib.output.FileOutputFormat'
      java_import 'org.apache.hadoop.fs.FSDataOutputStream'
      java_import 'org.apache.hadoop.fs.FSDataInputStream'

    end

  end

end
