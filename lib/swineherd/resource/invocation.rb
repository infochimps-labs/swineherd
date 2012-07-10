module Swineherd
  module Resource
    class Invocation
      include Gorillib::Model

      # Buffer size for reads and writes
      class_attribute :bufsize
      self.bufsize = 2**16

      @@command_path  = Hash.new unless defined?(@@command_path)
      @@command_avail = Hash.new unless defined?(@@command_avail)

      field :chdir, Pathname
      field :argv,  Array
      field :noop,  :boolean, tester: true

      field :input_filename,  Pathname, tester: true
      field :output_filename, Pathname, tester: true

      def input
        @input ||= ::File.open(input_filename, 'r') if input_filename?
      end

      def output
        return @output if @output
        if output_filename?
          @output = ::File.open(output_filename, 'wb')
        else
          @output = ::StringIO.new
        end
      end

      def error
        @error ||= ::StringIO.new
      end

      def available?(command_path)
        command_path = command_path.to_s
        return @@command_avail[command_path] if @@command_avail.has_key?(command_path)
        system('which', command_path)
        @@command_avail[command_path] = $?.success?
      end

      def redirected?
        output_filename?
      end

      # class Invocation
      attr_accessor :pid, :stdin, :stdout, :stderr, :readers, :writers

      def spawn(argv, options)
        argv    = argv.map(&:to_s)
        options = options.symbolize_keys
        if noop then Log.info(":noop set, skipping execution of #{self.inspect}") ; return true ; end

        @pid, @process_stdin, @process_stdout, @process_stderr = ::POSIX::Spawn.popen4(*argv, options)

        # lifted from posix-spawn
        # https://github.com/rtomayko/posix-spawn/blob/master/lib/posix/spawn/child.rb
        @readers = [process_stdout, process_stderr]
        @writers = if input then [process_stdin]
                   else          process_stdin.close ; [] ; end
        while readers.any? or writers.any?
          process_outstreams, process_instreams = ::IO.select(readers, writers, readers + writers)
          # write to process_stdin stream
          process_instreams.each do |fd|
            write_to_process(fd)
          end
          # read from process_stdout and process_stderr streams
          input_streams.each do |fd|
            buf = (fd == process_stdout) ? output : error
            read_from_process(fd, buf)
          end
        end
        # thanks @tmm1 and @rtomayko for showing how it's done!

        ::Process.waitpid pid

        error.rewind
        unless (whole_error = error.read).empty?
          $stderr.puts "[Swineherd::Resource] `#{argv.join(' ')}` STDERR:"
          $stderr.puts whole_error
        end

        unless output_redirected
          output.rewind
          output.read
        end
      ensure
        [process_stdin, process_stdout, process_stderr, input, output, error].each{|io| io.close unless (io.blank? || io.closed?) }
      end

      def running?
        [@process_stdout, @process_stderr, @process_stdin]
      end

      def write_to_process
        begin
          boom = nil
          size = fd.write(input.read(BUFSIZE))
        rescue ::Errno::EPIPE => boom
          close_input_streams
        rescue ::Errno::EAGAIN, ::Errno::EINTR
        end
        if size < bufsize
          close_input_streams
        end
      end

      def read_from_process(fd, buf)
        begin
          buf << fd.readpartial(bufsize)
        rescue ::Errno::EAGAIN, ::Errno::EINTR
        rescue ::EOFError
          readers.delete(fd)
          fd.close
        end
      end

      def close_input_streams
        process_stdin.close
        input.close
        writers.delete(process_stdin)
      end
    end
  end
end
