module Swineherd
  class RunStats
    include Gorillib::Model
    include SimpleUnits
    include SimpleUnits::HasDuration

    field :input,    Asset,    position: 0, doc: "asset consumed by this run"
    field :product,  Asset,    position: 1, doc: "asset produced by this run"
    field :executor, Executor, position: 2, doc: "context that executed this run: runner, machines, etc."
    #
    field :beg_time, Time,   doc: "Start time"
    field :end_time, Time,   doc: "End time"

    def run
      self.beg_time = Time.now
      yield
      self.end_time = Time.now
    end

    def duration
      return nil unless beg_time.present? && end_time.present?
      (end_time - beg_time).to_f
    end

    # @return true if the run is complete
    def reportable?
      !!duration
    end

    def asset(asset_name)
      raise ArgumentError, "asset name must be :input or :product" unless [:input, :product].include?(asset_name)
      read_attribute(asset_name)
    end

    #
    # Derived metrics
    #

    def gb(asset_name=:input)
      asset(asset_name).gb rescue nil
    end
    def mb(asset_name=:input)
      asset(asset_name).mb rescue nil
    end

    def gb_per_min(asset_name=:input) reportable? and gb(asset_name) / min ; end
    def min_per_gb(asset_name=:input) reportable? and 1.0 / gb_per_min(asset_name)     ; end

    def cost
      return unless reportable?
      executor.cost_per_hour * hour
    end
    def cost_per_gb(asset_name=:input)
      reportable? and cost / gb(asset_name)
    end

    def self.table_fields()
      { input:       ->(val){ val.name },
        product:     ->(val){ val.name },
        duration:    ->(val){ val.to_f.round(6) },
        min_per_gb:  ->(val){ val.to_f.round(3) },
        cost:        ->(val){ val.to_f.round(6) },
        cost_per_gb: ->(val){ val.to_f.round(3) },
        input_mb:    ->{ mb(:input)   and mb(:input  ).round(0) },
        output_mb:   ->{ mb(:product) and mb(:product).round(0) },
        executor:    ->(val){ val.name },
        }
    end
  end
end
