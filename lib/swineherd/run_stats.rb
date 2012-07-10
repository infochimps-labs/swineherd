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
      [:input, :product, :duration, :min_per_gb, :cost, :cost_per_gb, :input_mb, :output_mb, :executor]
    end
    def table_attributes
      super.tap do |hsh|
        hsh.merge!(
          input_mb:      mb(:input),
          output_mb:     mb(:product),
          )
        hsh[:input]    = input.name
        hsh[:product]  = product.name
        hsh[:executor] = executor.name
      end
    end
    def self.table_fixup()
      super.merge(
        input_mb:      ->(val){ val.to_f.round(3) },
        output_mb:     ->(val){ val.to_f.round(3) },
        min_per_gb:    ->(val){ val.to_f.round(3) },
        cost:          ->(val){ val.to_f.round(6) },
        cost_per_gb:   ->(val){ val.to_f.round(2) },
        )
    end
  end
end
