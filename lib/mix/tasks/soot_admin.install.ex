defmodule Mix.Tasks.SootAdmin.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs the Soot admin LiveView surface into a Phoenix project"
  end

  def example do
    "mix igniter.install soot_admin"
  end

  def long_doc do
    """
    #{short_doc()}

    Generates a `/admin` scope in the operator's router, an admin layout
    component, and one LiveView per Soot resource domain wrapping the
    Cinder components shipped by `soot_admin`. Composed by
    `mix soot.install`; can also be run standalone.

    The installer assumes `ash_authentication_phoenix.install` has
    already been run (so `LiveUserAuth` and the `:browser` pipeline
    plugs exist). If it hasn't, run `mix soot.install` instead.

    See the `UI-SPEC.md` in the `soot` package for the full design.

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

      * `--example` — same shape as the rest of the Soot installers;
        currently a no-op for `soot_admin` since the LiveView stubs
        already render usable defaults.
      * `--yes` — answer yes to dependency-fetching prompts.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.SootAdmin.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"
    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @admin_pages [
      {:overview, "Overview", "/", "OverviewLive"},
      {:devices, "Devices", "/devices", "DevicesLive"},
      {:enrollment, "Enrollment", "/enrollment", "EnrollmentLive"},
      {:certificates, "Certificates", "/certificates", "CertificatesLive"},
      {:telemetry, "Telemetry", "/telemetry", "TelemetryLive"},
      {:segments, "Segments", "/segments", "SegmentsLive"}
    ]

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :soot,
        example: __MODULE__.Docs.example(),
        only: nil,
        composes: [],
        schema: [example: :boolean, yes: :boolean],
        defaults: [example: false, yes: false],
        aliases: [y: :yes, e: :example]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:soot_admin)
      |> add_admin_routes()
      |> create_admin_layout()
      |> create_admin_nav()
      |> create_admin_liveviews()
      |> note_next_steps()
    end

    defp add_admin_routes(igniter) do
      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should the Soot admin LiveViews be mounted in?"
        )

      if router do
        web_module = Igniter.Libs.Phoenix.web_module(igniter)
        live_user_auth = Module.concat([web_module, "LiveUserAuth"])

        if admin_scope_present?(igniter, router) do
          igniter
        else
          live_routes =
            Enum.map_join(@admin_pages, "\n", fn {_id, _label, path, mod} ->
              ~s|      live #{inspect(path)}, Admin.#{mod}, :index|
            end)

          scope_body = """
          pipe_through :browser

          ash_authentication_live_session :soot_admin,
            on_mount: [{#{inspect(live_user_auth)}, :live_user_required}] do
          #{live_routes}
          end
          """

          Igniter.Libs.Phoenix.add_scope(
            igniter,
            "/admin",
            scope_body,
            arg2: web_module,
            router: router
          )
        end
      else
        Igniter.add_warning(igniter, """
        No Phoenix router found. The Soot admin LiveViews were not
        mounted. Set up a Phoenix router and re-run
        `mix igniter.install soot_admin`.
        """)
      end
    end

    # The /admin scope is uniquely identifiable by the
    # `ash_authentication_live_session :soot_admin` call inside it.
    # Detect that to make the installer idempotent.
    defp admin_scope_present?(igniter, router) do
      {_, _source, zipper} = Igniter.Project.Module.find_module!(igniter, router)

      case Igniter.Code.Common.move_to(zipper, fn z ->
             Igniter.Code.Function.function_call?(z, :ash_authentication_live_session, [2, 3]) and
               Igniter.Code.Function.argument_equals?(z, 0, :soot_admin)
           end) do
        {:ok, _} -> true
        :error -> false
      end
    end

    defp create_admin_layout(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      module = Module.concat([web_module, "AdminLayouts"])
      nav = Module.concat([web_module, "AdminNav"])

      Igniter.Project.Module.create_module(
        igniter,
        module,
        """
        @moduledoc \"\"\"
        Layout shell used by every Soot admin LiveView.

        Renders the sidebar (delegated to `#{inspect(nav)}`) plus a
        page-content slot. Operators can copy this module into their
        own namespace and customize freely — the framework does not
        re-touch this file once generated.
        \"\"\"

        use Phoenix.Component

        attr :active, :atom, required: true
        slot :inner_block, required: true

        def admin_layout(assigns) do
          ~H\"\"\"
          <div class="flex min-h-screen">
            <#{inspect(nav)}.nav active={@active} />
            <main class="flex-1 p-6">
              {render_slot(@inner_block)}
            </main>
          </div>
          \"\"\"
        end
        """
      )
    end

    defp create_admin_nav(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      module = Module.concat([web_module, "AdminNav"])

      pages_literal =
        Enum.map_join(@admin_pages, ",\n", fn {id, label, path, _mod} ->
          ~s|    {#{inspect(id)}, "#{label}", "/admin#{path}"}|
        end)

      Igniter.Project.Module.create_module(
        igniter,
        module,
        """
        @moduledoc \"\"\"
        Sidebar navigation for the Soot admin LiveViews.

        Edit `pages/0` to add operator-specific tabs. The framework
        does not re-touch this file once generated.
        \"\"\"

        use Phoenix.Component

        attr :active, :atom, required: true

        def nav(assigns) do
          assigns = assign(assigns, :pages, pages())

          ~H\"\"\"
          <nav class="w-56 bg-gray-100 p-4">
            <h1 class="font-bold mb-4">Soot Admin</h1>
            <ul>
              <li :for={ {id, label, href} <- @pages } class="mb-1">
                <a href={href} class={if @active == id, do: "font-bold", else: ""}>
                  {label}
                </a>
              </li>
            </ul>
          </nav>
          \"\"\"
        end

        @doc \"\"\"
        Pages rendered in the sidebar. Append to this list to add
        operator-specific admin tabs.
        \"\"\"
        def pages do
          [
        #{pages_literal}
          ]
        end
        """
      )
    end

    defp create_admin_liveviews(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      layouts = Module.concat([web_module, "AdminLayouts"])
      live_user_auth = Module.concat([web_module, "LiveUserAuth"])

      Enum.reduce(@admin_pages, igniter, fn page, igniter ->
        create_admin_liveview(igniter, page, web_module, layouts, live_user_auth)
      end)
    end

    defp create_admin_liveview(igniter, {id, title, _path, mod}, web_module, layouts, live_user_auth) do
      module = Module.concat([web_module, "Admin", mod])

      body = liveview_body(id)

      Igniter.Project.Module.create_module(
        igniter,
        module,
        """
        @moduledoc \"\"\"
        #{title} tab in the Soot admin UI.

        Generated stub — operators can extend with their own filters,
        actions, and supplementary panels. The framework does not
        re-touch this file once generated.
        \"\"\"

        use #{inspect(web_module)}, :live_view

        on_mount {#{inspect(live_user_auth)}, :live_user_required}

        import #{inspect(layouts)}

        def mount(_params, _session, socket) do
          {:ok, assign(socket, :page_title, #{inspect(title)})}
        end

        def render(assigns) do
          ~H\"\"\"
          <.admin_layout active={#{inspect(id)}}>
        #{body}
          </.admin_layout>
          \"\"\"
        end
        """
      )
    end

    defp liveview_body(:overview) do
      ~s|    <h2 class="text-2xl mb-4">Overview</h2>
        <p class="text-gray-600">
          Replace this with your operator-specific dashboard. Aggregate
          counts, recent ingest sessions, and links to the other tabs
          are good starting points.
        </p>|
    end

    defp liveview_body(:devices) do
      ~s|    <SootAdmin.DeviceTable.table actor={@current_user} />|
    end

    defp liveview_body(:enrollment) do
      ~s|    <SootAdmin.EnrollmentQueue.table actor={@current_user} />|
    end

    defp liveview_body(:certificates) do
      ~s|    <SootAdmin.CertificateTable.table actor={@current_user} />|
    end

    defp liveview_body(:telemetry) do
      ~s|    <SootAdmin.TelemetryStreamPanel.table actor={@current_user} />|
    end

    defp liveview_body(:segments) do
      ~s|    <SootAdmin.SegmentTable.table actor={@current_user} />|
    end

    defp note_next_steps(igniter) do
      Igniter.add_notice(igniter, """
      soot_admin installed.

      The admin LiveView surface is mounted at /admin. Sign in with an
      ash_authentication user, then browse:

        /admin/             Overview (operator-customizable dashboard)
        /admin/devices      Device table
        /admin/enrollment   Pending enrollment queue
        /admin/certificates Certificate table
        /admin/telemetry    Telemetry stream panel
        /admin/segments     Segment table

      The generated layout, nav, and per-tab LiveViews live in your
      <web>/components/ and <web>/live/admin/ directories. Edit them
      freely — the installer will not re-touch them.
      """)
    end
  end
else
  defmodule Mix.Tasks.SootAdmin.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"
    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task `soot_admin.install` requires igniter. Add
      `{:igniter, "~> 0.6"}` to your project deps and try again, or
      invoke via:

          mix igniter.install soot_admin

      For more information, see https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
