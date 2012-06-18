module Swineherd
  module Resource

    BUFSIZE = 2**16 unless defined?(Swineherd::Resource::BUFSIZE)

    def self.command_available?(bin) # :nodoc:
      bin = bin.to_s
      return @@available_query[bin] if defined?(@@available_query) and @@available_query.is_a?(::Hash) and @@available_query.has_key?(bin)
      @@available_query ||= {}
      `which #{bin}`
      @@available_query[bin] = $?.success?
    end

    def self.run_command(argv, options = {}) # :nodoc:
      argv    = argv.map(&:to_s)
      options = options.dup
      options[:chdir] = options[:chdir].to_s if options[:chdir].present?

      if options[:noop]
        Log.info(":noop set, skipping execution of #{argv.inspect} #{options.inspect}")
        return true
      end

      input =
        if (read_from = options.delete(:read_from))
          ::File.open(read_from, 'r')
        end

      output = if (write_to = options.delete(:write_to))
                 output_redirected = true
                 ::File.open(write_to, 'wb')
               else
                 output_redirected = false
                 ::StringIO.new
               end

      error = ::StringIO.new

      pid, stdin, stdout, stderr = ::POSIX::Spawn.popen4(*(argv+[options]))

      # lifted from posix-spawn
      # https://github.com/rtomayko/posix-spawn/blob/master/lib/posix/spawn/child.rb
      readers = [stdout, stderr]
      writers = if input
                  [stdin]
                else
                  stdin.close
                  []
                end
      while readers.any? or writers.any?
        ready = ::IO.select(readers, writers, readers + writers)
        # write to stdin stream
        ready[1].each do |fd|
          begin
            boom = nil
            size = fd.write(input.read(BUFSIZE))
          rescue ::Errno::EPIPE => boom
          rescue ::Errno::EAGAIN, ::Errno::EINTR
          end
          if boom || size < BUFSIZE
            stdin.close
            input.close
            writers.delete(stdin)
          end
        end
        # read from stdout and stderr streams
        ready[0].each do |fd|
          buf = (fd == stdout) ? output : error
          begin
            buf << fd.readpartial(BUFSIZE)
          rescue ::Errno::EAGAIN, ::Errno::EINTR
          rescue ::EOFError
            readers.delete(fd)
            fd.close
          end
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
      [stdin, stdout, stderr, input, output, error].each { |io| io.close if io and not io.closed? }
    end

  end
end
