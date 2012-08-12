module Swineherd
  #
  # Concrete class that executes workflow segments
  #
  class Executor
    include Gorillib::Model

    field :name,          Symbol,            position: 0
    field :machines,      MachineCollection, position: 1
    field :machine_count, Integer, default: 1, doc: "number of machines"

    def cost_per_sec
      machines.values.sum{|machine| machine.cost_per_sec }
    end
    def cost_per_min()   cost_per_sec * SimpleUnits::MINUTE ; end
    def cost_per_hour()  cost_per_sec * SimpleUnits::HOUR   ; end
    def cost_per_day()   cost_per_sec * SimpleUnits::DAY    ; end
    def cost_per_month() cost_per_sec * SimpleUnits::MONTH  ; end

  end
end
