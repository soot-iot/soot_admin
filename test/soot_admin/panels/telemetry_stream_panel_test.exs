defmodule SootAdmin.TelemetryStreamPanelTest do
  use ExUnit.Case, async: true

  alias SootAdmin.TelemetryStreamPanel

  test "resource and columns" do
    assert TelemetryStreamPanel.resource() == SootTelemetry.StreamRow

    fields = TelemetryStreamPanel.column_specs() |> Enum.map(&elem(&1, 0))
    assert :name in fields
    assert :status in fields
    assert :tenant_scope in fields
    assert :clickhouse_table in fields
  end

  test "column_specs reference real StreamRow attributes" do
    assert :ok =
             SootAdmin.validate_columns(
               TelemetryStreamPanel.resource(),
               TelemetryStreamPanel.column_specs()
             )
  end

  test "query/0 sorts by name asc" do
    query = TelemetryStreamPanel.query()
    assert query.sort == [name: :asc]
  end

  test "ingest_sessions_query/1 filters to the given stream id" do
    stream_id = Ecto.UUID.generate()
    query = TelemetryStreamPanel.ingest_sessions_query(stream_id)
    assert query.resource == SootTelemetry.IngestSession
    assert inspect(query.filter) =~ stream_id
    assert query.sort == [last_batch_at: :desc]
  end

  test "query/1 :base_query is preserved" do
    require Ash.Query
    base = Ash.Query.filter(SootTelemetry.StreamRow, status == :active)

    query = TelemetryStreamPanel.query(base_query: base)

    assert inspect(query.filter) =~ "active"
    assert query.sort == [name: :asc]
  end
end
