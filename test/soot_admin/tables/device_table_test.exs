defmodule SootAdmin.DeviceTableTest do
  use ExUnit.Case, async: false

  alias SootAdmin.DeviceTable

  test "resource/0 returns the library default when no override is configured" do
    assert DeviceTable.resource() == SootCore.Device
  end

  test "resource/0 follows config :soot_core, device: …" do
    Application.put_env(:soot_core, :device, FakeApp.Device)

    try do
      assert DeviceTable.resource() == FakeApp.Device
    after
      Application.delete_env(:soot_core, :device)
    end
  end

  test "column_specs/0 includes the expected operator-facing fields" do
    fields = DeviceTable.column_specs() |> Enum.map(&elem(&1, 0))
    assert :serial in fields
    assert :state in fields
    assert :tenant_id in fields
    assert :model in fields
    assert :last_seen_at in fields
  end

  test "column_specs reference attributes that exist on SootCore.Device" do
    assert :ok = SootAdmin.validate_columns(DeviceTable.resource(), DeviceTable.column_specs())
  end

  test "query/0 returns an Ash query sorted by last_seen_at desc" do
    query = DeviceTable.query()

    assert %Ash.Query{} = query
    assert query.resource == SootCore.Device
    assert query.sort == [last_seen_at: :desc]
  end

  test "query/1 with :tenant_id filters by it" do
    tenant_id = Ecto.UUID.generate()
    query = DeviceTable.query(tenant_id: tenant_id)

    refute is_nil(query.filter)
    assert inspect(query.filter) =~ tenant_id
  end

  test "query/1 with :state filters by it" do
    query = DeviceTable.query(state: :operational)
    refute is_nil(query.filter)
    assert inspect(query.filter) =~ "operational"
  end

  test "query/1 accepts :base_query and chains filters onto it" do
    require Ash.Query
    base = Ash.Query.filter(SootCore.Device, model == "X")

    query = DeviceTable.query(base_query: base, state: :operational)

    refute is_nil(query.filter)
    assert inspect(query.filter) =~ "operational"
    assert inspect(query.filter) =~ "X"
  end
end
