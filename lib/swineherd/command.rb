module Swineherd

  #
  # Represents a command:
  #
  # * runnable (via command_runner, among others)
  # * exposes named options
  #
  # Named options are opinionated: see [how_to_name_options.md] in the notes directory
  # or swineherd wiki.
  #
  class Command
    include Gorillib::Model
  end


end
