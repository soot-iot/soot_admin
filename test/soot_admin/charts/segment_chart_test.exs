defmodule SootAdmin.SegmentChartTest do
  use ExUnit.Case, async: false

  alias SootAdmin.SegmentChart
  alias SootAdmin.Test.Fixtures.VibrationP95Segment

  setup do
    for resource <- [SootSegments.SegmentRow, SootSegments.SegmentVersion] do
      try do
        :ets.delete_all_objects(resource)
      rescue
        _ -> :ok
      end
    end

    {:ok, _} = SootSegments.Registry.register(VibrationP95Segment)
    :ok
  end

  test "chart_spec/2 produces sql + columns + config" do
    spec = SegmentChart.chart_spec(VibrationP95Segment)

    assert is_binary(spec.sql)
    assert is_list(spec.columns)
    assert is_map(spec.config)
  end

  test "config defaults: title from segment name, x_axis :bucket, every metric in y_axes" do
    spec = SegmentChart.chart_spec(VibrationP95Segment)

    assert spec.config.title == "Segment vibration_p95"
    assert spec.config.x_axis == :bucket
    assert :axis_x_p95 in spec.config.y_axes
    assert :samples in spec.config.y_axes
  end

  test ":metrics opt narrows y_axes" do
    spec = SegmentChart.chart_spec(VibrationP95Segment, metrics: [:samples])

    assert spec.config.y_axes == [:samples]
    refute :axis_x_p95 in spec.config.y_axes
  end

  test ":title opt overrides the default" do
    spec = SegmentChart.chart_spec(VibrationP95Segment, title: "Vibration p95 by device")
    assert spec.config.title == "Vibration p95 by device"
  end

  test "series_for carries each metric's name + aggregation kind" do
    spec = SegmentChart.chart_spec(VibrationP95Segment)
    assert %{name: :axis_x_p95, kind: :quantile} in spec.config.series_for
    assert %{name: :samples, kind: :count} in spec.config.series_for
  end
end
