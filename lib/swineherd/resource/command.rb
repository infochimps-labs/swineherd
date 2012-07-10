module Swineherd
  module Resource

    class RunStats
      field :beg_time, Time, position: 0, doc: "Start time"
      field :end_time,
    end

    class Command
      include Gorillib::Model
      include Gorillib::CheckedPopen

      class_attribute :exe_path

      def run

      end

      def run_with_stats(command, stdin)
        start  = Time.now
        finish =
      end


    end
  end
end
