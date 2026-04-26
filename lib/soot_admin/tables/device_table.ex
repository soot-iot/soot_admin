defmodule SootAdmin.DeviceTable do
  @moduledoc """
  Cinder table over `SootCore.Device`.

  Defaults to all devices visible to the actor, sortable by
  `last_seen_at` and filterable by `state` / `tenant_id` / `model`.

  ## Operator use

      <.live_component
        module={SootAdmin.DeviceTable}
        id="device-table"
        actor={@current_user}
      />

  Or, with a base filter (e.g. only this tenant's devices):

      query = SootAdmin.DeviceTable.query(actor: @current_user, tenant_id: @tenant.id)
      <SootAdmin.DeviceTable.table query={query} actor={@current_user} />
  """

  use Phoenix.Component
  require Ash.Query

  @resource SootCore.Device

  @doc "Underlying Ash resource."
  @spec resource() :: module()
  def resource, do: @resource

  @doc """
  Column specifications. Each entry is `{field, opts}`; opts mirror
  Cinder's column slot attrs (`filter:`, `sort:`, `label:`, `class:`).
  """
  @spec column_specs() :: [{atom(), keyword()}]
  def column_specs do
    [
      {:serial, label: "Serial", filter: :text, sort: true},
      {:state, label: "State", filter: :select, sort: true},
      {:tenant_id, label: "Tenant", filter: :text, sort: true},
      {:model, label: "Model", filter: :text, sort: true},
      {:batch_id, label: "Batch", filter: :text},
      {:last_seen_at, label: "Last seen", sort: true},
      {:operational_certificate_id, label: "Operational cert"}
    ]
  end

  @doc """
  Build the base query. Optional opts:
    * `:tenant_id` — restrict to one tenant.
    * `:state` — restrict to one state.
    * `:base_query` — start from an existing `Ash.Query` instead of
      `SootCore.Device`.
  """
  @spec query(keyword()) :: Ash.Query.t()
  def query(opts \\ []) do
    base = Keyword.get(opts, :base_query, Ash.Query.new(@resource))

    base
    |> apply_tenant(opts)
    |> apply_state(opts)
    |> Ash.Query.sort(last_seen_at: :desc)
  end

  defp apply_tenant(query, opts) do
    case Keyword.get(opts, :tenant_id) do
      nil -> query
      id -> Ash.Query.filter(query, tenant_id == ^id)
    end
  end

  defp apply_state(query, opts) do
    case Keyword.get(opts, :state) do
      nil -> query
      state when is_atom(state) -> Ash.Query.filter(query, state == ^state)
    end
  end

  attr :actor, :any, required: true
  attr :tenant, :any, default: nil
  attr :query, :any, default: nil
  attr :id, :string, default: "soot-device-table"
  attr :page_size, :integer, default: 25

  @doc "Phoenix component wrapping `Cinder.collection` with the device columns."
  def table(assigns) do
    assigns = assign_new(assigns, :query, fn -> query() end)

    ~H"""
    <Cinder.collection
      id={@id}
      query={@query}
      actor={@actor}
      tenant={@tenant}
      page_size={@page_size}
    >
      <:col :let={device} field="serial" filter sort>{device.serial}</:col>
      <:col :let={device} field="state" filter sort>{device.state}</:col>
      <:col :let={device} field="tenant_id" filter sort>{device.tenant_id}</:col>
      <:col :let={device} field="model" filter sort>{device.model}</:col>
      <:col :let={device} field="last_seen_at" sort>{device.last_seen_at}</:col>
    </Cinder.collection>
    """
  end
end
