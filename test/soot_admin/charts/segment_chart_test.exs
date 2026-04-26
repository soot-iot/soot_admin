defmodule SootAdmin.SegmentChartTest do
  use ExUnit.Case, async: false

  alias SootAdmin.SegmentChart
  alias SootAdmin.Test.Fixtures.VibrationP95Segment

  setup do
    for resource <- [SootSegments.SegmentRow, SootSegments.SegmentVersion] do
      if :ets.whereis(resource) != :undefined do
        :ets.delete_all_objects(resource)
      end
    end

    {:ok, _} = SootSegments.Registry.register(VibrationP95Segment)
    :ok
  end

  test "chart_spec/2 produces sql + columns + chart_meta" do
    spec = SegmentChart.chart_spec(VibrationP95Segment)

    assert is_binary(spec.sql)
    assert is_list(spec.columns)
    assert is_map(spec.chart_meta)
  end

  test "config defaults: title from segment name, x_axis :bucket, every metric in y_axes" do
    spec = SegmentChart.chart_spec(VibrationP95Segment)

    assert spec.chart_meta.title == "Segment vibration_p95"
    assert spec.chart_meta.x_axis == :bucket
    assert :axis_x_p95 in spec.chart_meta.y_axes
    assert :samples in spec.chart_meta.y_axes
  end

  test ":metrics opt narrows y_axes" do
    spec = SegmentChart.chart_spec(VibrationP95Segment, metrics: [:samples])

    assert spec.chart_meta.y_axes == [:samples]
    refute :axis_x_p95 in spec.chart_meta.y_axes
  end

  test ":title opt overrides the default" do
    spec = SegmentChart.chart_spec(VibrationP95Segment, title: "Vibration p95 by device")
    assert spec.chart_meta.title == "Vibration p95 by device"
  end

  test "series_for carries each metric's name + aggregation kind" do
    spec = SegmentChart.chart_spec(VibrationP95Segment)
    assert %{name: :axis_x_p95, kind: :quantile} in spec.chart_meta.series_for
    assert %{name: :samples, kind: :count} in spec.chart_meta.series_for
  end

  test ":from / :until forward to the SQL window predicate" do
    from = ~U[2026-04-25 00:00:00Z]
    until = ~U[2026-04-26 00:00:00Z]

    spec = SegmentChart.chart_spec(VibrationP95Segment, from: from, until: until)

    assert spec.sql =~ "bucket >= '2026-04-25T00:00:00Z'"
    assert spec.sql =~ "bucket <  '2026-04-26T00:00:00Z'"
  end

  test ":dims narrows the columns list" do
    spec = SegmentChart.chart_spec(VibrationP95Segment, dims: [:device_id])

    column_names = Enum.map(spec.columns, & &1.name)
    assert :device_id in column_names
    refute :tenant_id in column_names
  end

  test ":target overrides the MV table name in the SQL" do
    spec = SegmentChart.chart_spec(VibrationP95Segment, target: "vibration_p95_v42_archive")

    assert spec.sql =~ "FROM vibration_p95_v42_archive"
  end
end
