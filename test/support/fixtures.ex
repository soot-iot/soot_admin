defmodule SootAdmin.Test.Fixtures.VibrationStream do
  @moduledoc false
  use SootTelemetry.Stream.Definition

  telemetry_stream do
    name :vibration
    tenant_scope(:per_tenant)

    fields do
      field :ts, :timestamp_us, required: true
      field :tenant_id, :string, dictionary: true, server_set: true
      field :device_id, :string, dictionary: true
      field :axis_x, :float32
      field :sequence, :uint64, monotonic: true
    end

    clickhouse do
      order_by([:tenant_id, :device_id, :ts])
    end
  end
end

defmodule SootAdmin.Test.Fixtures.VibrationP95Segment do
  @moduledoc false
  use SootSegments.Segment.Definition

  segment do
    name :vibration_p95
    source_stream(:vibration)
    granularity(:hour)

    dimensions do
      dimension(:tenant_id)
      dimension(:device_id)
    end

    metrics do
      metric(:axis_x_p95, :quantile, column: :axis_x, q: 0.95)
      metric(:samples, :count)
    end
  end
end
