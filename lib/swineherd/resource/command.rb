module Swineherd
  module Resource

    class Command
      include Gorillib::Model
      include Gorillib::CheckedPopen

      # handle to the Pathname.register_path'ed executable for this command type
      class_attribute :exe_path_handle
      # executable pathname
      def exe_path
        Pathname.path_to(exe_path_handle)
      end

      def run(*argv)
        checked_popen [exe_path, *argv] do |process|
          p process
        end
      end
    end

    class CopyCommand < Command
      self.exe_path_handle = :cp_exe
    end

  end
end
