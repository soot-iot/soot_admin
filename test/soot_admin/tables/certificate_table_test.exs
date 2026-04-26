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

  test "query/1 :expiring_within_days computes the cutoff as now + N*86_400 seconds" do
    days = 7
    before = DateTime.utc_now()
    query = CertificateTable.query(expiring_within_days: days)
    aft = DateTime.utc_now()

    cutoff = find_datetime(query.filter)
    assert %DateTime{} = cutoff

    expected_lower = DateTime.add(before, days * 86_400, :second)
    expected_upper = DateTime.add(aft, days * 86_400, :second)

    assert DateTime.compare(cutoff, expected_lower) in [:eq, :gt]
    assert DateTime.compare(cutoff, expected_upper) in [:eq, :lt]
  end

  test "query/1 :expiring_within_days raises ArgumentError on non-integer input" do
    assert_raise ArgumentError, ~r/:expiring_within_days/, fn ->
      CertificateTable.query(expiring_within_days: "30")
    end
  end

  test "query/1 :base_query is preserved through the certificate filters" do
    require Ash.Query
    base = Ash.Query.filter(AshPki.Certificate, subject_dn == "CN=Foo")

    query = CertificateTable.query(base_query: base, status: :active)

    f = inspect(query.filter)
    assert f =~ "Foo"
    assert f =~ "active"
  end

  defp find_datetime(%DateTime{} = dt), do: dt

  defp find_datetime(value) when is_struct(value) do
    value
    |> Map.from_struct()
    |> Enum.find_value(&find_datetime/1)
  end

  defp find_datetime(value) when is_map(value) do
    Enum.find_value(value, &find_datetime/1)
  end

  defp find_datetime({_key, value}), do: find_datetime(value)

  defp find_datetime(value) when is_list(value) do
    Enum.find_value(value, &find_datetime/1)
  end

  defp find_datetime(_), do: nil
end
