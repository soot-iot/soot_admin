defmodule SootAdmin.SegmentTableTest do
  use ExUnit.Case, async: true

  alias SootAdmin.SegmentTable

  test "resource and columns" do
    assert SegmentTable.resource() == SootSegments.SegmentRow

    fields = SegmentTable.column_specs() |> Enum.map(&elem(&1, 0))
    assert :name in fields
    assert :source_stream in fields
    assert :granularity in fields
    assert :status in fields
    assert :target in fields
  end

  test "column_specs reference real SegmentRow attributes" do
    assert :ok = SootAdmin.validate_columns(SegmentTable.resource(), SegmentTable.column_specs())
  end

  test "query/0 sorts by name asc" do
    query = SegmentTable.query()
    assert query.sort == [name: :asc]
  end
end
