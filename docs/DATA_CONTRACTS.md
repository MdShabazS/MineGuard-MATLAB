# Data Contracts and Coordinates — MG-003 Frozen v1.0

**Authoritative contract:** [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md). That specification freezes **actual field names, MATLAB struct/table types, public function signatures, unit conventions, truth access, validations and task-to-test traceability** for `mg-contract/1.0`. This file is the short integration index and migration note. Contract acceptance is a **documentation task**; no MATLAB integration tests are implied.

## Canonical conventions

| Topic | Frozen v1.0 contract |
|---|---|
| Frame | Local right-handed ENU: `x_east_m`, `y_north_m`, `z_up_m` in metres; convert to NED only at UAV Toolbox adapter |
| Time | `t_s` seconds from simulation start; monotonic; `dt_s>0`, `sampling_hz>0` |
| Thermal | `temperature_K` (kelvin), optional UI conversion to °C |
| EM | `response_norm`, **unitless normalized simulation response** — never a claimed measured field strength |
| Virtual GPS | `virtual_lat_deg` and `virtual_lon_deg`, not a physical GNSS fix |
| Missing sensor | `valid=false`, numeric `NaN`, nonempty `invalid_reason`; don't silently fabricate samples |
| Geometry secrecy | Navigation receives `ScenarioGeometry` only, never `TargetTruth` or target counts |
| Simulation truth | `TargetTruth` privately available to scenario forward models and evaluator; **not** to classifier, policy, or inference App callbacks |
| Estimated detections | `DetectionEvent` location estimates, `confidence_0_1` and `status='SUSPECTED'` only |
| Reproducibility | Config `schema_version='mg-contract/1.0'`, `scenario_id`, seed and model version; held-out split IDs and run provenance |
| Empty datasets | Typed 0-row MATLAB `table` with preserved columns; do not use ambiguous 0x0 doubles |

## Canonical v1.0 records

1. `ExperimentConfig` — validated bounds, RNG seed, temporal/grid/vehicle settings, terrain/soil identifiers, target/clutter counts and min separation.
2. `ScenarioGeometry` — only boundary, terrain and exclusions visible to navigation/plotting.
3. `TargetTruth` — private labelled target/clutter table for physical forward-model and evaluator use.
4. `PoseSample` — simulated pose/virtual geotags/time.
5. `SensorSample` — thermal or EM reading with channel-specific value, standoff, footprint and validity.
6. `DetectionEvent` — suspected estimated anomaly, confidence, uncertainty and sample links.
7. `ExperimentResult` — evaluative metrics and complete reproducibility context.

See the primary specification for full field listings and exact function signatures. No arbitrary renaming is permitted inside implementations.

## Migration from original v0.1 draft

The initial planning document used shorthand identifiers that are **not** v1.0 canonical:

| v0.1 draft | v1.0 field or rule |
|---|---|
| `lat_deg`, `lon_deg` | `virtual_lat_deg`, `virtual_lon_deg` |
| generic `measurement_value/measurement_unit` | `temperature_K` for thermal or `response_norm` for EM, other field NaN |
| `score_0_1` | `confidence_0_1` |
| `class_pred` | `status='SUSPECTED'`; no assertion of real target class |
| `noise_sigma` without unit | channel-specific K or normalized response units |

If MATLAB feasibility forces a change, request it explicitly with version bump and tests; do not silently adapt consumer code. The separate `MG-004` task must use the **v1.0** source-of-truth record names in `MG003_INTERFACE_FREEZE.md`.

## Evidence requirements

- **MG-003 (documentation)**: interface freeze and traceability approved via task PR + CI and linked evidence file.
- **MG-004 (MATLAB build)**: actual `generateScenario` and `validateScenario` implementation, deterministic scenario tests, real MATLAB R2026b command/log and task evidence, **not** merely a syntax check.
- **Later modules**: test sensor validity, geotag conversion, leakage prevention, evaluator-only truth access, app output and data/export metadata.

See also [ARCHITECTURE.md](ARCHITECTURE.md), [REQUIREMENTS.md](REQUIREMENTS.md), [ACCEPTANCE_MATRIX.md](ACCEPTANCE_MATRIX.md) and [PHYSICS_AND_FEASIBILITY.md](PHYSICS_AND_FEASIBILITY.md).
