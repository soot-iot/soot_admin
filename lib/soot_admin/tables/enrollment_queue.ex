defmodule SootAdmin.EnrollmentQueue do
  @moduledoc """
  Devices waiting to be provisioned. Filters `SootCore.Device` to the
  states that need an operator's attention:

    * `:unprovisioned` — row exists, no cert. Need to mint a bootstrap
      token + bootstrap cert.
    * `:bootstrapped` — bootstrap cert issued, awaiting operational
      enrollment via `SootCore.Plug.Enroll`.
  """

  use Phoenix.Component
  require Ash.Query

  @doc """
  Underlying Ash resource. Resolves at runtime via `SootCore.device/0`
  so the queue follows `config :soot_core, device: MyApp.Device`.
  """
  @spec resource() :: module()
  def resource, do: SootCore.device()

  @doc """
  Column specifications. This list is the documented source of truth
  for what columns `table/1` renders — keep the HEEx in sync.
  """
  @spec column_specs() :: [{atom(), keyword()}]
  def column_specs do
    [
      {:serial, label: "Serial", filter: :text, sort: true},
      {:state, label: "State", filter: :select, sort: true},
      {:tenant_id, label: "Tenant", filter: :text, sort: true},
      {:bootstrap_certificate_id, label: "Bootstrap cert"},
      {:inserted_at, label: "Created", sort: true}
    ]
  end

  @doc """
  Base query — devices in :unprovisioned or :bootstrapped state.

  Opts:
    * `:tenant_id` — restrict to one tenant.
    * `:base_query` — start from an existing `Ash.Query` instead of
      `SootCore.Device`.
  """
  @spec query(keyword()) :: Ash.Query.t()
  def query(opts \\ []) do
    base = Keyword.get(opts, :base_query, Ash.Query.new(resource()))
    queue_states = [:unprovisioned, :bootstrapped]

    base
    |> Ash.Query.filter(state in ^queue_states)
    |> apply_tenant(opts)
    |> Ash.Query.sort(inserted_at: :asc)
  end

  defp apply_tenant(query, opts) do
    case Keyword.get(opts, :tenant_id) do
      nil ->
        query

      id when is_binary(id) ->
        Ash.Query.filter(query, tenant_id == ^id)

      other ->
        raise ArgumentError,
              "EnrollmentQueue.query/1 :tenant_id must be a UUID string, got: #{inspect(other)}"
    end
  end

  attr :actor, :any, required: true
  attr :query, :any, default: nil
  attr :id, :string, default: "soot-enrollment-queue"
  attr :page_size, :integer, default: 25

  def table(assigns) do
    assigns = assign(assigns, :query, assigns[:query] || query())

    ~H"""
    <Cinder.collection id={@id} query={@query} actor={@actor} page_size={@page_size}>
      <:col :let={device} field="serial" filter={:text} sort>{device.serial}</:col>
      <:col :let={device} field="state" filter={:select} sort>{device.state}</:col>
      <:col :let={device} field="tenant_id" filter={:text} sort>{device.tenant_id}</:col>
      <:col :let={device} field="bootstrap_certificate_id">{device.bootstrap_certificate_id}</:col>
      <:col :let={device} field="inserted_at" sort>{device.inserted_at}</:col>
    </Cinder.collection>
    """
  end
end
