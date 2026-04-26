defmodule SootAdmin do
  @moduledoc """
  Cinder table configs and LiveView component shells for the Soot
  resources.

  Each table module exposes:

    * `resource/0`, `query/1`, `column_specs/0` — plain-data getters the
      operator can compose with their own LiveView. Easily testable.
    * a Phoenix component (`table/1` or similar) — a thin wrapper around
      `Cinder.collection` with the right `:col` slots pre-baked.

  Operators mount these into their own Phoenix LiveView app — this
  library does not own routing, auth, layout, or theme.

  See:

    * `SootAdmin.DeviceTable`
    * `SootAdmin.CertificateTable`
    * `SootAdmin.EnrollmentQueue`
    * `SootAdmin.TelemetryStreamPanel`
    * `SootAdmin.SegmentTable`
  """

  @doc """
  Validate that every column spec references an attribute that
  actually exists on the underlying Ash resource. Returns `:ok` or
  `{:error, [{field, reason}, …]}`.
  """
  @spec validate_columns(module(), [{atom() | String.t(), keyword()}]) ::
          :ok | {:error, [{atom() | String.t(), term()}]}
  def validate_columns(resource, specs) do
    fields =
      Ash.Resource.Info.attributes(resource)
      |> MapSet.new(& &1.name)

    bad =
      Enum.flat_map(specs, fn {field, _opts} ->
        atom = field_to_atom(field)
        if atom != nil and MapSet.member?(fields, atom), do: [], else: [{field, :unknown_field}]
      end)

    case bad do
      [] -> :ok
      _ -> {:error, bad}
    end
  end

  defp field_to_atom(field) when is_atom(field), do: field

  defp field_to_atom(field) when is_binary(field) do
    String.to_existing_atom(field)
  rescue
    ArgumentError -> nil
  end

  defp field_to_atom(_), do: nil
end
