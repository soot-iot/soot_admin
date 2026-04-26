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

  @doc """
  Column specifications. This list is the documented source of truth
  for what columns `table/1` renders — keep the HEEx in sync.
  """
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

  @doc """
  Base query sorted by name. Opts:
    * `:base_query` — start from an existing `Ash.Query` instead of
      `SootSegments.SegmentRow`.
  """
  @spec query(keyword()) :: Ash.Query.t()
  def query(opts \\ []) do
    base = Keyword.get(opts, :base_query, Ash.Query.new(@resource))
    Ash.Query.sort(base, name: :asc)
  end

  attr :actor, :any, required: true
  attr :query, :any, default: nil
  attr :id, :string, default: "soot-segments"
  attr :page_size, :integer, default: 25

  def table(assigns) do
    assigns = assign(assigns, :query, assigns[:query] || query())

    ~H"""
    <Cinder.collection id={@id} query={@query} actor={@actor} page_size={@page_size}>
      <:col :let={s} field="name" filter={:text} sort>{s.name}</:col>
      <:col :let={s} field="source_stream" filter={:text} sort>{s.source_stream}</:col>
      <:col :let={s} field="granularity" filter={:select} sort>{s.granularity}</:col>
      <:col :let={s} field="status" filter={:select} sort>{s.status}</:col>
      <:col :let={s} field="current_version_id">{s.current_version_id}</:col>
      <:col :let={s} field="target">{s.target}</:col>
    </Cinder.collection>
    """
  end
end
