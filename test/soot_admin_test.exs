defmodule SootAdminTest do
  use ExUnit.Case, async: true

  describe "validate_columns/2" do
    test "returns :ok when every spec field is a real Device attribute" do
      specs = [{:serial, []}, {:state, []}]
      assert :ok = SootAdmin.validate_columns(SootCore.Device, specs)
    end

    test "returns {:error, [{field, :unknown_field}, ...]} for nonexistent fields" do
      specs = [{:serial, []}, {:not_a_real_field, []}, {:also_bogus, []}]

      assert {:error, errors} = SootAdmin.validate_columns(SootCore.Device, specs)

      assert {:not_a_real_field, :unknown_field} in errors
      assert {:also_bogus, :unknown_field} in errors
      refute Enum.any?(errors, fn {field, _} -> field == :serial end)
    end

    test "string field names that match a real attribute pass" do
      assert :ok = SootAdmin.validate_columns(SootCore.Device, [{"serial", []}])
    end

    test "string field names that do NOT correspond to any existing atom flag as unknown" do
      specs = [{"never_seen_this_string_field_anywhere_in_the_runtime", []}]

      assert {:error, [{field, :unknown_field}]} =
               SootAdmin.validate_columns(SootCore.Device, specs)

      assert is_binary(field)
    end
  end
end
