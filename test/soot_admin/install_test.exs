defmodule Mix.Tasks.SootAdmin.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  @router """
  defmodule TestWeb.Router do
    use TestWeb, :router

    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_live_flash
      plug :put_root_layout, html: {TestWeb.Layouts, :root}
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end

    scope "/", TestWeb do
      pipe_through :browser
      get "/", PageController, :home
    end
  end
  """

  @endpoint """
  defmodule TestWeb.Endpoint do
    use Phoenix.Endpoint, otp_app: :test

    plug TestWeb.Router
  end
  """

  defp setup_project do
    test_project(
      files: %{
        "lib/test_web/endpoint.ex" => @endpoint,
        "lib/test_web/router.ex" => @router
      }
    )
    |> Igniter.Project.Application.create_app(Test.Application)
    |> apply_igniter!()
    # See soot's install_test.exs: Igniter's test_project leaves
    # rewrite empty after apply_igniter!. Manually include the files
    # we need module-discovery to find.
    |> Igniter.include_existing_file("lib/test_web/router.ex")
    |> Igniter.include_existing_file("lib/test_web/endpoint.ex")
  end

  describe "info/2" do
    test "exposes the documented option schema" do
      info = Mix.Tasks.SootAdmin.Install.info([], nil)
      assert info.group == :soot
      assert info.schema == [example: :boolean, yes: :boolean]
      assert info.aliases == [y: :yes, e: :example]
    end

    test "composes cinder.install" do
      # Cinder owns the Tailwind content-path wiring and the
      # `:cinder, :default_theme` config. Without that the admin
      # tables compile but render unstyled — the operator's Tailwind
      # build never sees the classes Cinder emits.
      info = Mix.Tasks.SootAdmin.Install.info([], nil)
      assert "cinder.install" in info.composes
    end
  end

  describe "cinder wiring" do
    test "configures the cinder default_theme in config.exs" do
      # Side effect of `cinder.install`: a `config :cinder,
      # default_theme: "modern"` line gets injected into config.exs.
      # We don't care about the exact value (operators can override),
      # just that the wiring fired.
      result =
        setup_project()
        |> Igniter.compose_task("soot_admin.install", [])

      diff = diff(result, only: "config/config.exs")
      assert diff =~ ":cinder"
      assert diff =~ "default_theme"
    end
  end

  describe "router patching" do
    test "adds an /admin scope under :browser" do
      setup_project()
      |> Igniter.compose_task("soot_admin.install", [])
      |> assert_has_patch("lib/test_web/router.ex", """
      + |  scope "/admin", TestWeb do
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
      + |    pipe_through(:browser)
      """)
    end

    test "wires ash_authentication_live_session with LiveUserAuth" do
      setup_project()
      |> Igniter.compose_task("soot_admin.install", [])
      |> assert_has_patch("lib/test_web/router.ex", """
      + |    ash_authentication_live_session :soot_admin,
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
      + |      on_mount: [{TestWeb.LiveUserAuth, :live_user_required}] do
      """)
    end

    test "mounts every documented admin live route" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_admin.install", [])

      diff = diff(result, only: "lib/test_web/router.ex")

      assert diff =~ "Admin.OverviewLive"
      assert diff =~ "Admin.DevicesLive"
      assert diff =~ "Admin.EnrollmentLive"
      assert diff =~ "Admin.CertificatesLive"
      assert diff =~ "Admin.TelemetryLive"
      assert diff =~ "Admin.SegmentsLive"
    end

    test "is idempotent" do
      setup_project()
      |> Igniter.compose_task("soot_admin.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("soot_admin.install", [])
      |> assert_unchanged("lib/test_web/router.ex")
    end
  end

  describe "generated modules" do
    test "creates the admin layout component" do
      setup_project()
      |> Igniter.compose_task("soot_admin.install", [])
      |> assert_creates("lib/test_web/admin_layouts.ex")
    end

    test "creates the admin nav component" do
      setup_project()
      |> Igniter.compose_task("soot_admin.install", [])
      |> assert_creates("lib/test_web/admin_nav.ex")
    end

    test "creates a LiveView module for every admin tab" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_admin.install", [])

      Enum.each(
        ~w(overview_live devices_live enrollment_live
           certificates_live telemetry_live segments_live),
        fn file ->
          assert_creates(result, "lib/test_web/admin/#{file}.ex")
        end
      )
    end

    test "DevicesLive renders SootAdmin.DeviceTable.table" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_admin.install", [])

      diff = diff(result, only: "lib/test_web/admin/devices_live.ex")
      assert diff =~ "SootAdmin.DeviceTable.table"
      assert diff =~ "actor={@current_user}"
    end
  end

  describe "running on a project without a router" do
    test "emits a warning rather than crashing" do
      igniter =
        test_project(files: %{})
        |> Igniter.compose_task("soot_admin.install", [])

      assert is_struct(igniter, Igniter)
      assert Enum.any?(igniter.warnings, &(&1 =~ "No Phoenix router"))
    end
  end

  describe "next-steps notice" do
    test "always emits a soot_admin installed notice" do
      igniter =
        test_project(files: %{})
        |> Igniter.compose_task("soot_admin.install", [])

      assert Enum.any?(igniter.notices, &(&1 =~ "soot_admin installed."))
      assert Enum.any?(igniter.notices, &(&1 =~ "/admin"))
    end
  end
end
