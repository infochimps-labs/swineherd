module Swineherd
  module Resource
    #
    # Launch a command with input
    #
    # some code lifted from [posix-spawn](https://github.com/rtomayko/posix-spawn/blob/master/lib/posix/spawn/child.rb)
    # and from [unix-utils]()
    class CommandRunner
      include Gorillib::Model

      # Buffer size for reads and writes
      class_attribute :bufsize
      self.bufsize = 2**16
      # @private
      NO_EXIT_STATUS = OpenStruct.new(:exitstatus => 0, :success? => false)

      field :command,         Pathname, position: 0, default: Array.new
      field :noop,            :boolean, default: false
      field :env,             Hash,     default: Hash.new
      field :chdir,           Pathname
      field :unsetenv_others, :boolean
      field :input_sent,      Integer,  doc: "Count of input bytes delivered. Nil if no input stream; zero means input stream but no data sent."
      field :input_filename,  Pathname, tester: true
      field :output_filename, Pathname, tester: true

      attr_reader :pr_stdin, :pr_stdout, :pr_stderr, :pr_intos, :pr_froms, :pid, :last_status
      attr_reader :errors

      def input_stream
        @input_stream  ||= ::File.open(input_filename, 'r') if input_filename?
      end

      def output_stream
        @output_stream ||= (output_filename? ? ::File.open(output_filename, 'wb') : ::StringIO.new)
      end

      def error_stream
        @error_stream  ||= ::StringIO.new
      end

      def redirected?
        output_filename?
      end

      def running?()   pr_froms.any? || pr_intos.any?        ; end
      def exitstatus() last_status && last_status.exitstatus ; end
      def success?()   last_status && last_status.success? && errors.blank?  ; end

      def spawn_options
        compact_attributes.slice(:chdir, :unsetenv_others)  # umask rlimit_{cpu,cpor,data} pgroup
      end

      def inspect_helper
        super.tap{|attrs| attrs.merge!({exitstatus: exitstatus, errors: errors}.compact_blank) if last_status }
      end

      def description(argv=[])
        str = "'#{command}"
        str << " #{argv.join(" ")}" if argv.present?
        str << "'"
        str << " env #{env}"       if env.present?
        str << " spawn options #{spawn_options})" if spawn_options.present?
        str << " -- exitstatus #{exitstatus} (#{success? ? 'success' : 'fail'})" if last_status
        str << " !! errors #{errors.join(" - ")}" if errors.present?
        str
      end

      def run(argv=[])
        raise ArgumentError, "commandline must be an array of strings: #{argv}" unless argv.is_a?(Array)
        raise ArgumentError, "Don't forking use this for the forking version: #{command} should not be '-'"  if command.to_s == '-'
        reset!
        if noop then Log.info(":noop set, skipping execution of #{self.description(argv)}") ; return ['', '', 0] ; end
        # Log.debug{ self.description(argv) }

        # launch the command
        @pid, @pr_stdin, @pr_stdout, @pr_stderr = ::POSIX::Spawn.popen4(env.stringify_keys, command.to_s, *argv, spawn_options)

        # prepare streams
        @pr_froms = [pr_stdout, pr_stderr]
        @pr_intos = [pr_stdin]
        if not input_stream then pr_stdin.close ; pr_intos.delete(pr_stdin) ; @input_sent = nil end

        # provide input, consume output...
        while running?
          outstreams, instreams = ::IO.select(pr_froms, pr_intos, pr_froms + pr_intos)
          instreams.each{|fd|  write_to_process(fd)  }
          outstreams.each{|fd| read_from_process(fd) }
        end
        # ... and wait until finished
        ::Process.waitpid pid

        # collect and deliver the good news
        error_stream.rewind
        output_stream.rewind unless redirected?
        @last_status = $? || NO_EXIT_STATUS
        [(redirected? ? nil : output_stream.read), error_stream.read, success?]
      rescue ::Errno::ENOENT => boom
        raise ::Errno::ENOENT, "command #{command} not found", boom.backtrace
      ensure
        [ pr_stdin,      pr_stdout,      pr_stderr,
          input_stream, output_stream, error_stream].each{|stream| stream.close unless (stream.blank? || stream.closed?) }
        @input_stream = nil; @output_stream = nil; @error_stream = nil
      end

    protected

      def reset!
        @last_status = nil ; @errors = [] ; @input_sent = 0
        @input_stream = nil; @output_stream = nil; @error_stream = nil
      end

      def write_to_process(fd)
        input_chunk = input_stream.read(bufsize)
        size = fd.write(input_chunk)
        @input_sent += size
        if    (not input_chunk)             then close_input_streams
        elsif (size < input_chunk.bytesize) then close_input_streams ; errors << "Incomplete read of #{self}"
        end
      rescue ::Errno::EPIPE => boom
        errors << boom
        close_input_streams
      rescue ::Errno::EAGAIN, ::Errno::EINTR => boom
        errors << boom
      end

      def read_from_process(fd)
        buf = (fd == pr_stdout) ? output_stream : error_stream
        buf << fd.readpartial(bufsize)
      rescue ::Errno::EAGAIN, ::Errno::EINTR => boom
        errors << boom
      rescue ::EOFError
        pr_froms.delete(fd)
        fd.close
      end

      def close_input_streams
        input_stream.close
        pr_stdin.close
        pr_intos.delete(pr_stdin)
      end

    end
  end
end
