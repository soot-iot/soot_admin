defmodule SootAdmin.SegmentChart do
  @moduledoc """
  Builds the SQL + column descriptors needed to render a time-series
  chart over a segment's materialized view.

  This module is **not** a renderer — that's operator territory and
  depends on which JS chart lib they use. What this module produces:

      %{
        sql: "<SELECT … with merge expressions>",
        columns: [%{name: :bucket, type: :datetime}, ...],
        chart_meta: %{title: ..., x_axis: :bucket, y_axes: [...], series_for: [...]}
      }

  `chart_meta` is operator-side metadata — title, axis assignments,
  per-series aggregation kind — meant to be threaded into a JS chart
  lib's config. It is **not** a Vega-Lite or Chart.js spec.

  Operators run the SQL through their ClickHouse client, then plot it
  with whatever chart component they prefer.

  Deferred: a built-in renderer (likely Chart.js or ECharts via a
  separate `soot_admin_charts` shim) — out of scope for v0.1 since the
  framework already does its job by producing the SQL.
  """

  alias SootSegments.Query
  alias SootSegments.Segment.Info

  @doc """
  Build a chart spec for the segment module over the given window.

  Options forwarded to `SootSegments.Query.sql/2`:
    * `:from`, `:until`, `:dims`, `:metrics`, `:target`.

  Plus chart-specific options:
    * `:title` — override the chart title.
    * `:x_axis` — column to use as the x axis. Default `:bucket`.
  """
  @spec chart_spec(module(), keyword()) :: %{
          sql: String.t(),
          columns: [map()],
          chart_meta: %{
            title: String.t(),
            x_axis: atom(),
            y_axes: [atom()],
            series_for: [%{name: atom(), kind: atom()}]
          }
        }
  def chart_spec(segment_module, opts \\ []) do
    sql = Query.sql(segment_module, opts)
    %{columns: columns} = Query.cinder(segment_module, opts)

    metrics =
      segment_module
      |> Info.metrics()
      |> Enum.filter(&metric_in_opts?(&1, opts))

    %{
      sql: sql,
      columns: columns,
      chart_meta: %{
        title: Keyword.get(opts, :title, default_title(segment_module)),
        x_axis: Keyword.get(opts, :x_axis, :bucket),
        y_axes: Enum.map(metrics, & &1.name),
        series_for: Enum.map(metrics, &%{name: &1.name, kind: &1.aggregation})
      }
    }
  end

  defp metric_in_opts?(metric, opts) do
    case Keyword.get(opts, :metrics) do
      nil -> true
      list -> metric.name in list
    end
  end

  defp default_title(module) do
    "Segment #{Info.name(module)}"
  end
end
