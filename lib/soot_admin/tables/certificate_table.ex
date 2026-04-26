defmodule SootAdmin.CertificateTable do
  @moduledoc """
  Cinder table over `AshPki.Certificate`. Sortable by `not_after` so
  expiring certs surface at the top.
  """

  use Phoenix.Component
  require Ash.Query

  @resource AshPki.Certificate

  @spec resource() :: module()
  def resource, do: @resource

  @doc """
  Column specifications. This list is the documented source of truth
  for what columns `table/1` renders — keep the HEEx in sync.
  """
  @spec column_specs() :: [{atom(), keyword()}]
  def column_specs do
    [
      {:subject_dn, label: "Subject", filter: :text, sort: true},
      {:status, label: "Status", filter: :select, sort: true},
      {:serial, label: "Serial", filter: :text},
      {:fingerprint, label: "Fingerprint", filter: :text},
      {:issuer_id, label: "Issuer"},
      {:not_after, label: "Expires", sort: true},
      {:revoked_at, label: "Revoked at"},
      {:revocation_reason, label: "Reason", filter: :select}
    ]
  end

  @doc """
  Base query. Opts:
    * `:status` — restrict to one status (`:active`, `:revoked`, `:expired`).
    * `:issuer_id` — restrict to one issuing CA.
    * `:expiring_within_days` — only certs whose `not_after` is within N days.
  """
  @spec query(keyword()) :: Ash.Query.t()
  def query(opts \\ []) do
    base = Keyword.get(opts, :base_query, Ash.Query.new(@resource))

    base
    |> apply_status(opts)
    |> apply_issuer(opts)
    |> apply_expiring(opts)
    |> Ash.Query.sort(not_after: :asc)
  end

  defp apply_status(query, opts) do
    case Keyword.get(opts, :status) do
      nil ->
        query

      status when is_atom(status) ->
        Ash.Query.filter(query, status == ^status)

      status when is_binary(status) ->
        Ash.Query.filter(query, status == ^to_existing_atom!(status, :status))

      other ->
        raise ArgumentError,
              "CertificateTable.query/1 :status must be an atom or string, got: #{inspect(other)}"
    end
  end

  defp apply_issuer(query, opts) do
    case Keyword.get(opts, :issuer_id) do
      nil ->
        query

      id when is_binary(id) ->
        Ash.Query.filter(query, issuer_id == ^id)

      other ->
        raise ArgumentError,
              "CertificateTable.query/1 :issuer_id must be a UUID string, got: #{inspect(other)}"
    end
  end

  defp apply_expiring(query, opts) do
    case Keyword.get(opts, :expiring_within_days) do
      nil ->
        query

      days when is_integer(days) ->
        cutoff = DateTime.utc_now() |> DateTime.add(days * 86_400, :second)
        Ash.Query.filter(query, not_after <= ^cutoff and status == :active)

      other ->
        raise ArgumentError,
              "CertificateTable.query/1 :expiring_within_days must be an integer, got: #{inspect(other)}"
    end
  end

  defp to_existing_atom!(value, opt_name) do
    String.to_existing_atom(value)
  rescue
    ArgumentError ->
      reraise ArgumentError,
              "CertificateTable.query/1 #{inspect(opt_name)} got unknown value #{inspect(value)}",
              __STACKTRACE__
  end

  attr :actor, :any, required: true
  attr :query, :any, default: nil
  attr :id, :string, default: "soot-certificate-table"

  def table(assigns) do
    assigns = assign_new(assigns, :query, fn -> query() end)

    ~H"""
    <Cinder.collection id={@id} query={@query} actor={@actor}>
      <:col :let={c} field="subject_dn" filter={:text} sort>{c.subject_dn}</:col>
      <:col :let={c} field="status" filter={:select} sort>{c.status}</:col>
      <:col :let={c} field="serial" filter={:text}>{c.serial}</:col>
      <:col :let={c} field="fingerprint" filter={:text}>{c.fingerprint}</:col>
      <:col :let={c} field="issuer_id">{c.issuer_id}</:col>
      <:col :let={c} field="not_after" sort>{c.not_after}</:col>
      <:col :let={c} field="revoked_at">{c.revoked_at}</:col>
      <:col :let={c} field="revocation_reason" filter={:select}>{c.revocation_reason}</:col>
    </Cinder.collection>
    """
  end
end
