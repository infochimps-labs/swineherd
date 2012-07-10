module Swineherd
  module SimpleUnits
    extend self # include SimpleUnits for methods on self, or call SimpleUnits.whatever

    KILOBYTE = 1024             unless defined?(KILOBYTE)
    MEGABYTE = 1024 * KILOBYTE  unless defined?(MEGABYTE)
    GIGABYTE = 1024 * MEGABYTE  unless defined?(GIGABYTE)
    TERABYTE = 1024 * GIGABYTE  unless defined?(TERABYTE)

    def to_kilobytes(size)   size and size.to_f / KILOBYTE ; end
    def to_megabytes(size)   size and size.to_f / MEGABYTE ; end
    def to_gigabytes(size)   size and size.to_f / GIGABYTE ; end
    def to_terabytes(size)   size and size.to_f / TERABYTE ; end
    #
    def from_kilobytes(size) size and size.to_f * KILOBYTE ; end
    def from_megabytes(size) size and size.to_f * MEGABYTE ; end
    def from_gigabytes(size) size and size.to_f * GIGABYTE ; end
    def from_terabytes(size) size and size.to_f * TERABYTE ; end

    # include this in your class, and define a method `bytesize`, to get
    # shorthand methods `kb`, `mb`, `gb` and `tb`
    module HasBytes
      def kb(*args)     SimpleUnits.to_kilobytes(bytesize(*args)) ; end
      def mb(*args)     SimpleUnits.to_megabytes(bytesize(*args)) ; end
      def gb(*args)     SimpleUnits.to_gigabytes(bytesize(*args)) ; end
      def tb(*args)     SimpleUnits.to_terabytes(bytesize(*args)) ; end
    end

    MINUTE  = 60                  unless defined?(MINUTE)
    HOUR    = 60       * MINUTE   unless defined?(HOUR)
    DAY     = 24       * HOUR     unless defined?(DAY)
    MONTH   = 29.53059 * DAY      unless defined?(MONTH)
    YEAR    = 365.25   * DAY      unless defined?(YEAR)

    def to_minutes(tm)   tm and tm.to_f / MINUTE ; end
    def to_hours(tm)     tm and tm.to_f / HOUR   ; end
    def to_days(tm)      tm and tm.to_f / DAY    ; end
    def to_years(tm)     tm and tm.to_f / YEAR   ; end
    #
    def from_minutes(tm) tm and tm.to_f * MINUTE ; end
    def from_hours(tm)   tm and tm.to_f * HOUR   ; end
    def from_days(tm)    tm and tm.to_f * DAY    ; end
    def from_years(tm)   tm and tm.to_f * YEAR   ; end

    # include this in your class, and define a method `duration`, to get
    # shorthand methods `sec`, `min`, `hour` &c.
    module HasDuration
      def sec( *args)                            duration(*args)  ; end
      def min( *args)     SimpleUnits.to_minutes(duration(*args)) ; end
      def hour(*args)    SimpleUnits.to_hours(   duration(*args)) ; end
    end

  end
end
