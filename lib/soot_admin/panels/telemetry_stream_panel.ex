defmodule SootAdmin.TelemetryStreamPanel do
  @moduledoc """
  Cinder table over `SootTelemetry.StreamRow` (the registered streams),
  with a sibling helper for showing per-(device, stream) ingest stats
  pulled from `SootTelemetry.IngestSession`.
  """

  use Phoenix.Component
  require Ash.Query

  @resource SootTelemetry.StreamRow

  @spec resource() :: module()
  def resource, do: @resource

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

  @doc "Plain Ash query over StreamRow."
  @spec query(keyword()) :: Ash.Query.t()
  def query(opts \\ []) do
    base = Keyword.get(opts, :base_query, Ash.Query.new(@resource))
    Ash.Query.sort(base, name: :asc)
  end

  @doc """
  Build a query for ingest sessions on a given stream. Useful in a
  detail panel below the streams table.
  """
  @spec ingest_sessions_query(stream_id :: Ash.UUID.t(), keyword()) :: Ash.Query.t()
  def ingest_sessions_query(stream_id, _opts \\ []) do
    SootTelemetry.IngestSession
    |> Ash.Query.filter(stream_id == ^stream_id)
    |> Ash.Query.sort(last_batch_at: :desc)
  end

  attr :actor, :any, required: true
  attr :query, :any, default: nil
  attr :id, :string, default: "soot-telemetry-streams"

  def table(assigns) do
    assigns = assign_new(assigns, :query, fn -> query() end)

    ~H"""
    <Cinder.collection id={@id} query={@query} actor={@actor}>
      <:col :let={s} field="name" filter sort>{s.name}</:col>
      <:col :let={s} field="status" filter sort>{s.status}</:col>
      <:col :let={s} field="tenant_scope" filter>{s.tenant_scope}</:col>
      <:col :let={s} field="clickhouse_table">{s.clickhouse_table}</:col>
    </Cinder.collection>
    """
  end
end
