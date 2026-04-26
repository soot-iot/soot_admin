defmodule SootAdmin.CertificateTableTest do
  use ExUnit.Case, async: true

  alias SootAdmin.CertificateTable

  test "resource and columns" do
    assert CertificateTable.resource() == AshPki.Certificate
    fields = CertificateTable.column_specs() |> Enum.map(&elem(&1, 0))
    assert :subject_dn in fields
    assert :status in fields
    assert :not_after in fields
    assert :revocation_reason in fields
  end

  test "column_specs reference real Certificate attributes" do
    assert :ok =
             SootAdmin.validate_columns(
               CertificateTable.resource(),
               CertificateTable.column_specs()
             )
  end

  test "query/0 sorts by not_after asc so soonest-to-expire surfaces first" do
    query = CertificateTable.query()
    assert query.sort == [not_after: :asc]
  end

  test "query/1 with :status filters" do
    query = CertificateTable.query(status: :revoked)
    assert inspect(query.filter) =~ "revoked"
  end

  test "query/1 with :issuer_id filters" do
    issuer_id = Ecto.UUID.generate()
    query = CertificateTable.query(issuer_id: issuer_id)
    assert inspect(query.filter) =~ issuer_id
  end

  test "query/1 with :expiring_within_days filters by not_after AND status :active" do
    query = CertificateTable.query(expiring_within_days: 30)
    f = inspect(query.filter)
    assert f =~ "not_after"
    assert f =~ "active"
  end
end
