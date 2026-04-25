defmodule SootAdmin.SegmentTable do
  @moduledoc """
  Cinder table over `SootSegments.SegmentRow` (registered segments).

  The companion `SootAdmin.SegmentChart` (separate module) renders a
  time-series chart from the corresponding ClickHouse MV via
  `SootSegments.Query.sql/2`. Charting requires an operator-supplied
  ClickHouse runner; this library produces the SQL but does not run
  it.
  """

  use Phoenix.Component
  require Ash.Query

  @resource SootSegments.SegmentRow

  @spec resource() :: module()
  def resource, do: @resource

  @spec column_specs() :: [{atom(), keyword()}]
  def column_specs do
    [
      {:name, label: "Segment", filter: :text, sort: true},
      {:source_stream, label: "Source", filter: :text, sort: true},
      {:granularity, label: "Granularity", filter: :select, sort: true},
      {:status, label: "Status", filter: :select, sort: true},
      {:current_version_id, label: "Version id"},
      {:target, label: "MV target"}
    ]
  end

  @spec query(keyword()) :: Ash.Query.t()
  def query(opts \\ []) do
    base = Keyword.get(opts, :base_query, Ash.Query.new(@resource))
    Ash.Query.sort(base, name: :asc)
  end

  attr :actor, :any, required: true
  attr :query, :any, default: nil
  attr :id, :string, default: "soot-segments"

  def table(assigns) do
    assigns = assign_new(assigns, :query, fn -> query() end)

    ~H"""
    <Cinder.Table.table id={@id} query={@query} actor={@actor}>
      <:col :let={s} field="name" filter sort>{s.name}</:col>
      <:col :let={s} field="source_stream" filter sort>{s.source_stream}</:col>
      <:col :let={s} field="granularity" filter sort>{s.granularity}</:col>
      <:col :let={s} field="status" filter sort>{s.status}</:col>
      <:col :let={s} field="target">{s.target}</:col>
    </Cinder.Table.table>
    """
  end
end
