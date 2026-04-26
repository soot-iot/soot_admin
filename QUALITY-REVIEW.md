# `soot_admin` — Phase 6 quality review

Reviewed against `sprawl/soot/QUALITY-REVIEW.md` at commit `5b2bf14`.
Findings ordered by severity within each group.

## Gate status (before review)

```
mix deps.unlock --check-unused   ✓ (clean after `mix deps.get`)
mix deps.audit                   ✗ task not found (mix_audit not installed)
mix format --check-formatted     ✗ 8 files dirty (see Stylistic 28)
mix compile --warnings-as-errors ✓
mix credo --strict               ✗ task not found
mix sobelow                      ✗ task not found
mix test                         ✓ 29 tests, 0 failures
mix dialyzer                     ✗ task not found
```

## Correctness bugs

### 1. `Cinder.Table.table` is deprecated for removal in cinder 1.0
The vendored cinder 0.12.1 marks `Cinder.Table.table/1` as `@deprecated
"Use Cinder.collection instead"` and the moduledoc states "**DEPRECATED:**
… This module will be removed in version 1.0." Every public component
in this library wraps `<Cinder.Table.table ...>`. `mix.exs` pins
`{:cinder, "~> 0.12"}`, so 0.13/0.14 are reachable via `mix deps.update`
and a future point release that drops the shim breaks every component
shipped here. Either migrate to `Cinder.collection` now or pin a tighter
range and document the migration deadline.

References: `lib/soot_admin/tables/device_table.ex:90`,
`certificate_table.ex:79`, `enrollment_queue.ex:59`,
`segment_table.ex:46`, `panels/telemetry_stream_panel.ex:54`,
`deps/cinder/lib/cinder/table.ex:1-15, 92`.

### 2. `column_specs/0` is dead documentation — never wired into `table/1`
Every module declares `column_specs/0` returning `[{field, opts}, …]`
with `:filter`, `:sort`, `:label`, `:class` metadata. None of the
`table/1` HEEx components consume that list. The HEEx hard-codes a
*different and shorter* column set (and re-derives `filter sort` from
nothing). The README, moduledoc, and tests all imply the spec is the
source of truth; in reality it's a parallel surface that drifts the
moment the HEEx is edited. Either render the table from the spec
(loop the slot over `column_specs/0`) or delete the function and
reflect that operators copy/edit the HEEx.

References: `lib/soot_admin.ex:6-13`,
`lib/soot_admin/tables/device_table.ex:36-46 vs :86-103`,
`certificate_table.ex:16-27 vs :75-87`,
`enrollment_queue.ex:21-29 vs :55-71`,
`segment_table.ex:21-30 vs :42-54`,
`panels/telemetry_stream_panel.ex:17-26 vs :50-61`.

### 3. Spec/HEEx column drift — tables omit declared columns
Concrete instances of bug 2:

* `DeviceTable`: spec lists `:batch_id`, `:operational_certificate_id`;
  HEEx omits both.
* `CertificateTable`: spec lists `:issuer_id`, `:revoked_at`,
  `:revocation_reason`; HEEx omits all three. The whole "is it
  revoked, when, why" panel is missing from the rendered table.
* `EnrollmentQueue`: spec lists `:bootstrap_certificate_id`; HEEx
  omits it. Operators using this queue cannot see whether the
  bootstrap cert has been issued.
* `SegmentTable`: spec lists `:current_version_id`; HEEx omits it.
* `TelemetryStreamPanel`: spec lists `:current_schema_id`,
  `:partitioning`; HEEx omits both.

Either fix tables to render the declared columns, or trim the specs
back to what the table actually shows.

References: same as finding 2.

### 4. Spec `filter:` / `sort:` opts are silently dropped by `table/1`
`DeviceTable.column_specs` declares `{:state, filter: :select, sort:
true}`. The HEEx writes `<:col field="state" filter sort>` — i.e. the
`:select` hint is lost and Cinder auto-detects from the Ash attribute.
Same for every other module. If the operator is meant to copy the
HEEx, the spec is misleading; if the spec is supposed to drive the
table, it does not. Pick one.

### 5. Multitenancy `:tenant` attr passed to non-multitenant resources
Neither `SootCore.Device`, `AshPki.Certificate`, `SootTelemetry.StreamRow`
nor `SootSegments.SegmentRow` declare `multitenancy do … end`.
`DeviceTable.table` and `EnrollmentQueue.table` both accept `attr
:tenant` and pass it to `<Cinder.Table.table tenant={@tenant}>` which
forwards to `Ash.Query.set_tenant/2` if non-nil. With no multitenancy
strategy the call is at best a no-op; at worst it'll raise once Ash
tightens the API. Either drop the `:tenant` attr or wire the
underlying resources for multitenancy.

References: `lib/soot_admin/tables/device_table.ex:80, 94`,
`enrollment_queue.ex:51, 63`. README `:88-95` claims multi-tenant
narrowing is supported — confirm the resources first.

### 6. README `<.live_component module={SootAdmin.DeviceTable} …>` example doesn't work
README lines 9-15 show:

```heex
<.live_component module={SootAdmin.DeviceTable} id="device-table" actor={@current_user} />
```

`SootAdmin.DeviceTable` is `use Phoenix.Component`, not
`Phoenix.LiveComponent`. The above raises at runtime
("module … is not a Phoenix.LiveComponent"). The `<SootAdmin.DeviceTable.table .../>`
form (the second example) is the correct one. Drop the live-component
example or convert at least one module to a LiveComponent.

References: `lib/soot_admin/tables/device_table.ex:10-14, 22`,
`README.md` (rendered lines 9-15 of the moduledoc).

### 7. `validate_columns/2` claims to check calculations but only checks attributes
Moduledoc: "Validate that every column spec references an attribute or
calculation that actually exists on the underlying Ash resource." The
implementation only consults `Ash.Resource.Info.attributes/1`. Calls
that include a calculation field name will be flagged
`{:unknown_field, …}` even when the calculation is real. Either union
in `Ash.Resource.Info.calculations/1` (and `aggregates/1`,
`relationships/1` if dotted-paths matter) or trim the moduledoc to
"attribute".

References: `lib/soot_admin.ex:25-47`.

### 8. `apply_state` / `apply_status` / `apply_issuer` raise `FunctionClauseError` on bad input
`DeviceTable.query(state: "operational")` (string instead of atom)
crashes with `FunctionClauseError` rather than returning a useful
error or skipping the filter. Same for `CertificateTable` `:status`
(non-atom), `:issuer_id` (any), `:expiring_within_days` (non-integer).
For an operator-facing helper this is unfriendly — at minimum
convert string inputs (the form-submit shape) or raise with a
descriptive message.

References: `lib/soot_admin/tables/device_table.ex:72-77`,
`certificate_table.ex:46-69`,
`enrollment_queue.ex:43-48`.

## Component / config hygiene

### 9. `:page_size` only on `DeviceTable.table`, not the others
`DeviceTable.table` accepts `attr :page_size, :integer, default: 25`.
The other four `table/1` components silently default to Cinder's 25
with no override. Operator surface is inconsistent. Either add
`:page_size` to every table or document why Device gets one.

References: `lib/soot_admin/tables/device_table.ex:83`.

### 10. `:base_query` opt only documented on `DeviceTable.query/1`
`DeviceTable.query/1`'s @doc lists `:base_query`; the same option is
silently honored by every other module's `query/1` but is not
documented in their `@doc`. Either remove the opt or document it
everywhere.

References: `lib/soot_admin/tables/certificate_table.ex:30-34`,
`enrollment_queue.ex:31-32`, `segment_table.ex:32-36`,
`panels/telemetry_stream_panel.ex:29-33`.

### 11. `TelemetryStreamPanel.ingest_sessions_query/2` ignores `_opts`
Signature is `ingest_sessions_query(stream_id, _opts \\ [])` but the
function body never reads opts. Either implement (`:from`, `:until`,
`:device_id` are obvious candidates) or drop the second parameter and
update the @doc.

References: `lib/soot_admin/panels/telemetry_stream_panel.ex:39-44`.

### 12. `validate_columns/2` calls `String.to_atom/1` on string fields
Specs are static today, so the unbounded atom-table conversion is
benign. If the function is ever fed user input (e.g. an admin
column-picker), the conversion is an atom-leak vector. Use
`String.to_existing_atom/1` once columns are known to be atom-named.

References: `lib/soot_admin.ex:38-40`.

### 13. `SegmentChart.chart_spec/2` advertises a "chart spec" but produces operator-side metadata
The moduledoc is honest ("not a renderer") but the return key is named
`config` — operators may reasonably expect that to be a Vega-Lite or
Chart.js spec. It's neither; it's `%{title, x_axis, y_axes, series_for}`.
Rename to `chart_meta` (or equivalent) or document the shape in the
@spec so callers can typespec against it.

References: `lib/soot_admin/charts/segment_chart.ex:1-21, 36-55`.

### 14. `attr :query` defaults to `nil` but the body assigns it via `assign_new` to `query()`
Idiomatic but slightly surprising: a `nil` default plus
`assign_new(:query, fn -> query() end)` will only call `query()` when
the assign is *missing*, not when it's explicitly `nil`. If a parent
passes `query={nil}` (e.g. an unloaded form), `<Cinder.Table.table
query={nil}>` is rendered. Either drop the default and let `assign_new`
handle absence, or pattern-match `nil` and rebuild.

References: every `table/1` (`device_table.ex:81-87`, etc.).

## Test gaps

### 15. Zero `table/1` HEEx render tests
Every public Phoenix component (`table/1` on five modules) has no
render test. A breaking change in Cinder, a typo in a slot attr, or a
silently dropped column would not fail any test. At minimum, render
each component with `Phoenix.LiveViewTest.render_component/2` and
assert the column headers contain the expected labels.

### 16. `SootAdmin.validate_columns/2` `{:error, _}` branch never tested
Every test case asserts `:ok = SootAdmin.validate_columns(...)`. The
error-shape return (`{:error, [{field, :unknown_field}, …]}`) is
documented in the @spec and unexercised. Add a test that feeds a
deliberately-bogus spec.

References: `lib/soot_admin.ex:25-47`.

### 17. `CertificateTable.query(:expiring_within_days)` does not assert the cutoff
The current test asserts the inspect string contains `"not_after"`
and `"active"`. It does not assert that the cutoff is `now + N*86_400s`,
so a bug like "added `* 1_000` instead of `* 86_400`" or "subtract
instead of add" would pass. Build an `Ash.Query` and inspect the
filter's right-hand side (or compare against a hand-rolled query).

References: `test/soot_admin/tables/certificate_table_test.exs:35-40`,
`lib/soot_admin/tables/certificate_table.ex:60-69`.

### 18. `SegmentChart` `:from`, `:until`, `:dims`, `:target` opts untested
`chart_spec/2` forwards every option to `Query.sql/2` and
`Query.cinder/2`. Only `:metrics` and `:title` are exercised. Add at
least one test with a custom window asserting the SQL contains the
expected `bucket >= ...` literal, and one with `:dims` narrowing the
columns list.

References: `lib/soot_admin/charts/segment_chart.ex:37-55`,
`test/soot_admin/charts/segment_chart_test.exs`.

### 19. `:base_query` opt only tested on `DeviceTable`
`EnrollmentQueue`, `CertificateTable`, `SegmentTable`, and
`TelemetryStreamPanel` all accept `:base_query` but no test covers
that the supplied query is preserved and chained.

### 20. `TelemetryStreamPanel.ingest_sessions_query/2` second-arg behaviour untested
Once the opts argument actually does something (finding 11), it'll
need tests. Today the test only covers the no-opts shape.

References: `test/soot_admin/panels/telemetry_stream_panel_test.exs:29-35`.

### 21. `SegmentChartTest` setup uses a blanket `try/rescue _ -> :ok`
```elixir
try do
  :ets.delete_all_objects(resource)
rescue
  _ -> :ok
end
```
Standard playbook anti-pattern. Either guard the call (`if
:ets.whereis(resource) != :undefined do …`) or rescue the specific
`ArgumentError` raised when the table doesn't exist.

References: `test/soot_admin/charts/segment_chart_test.exs:7-15`.

### 22. `test_helper.exs` is bare `ExUnit.start()`
soot_telemetry settled on `ExUnit.start(capture_log: true)` as the
floor. No logger calls today, but matches the rest of the stack.

References: `test/test_helper.exs:1`.

### 23. `SegmentChartTest` is `async: false` and pollutes registry state
The test reaches into `:ets.delete_all_objects(SootSegments.SegmentRow)`
to reset state between runs. A `DataCase`-style setup or
`SootSegments.Registry.reset/0` (if it exists) would be cleaner and
let the tests run async. Same finding as soot_telemetry's review.

References: `test/soot_admin/charts/segment_chart_test.exs:2, 7-18`.

## Tooling gaps

### 24. No LICENSE file
`package: licenses: ["MIT"]` declared, no LICENSE file ships. Same
finding as soot_contracts.

### 25. Hex package metadata incomplete
* `links: %{}` empty.
* No `files:` allow-list — defaults pull `_build/`, `deps/`, and
  (today) `erl_crash.dump` (8.4 MB) into any future hex publish.
* No `source_url`, no `docs:`, no `aliases:`, no `dialyzer:` block.

Mirror `soot_telemetry/mix.exs:30-67`. Reference: `mix.exs:30-35`.

### 26. `consolidate_protocols: Mix.env() != :test`
Should be `Mix.env() == :prod`. Standard finding from earlier reviews.

Reference: `mix.exs:13`.

### 27. `elixir: "~> 1.16"` lags the rest of the stack
soot_telemetry pins `1.18.3-otp-27` in `.tool-versions` and uses
`~> 1.16` only as the lower bound. soot_admin has neither
`.tool-versions` nor an upper-pin policy. Pin to match.

Reference: `mix.exs:10`.

### 28. No `.tool-versions`
Pin `elixir 1.18.3-otp-27` / `erlang 27.3` to match the stack.

### 29. No CHANGELOG.md
Mirror `soot_telemetry/CHANGELOG.md`. First entry: "Initial Phase 6
release".

### 30. No CI workflow
Mirror `soot_telemetry/.github/workflows/elixir.yml` — same gate steps.

### 31. No lint stack
No `.credo.exs`, `.dialyzer_ignore.exs`, `.sobelow-conf`. No deps for
`:credo`, `:dialyxir`, `:sobelow`, `:mix_audit`, `:ex_doc`. Once
added, `Credo.Check.Design.AliasUsage` will probably want to be
disabled per the stack convention.

### 32. `erl_crash.dump` (8.4 MB) at repo root
Listed in `.gitignore`, so git ignores it. With no `package: files:`
allow-list, however, it would be packaged by `mix hex.publish`.
Delete the dump and add a `files:` allow-list.

Reference: repo root.

## Stylistic / minor

### 33. Formatter dirty (8 files)
`mix format --check-formatted` flags eight files where Spark/Phoenix
DSL macros need explicit parens after `mix format --migrate`:

* `test/support/fixtures.ex` — `tenant_scope`, `order_by`, `name`,
  `source_stream`, `granularity`, `dimension`, `metric` macros.
* `lib/soot_admin/tables/{device,certificate,enrollment_queue,segment}_table.ex`
  and `lib/soot_admin/panels/telemetry_stream_panel.ex` — Phoenix
  `attr/3` macro calls need parens.
* `test/soot_admin/tables/{certificate,enrollment_queue}_table_test.exs`
  — long `assert :ok = SootAdmin.validate_columns(...)` call needs
  multi-line indent.

`mix format` resolves all of them; the diff is mechanical. (Note that
the `attr` rewrite introduces parens that some style guides actually
disprefer for the macro form; the upstream Phoenix usage rules don't
state a preference. Either accept the format-migrate output or pin
the formatter to omit `:migrate`.)

### 34. README claims "29 tests"
Currently true, drifts. Drop the count or replace with "see `mix
test`". Same finding as soot_contracts.

References: `README.md:101-110`.

### 35. `extra_applications: [:logger]`
Fine — no `:crypto` or `:public_key` redundancy. Noted only because
sibling libraries needed trimming here.

### 36. `test/support/fixtures.ex` only used by one test
`SegmentChartTest` is the only consumer. Inlining the fixtures into
the test (or scoping them to that file) avoids dragging the
test-support compile path for a single use.

### 37. `SegmentChart.chart_spec/2` `default_title/1` builds `"Segment " <> Atom.to_string(...)`
Could use `"Segment #{Info.name(module)}"` for symmetry with the rest
of the codebase. Trivial.

References: `lib/soot_admin/charts/segment_chart.ex:64-66`.

### 38. `EnrollmentQueue` moduledoc references `SootCore.Plug.Enroll`
Confirm that module name still exists in `soot_core` after Phase 3b.
If renamed (e.g. to `SootCore.EnrollmentPlug`), update the doc.

References: `lib/soot_admin/tables/enrollment_queue.ex:9`.

### 39. `cinder` upstream URL in this prompt was wrong
The team-alembic/cinder GitHub URL returns 404. The vendored
`deps/cinder/mix.exs` does not declare a `source_url`, so the actual
upstream is unclear. Worth tracking down for the README link in this
library and the `links:` map fix.
