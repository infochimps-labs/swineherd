module Swineherd
  class Machine
    include Gorillib::Model

    field :name,          Symbol,  doc: "label for this executor",             position: 0
    #
    field :ram,           Integer, doc: "memory, in megabytes, per node",      position: 1
    field :cpus,          Integer, doc: "number of CPUs",                      position: 2
    field :cores,         Integer, doc: "total number of cores",               position: 3
    field :core_speed,    Integer, doc: "nominal speed of each core",          position: 4
    field :network,       Integer, doc: "nominal network speed in megabits/s", position: 5
    field :cost_per_hour, Float,   doc: "machine cost per hour",               position: 6
    field :disk_size,     Integer, doc: "size of disk in megabytes"

    def cost_per_sec()   cost_per_hour / SimpleUnits::HOUR   ; end
    def cost_per_min()   cost_per_sec  * SimpleUnits::MINUTE ; end
    def cost_per_day()   cost_per_sec  * SimpleUnits::DAY    ; end
    def cost_per_month() cost_per_sec  * SimpleUnits::MONTH  ; end

    def self.amortized_cost(sale_price, depreciation_years)
      hrs = SimpleUnits.to_hours(SimpleUnits.from_years(depreciation_years.to_f))
      sale_price.to_f / hrs
    end

    def self.table_fields()
      [:name, :ram, :cpus, :cores, :core_speed, :network, :cost_per_hour, :cost_per_day ]
    end
    def self.table_fixup()
      super.merge(
        cost_per_hour: ->(val){ val.to_f.round(4) },
        cost_per_day:  ->(val){ val.to_f.round(2) }, )
    end
  end

  class MachineCollection < Gorillib::ModelCollection
    self.item_type  = Swineherd::Machine
    self.key_method = :name
  end

  ExampleMachines = MachineCollection.receive([
      Machine.new(:laptop,    (8.0*1024), 1, 4, nil, 100, Machine.amortized_cost(2500, 3), disk_size: 500*1024),
      Machine.new(:m1_large,  (7.5*1024), 2, 2, 2,   100, 0.32, disk_size:  850*1024),
      Machine.new(:c1_xlarge, (7.0*1024), 4, 8, 2.5, 100, 0.66, disk_size: 1690*1024),
    ])

end
