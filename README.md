# `soot_admin`

Cinder table configs and Phoenix LiveView component shells for the Soot
resources. Operators drop these into their own admin LiveView app —
this library doesn't own routing, auth, layout, or theme.

Depends on [`ash_pki`](../ash_pki), [`soot_core`](../soot_core),
[`soot_telemetry`](../soot_telemetry), [`soot_segments`](../soot_segments),
plus `cinder` and `phoenix_live_view`.

## Components

| Module                              | Underlying resource                  | What it shows                                         |
|-------------------------------------|--------------------------------------|-------------------------------------------------------|
| `SootAdmin.DeviceTable`             | `SootCore.Device`                    | the fleet, sortable + filterable                      |
| `SootAdmin.EnrollmentQueue`         | `SootCore.Device`                    | only `:unprovisioned` and `:bootstrapped` states      |
| `SootAdmin.CertificateTable`        | `AshPki.Certificate`                 | certs, sorted by `not_after` so expiring rises to top |
| `SootAdmin.TelemetryStreamPanel`    | `SootTelemetry.StreamRow`            | registered streams + `ingest_sessions_query/2` helper |
| `SootAdmin.SegmentTable`            | `SootSegments.SegmentRow`            | registered segments and their MV target               |
| `SootAdmin.SegmentChart`            | `SootSegments.Query`                 | builds SQL + columns + chart config (no renderer)     |

Each table module exposes:

```elixir
DeviceTable.resource()       # underlying Ash resource module
DeviceTable.column_specs()   # list of {field, opts} for the operator's reference
DeviceTable.query(opts)      # Ash.Query.t() with the table's defaults applied
DeviceTable.table(assigns)   # Phoenix component wrapping Cinder.Table.table
```

## Use in an operator LiveView

```elixir
defmodule MyAppWeb.Admin.DevicesLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <SootAdmin.DeviceTable.table actor={@current_user} tenant={@tenant} />
    """
  end
end
```

Or with a base filter:

```elixir
def render(assigns) do
  query = SootAdmin.DeviceTable.query(tenant_id: assigns.tenant.id, state: :operational)
  ~H"""
  <SootAdmin.DeviceTable.table actor={@current_user} query={query} />
  """
end
```

## Filtering helpers

`CertificateTable.query/1` accepts:

- `:status` — restrict to one of `:active | :revoked | :expired`
- `:issuer_id` — restrict to one CA
- `:expiring_within_days` — show active certs whose `not_after` falls in
  the next N days

`DeviceTable.query/1` accepts `:tenant_id` and `:state`. `EnrollmentQueue.query/1`
already filters to `:unprovisioned`/`:bootstrapped`; pass `:tenant_id` to narrow.

## Charting

`SootAdmin.SegmentChart.chart_spec/2` returns `%{sql, columns, config}`
ready for an operator-supplied chart renderer:

```elixir
spec = SootAdmin.SegmentChart.chart_spec(MyApp.Segments.VibrationP95,
  from: ~U[2026-04-25 00:00:00Z],
  metrics: [:axis_x_p95, :samples])

# Run spec.sql via your ClickHouse client; pipe rows into your JS chart lib.
```

The library deliberately does **not** ship a renderer — that depends on
which JS chart lib (Chart.js, ECharts, ApexCharts…) the operator
prefers. `chart_spec/2` produces enough metadata
(`config.x_axis`/`config.y_axes`/`config.series_for`) for any of them.

## What this library is not

- Not a finished admin app. There's no router, no layout, no theme, no
  auth integration. Operators wire their `ash_authentication` (or other)
  setup as the actor.
- Not a chart renderer.
- Not a real-time fleet map / device console / SSH-like terminal.
- Not a customizable-dashboard framework — operators compose dashboards
  in their own LiveView modules out of the components we ship.

## Tests

```sh
mix test
```

29 tests cover the column specs reference real attributes on every
underlying resource, every documented `query/1` filter option produces
the expected `Ash.Query` predicate, sort orders match the
operator-facing assumption (e.g. `CertificateTable` sorts by `not_after`
asc so soonest-expiring rises), `TelemetryStreamPanel.ingest_sessions_query/2`
narrows correctly, and `SegmentChart.chart_spec/2` defaults the title
from the segment name, builds y-axes from every metric (or a subset
when `:metrics` opt is passed), and stamps the aggregation kind into
`series_for`.
