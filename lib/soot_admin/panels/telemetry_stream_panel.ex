defmodule SootAdmin.TelemetryStreamPanel do
  @moduledoc """
  Cinder table over `SootTelemetry.StreamRow` (the registered streams),
  with a sibling helper for showing per-(device, stream) ingest stats
  pulled from `SootTelemetry.IngestSession`.
  """

  use Phoenix.Component
  require Ash.Query

  @doc """
  Underlying Ash resource. Resolves at runtime via
  `SootTelemetry.stream_row/0` so the panel follows
  `config :soot_telemetry, stream_row: MyApp.StreamRow`.
  """
  @spec resource() :: module()
  def resource, do: SootTelemetry.stream_row()

  @doc """
  Column specifications. This list is the documented source of truth
  for what columns `table/1` renders — keep the HEEx in sync.
  """
  @spec column_specs() :: [{atom(), keyword()}]
  def column_specs do
    [
      {:name, label: "Stream", filter: :text, sort: true},
      {:status, label: "Status", filter: :select, sort: true},
      {:tenant_scope, label: "Scope", filter: :select},
      {:current_schema_id, label: "Schema id"},
      {:clickhouse_table, label: "ClickHouse table"},
      {:partitioning, label: "Partition by"}
    ]
  end

  @doc """
  Plain Ash query over StreamRow. Opts:
    * `:base_query` — start from an existing `Ash.Query` instead of
      `SootTelemetry.StreamRow`.
  """
  @spec query(keyword()) :: Ash.Query.t()
  def query(opts \\ []) do
    base = Keyword.get(opts, :base_query, Ash.Query.new(resource()))
    Ash.Query.sort(base, name: :asc)
  end

  @doc """
  Build a query for ingest sessions on a given stream. Useful in a
  detail panel below the streams table. Resolves IngestSession at
  runtime via `SootTelemetry.ingest_session/0`.
  """
  @spec ingest_sessions_query(stream_id :: Ash.UUID.t()) :: Ash.Query.t()
  def ingest_sessions_query(stream_id) do
    SootTelemetry.ingest_session()
    |> Ash.Query.filter(stream_id == ^stream_id)
    |> Ash.Query.sort(last_batch_at: :desc)
  end

  attr :actor, :any, required: true
  attr :query, :any, default: nil
  attr :id, :string, default: "soot-telemetry-streams"
  attr :page_size, :integer, default: 25

  def table(assigns) do
    assigns = assign(assigns, :query, assigns[:query] || query())

    ~H"""
    <Cinder.collection id={@id} query={@query} actor={@actor} page_size={@page_size}>
      <:col :let={s} field="name" filter={:text} sort>{s.name}</:col>
      <:col :let={s} field="status" filter={:select} sort>{s.status}</:col>
      <:col :let={s} field="tenant_scope" filter={:select}>{s.tenant_scope}</:col>
      <:col :let={s} field="current_schema_id">{s.current_schema_id}</:col>
      <:col :let={s} field="clickhouse_table">{s.clickhouse_table}</:col>
      <:col :let={s} field="partitioning">{s.partitioning}</:col>
    </Cinder.collection>
    """
  end
end
