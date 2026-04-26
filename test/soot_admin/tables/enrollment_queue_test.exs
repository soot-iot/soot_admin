defmodule SootAdmin.EnrollmentQueueTest do
  use ExUnit.Case, async: true

  alias SootAdmin.EnrollmentQueue

  test "resource and columns" do
    assert EnrollmentQueue.resource() == SootCore.Device
    fields = EnrollmentQueue.column_specs() |> Enum.map(&elem(&1, 0))
    assert :serial in fields
    assert :state in fields
    assert :bootstrap_certificate_id in fields
  end

  test "column_specs reference real Device attributes" do
    assert :ok =
             SootAdmin.validate_columns(
               EnrollmentQueue.resource(),
               EnrollmentQueue.column_specs()
             )
  end

  test "query/0 filters to :unprovisioned and :bootstrapped, sorted oldest-first" do
    query = EnrollmentQueue.query()

    assert %Ash.Query{} = query
    assert query.sort == [inserted_at: :asc]
    assert inspect(query.filter) =~ "unprovisioned"
    assert inspect(query.filter) =~ "bootstrapped"
  end

  test "query/1 with :tenant_id narrows further" do
    tenant_id = Ecto.UUID.generate()
    query = EnrollmentQueue.query(tenant_id: tenant_id)

    assert inspect(query.filter) =~ tenant_id
    assert inspect(query.filter) =~ "unprovisioned"
  end
end
