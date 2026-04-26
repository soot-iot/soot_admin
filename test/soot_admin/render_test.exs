defmodule SootAdmin.RenderTest do
  @moduledoc """
  Render the public Phoenix function components and assert each
  declared column in `column_specs/0` shows up in the output.

  These are smoke tests: a typo in a slot attr, a silently dropped
  column, or a Cinder upstream change that breaks the rendering path
  would be caught here even though the suite does not stand up a
  full LiveView socket.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias SootAdmin.{
    CertificateTable,
    DeviceTable,
    EnrollmentQueue,
    SegmentTable,
    TelemetryStreamPanel
  }

  test "DeviceTable.table renders every column declared in column_specs/0" do
    html = render_component(&DeviceTable.table/1, %{actor: nil})
    assert_columns_rendered(html, DeviceTable.column_specs())
  end

  test "CertificateTable.table renders every column declared in column_specs/0" do
    html = render_component(&CertificateTable.table/1, %{actor: nil})
    assert_columns_rendered(html, CertificateTable.column_specs())
  end

  test "EnrollmentQueue.table renders every column declared in column_specs/0" do
    html = render_component(&EnrollmentQueue.table/1, %{actor: nil})
    assert_columns_rendered(html, EnrollmentQueue.column_specs())
  end

  test "SegmentTable.table renders every column declared in column_specs/0" do
    html = render_component(&SegmentTable.table/1, %{actor: nil})
    assert_columns_rendered(html, SegmentTable.column_specs())
  end

  test "TelemetryStreamPanel.table renders every column declared in column_specs/0" do
    html = render_component(&TelemetryStreamPanel.table/1, %{actor: nil})
    assert_columns_rendered(html, TelemetryStreamPanel.column_specs())
  end

  defp assert_columns_rendered(html, specs) do
    for {field, _opts} <- specs do
      field_str = Atom.to_string(field)
      humanized = field_str |> String.replace("_", " ") |> String.downcase()
      lower_html = String.downcase(html)

      assert lower_html =~ humanized,
             "Expected a column header derived from field #{inspect(field)} " <>
               "(looking for #{inspect(humanized)}) in rendered output, but it was missing."
    end
  end
end
