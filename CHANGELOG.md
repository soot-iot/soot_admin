# Changelog

All notable changes to `soot_admin` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to semantic versioning.

## [Unreleased]

### Added
- `:page_size` attribute on every `table/1` component (was DeviceTable-only).
- `:base_query` opt is now documented on every `query/1` helper.
- Render smoke tests for every public Phoenix component asserting
  every column declared in `column_specs/0` surfaces as a header.
- Test coverage for `validate_columns/2`'s `{:error, _}` branch.
- Test coverage for `CertificateTable.query(:expiring_within_days)`'s
  cutoff math (now + N*86_400s).
- Test coverage for `SegmentChart.chart_spec/2`'s `:from`, `:until`,
  `:dims`, `:target` opts.
- Test coverage for `:base_query` opt on every `query/1` helper.

### Changed
- Migrate every `<Cinder.Table.table>` call to `<Cinder.collection>`
  ahead of cinder 1.0 dropping the `Cinder.Table.table` shim.
- `column_specs/0` is now the documented source of truth for what
  columns each `table/1` renders. Every previously-declared but
  never-rendered column was added to the HEEx (DeviceTable's
  `:batch_id` / `:operational_certificate_id`, CertificateTable's
  `:issuer_id` / `:revoked_at` / `:revocation_reason`,
  EnrollmentQueue's `:bootstrap_certificate_id`, SegmentTable's
  `:current_version_id`, TelemetryStreamPanel's
  `:current_schema_id` / `:partitioning`).
- `<:col>` slots now receive the explicit filter type from
  `column_specs/0` (`filter={:select}` / `filter={:text}`) instead
  of bare `filter`, so the spec's declared filter type is honored
  end-to-end.
- `apply_state` / `apply_status` / `apply_issuer` / `apply_tenant` /
  `apply_expiring` accept string inputs (the form-submit shape) via
  `String.to_existing_atom/1` and raise `ArgumentError` with a
  descriptive message on bad input instead of crashing with a
  bare `FunctionClauseError`.
- `SegmentChart.chart_spec/2` returns `:chart_meta` instead of
  `:config` to avoid the (incorrect) suggestion that the value is a
  Vega/Chart.js spec.
- `validate_columns/2` uses `String.to_existing_atom/1` so it can't
  grow the atom table from operator-controlled input.
- `validate_columns/2` @doc no longer claims to check calculations
  (the implementation only consults `Ash.Resource.Info.attributes/1`).

### Removed
- `:tenant` attr on `DeviceTable.table` and `EnrollmentQueue.table`
  (the underlying resources are not multitenant; passing the attr
  was a no-op at best).
- `<.live_component module={SootAdmin.DeviceTable} ...>` example
  from the DeviceTable moduledoc — the module is `Phoenix.Component`,
  not `Phoenix.LiveComponent`, and the example raised at runtime.
- The unused second arg on
  `TelemetryStreamPanel.ingest_sessions_query/2`; tightened to /1.

## [0.1.0] - 2026-04-26

### Added
- Initial Phase 6 release: Cinder table configs and Phoenix
  function-component shells over `SootCore.Device`,
  `AshPki.Certificate`, `SootTelemetry.StreamRow`, and
  `SootSegments.SegmentRow`, plus `SootAdmin.SegmentChart` for
  building chart SQL + per-series metadata for an
  operator-supplied JS chart lib.
