# MG-003 — MATLAB Module Boundaries and Data-Interface Freeze

**Contract version:** `mg-contract/1.0` · **Prepared:** 2026-10-31 · **Owner:** Shabaz · **State:** proposed interface freeze, **not implemented MATLAB code**.
**Prerequisites verified on GitHub main:** MG-001 DONE (original Phase-1 title, objectives and problem statement verified), MG-002 DONE (Rahil's MATLAB R2026b/MCP and toolbox smoke-test evidence).
**Primary scope:** frozen Phase-1 original objectives in [PHASE1_BASELINE.md](PHASE1_BASELINE.md); simulations cannot establish real buried-mine detection or minefield safety.

## 1. Non-negotiable software contracts

1. All internal geometry is a local **right-handed ENU** frame in **metres**: `x_east_m`, `y_north_m`, `z_up_m`; origin (0,0,0) is the synthetic scenario's southwest ground datum. `z_up_m` is height above datum, not necessarily ground clearance. Convert ENU↔NED *only* inside the UAV Toolbox adapter, with unit and axis tests.
2. Time is `t_s`, seconds relative to simulation start, **finite and nondecreasing**. For streams with independent samples, sort stably by `t_s` and preserve unique integer IDs. Use `dt_s > 0` for simulation steps; `sampling_hz > 0` for sample generation. Do not mix timestamps with wall-clock UTC.
3. Internal thermal numeric field is **`temperature_K` (kelvin)**; user interface may display °C by `°C=K-273.15`. Synthetic EM `response_norm` is **dimensionless normalized model output**, never advertised as measured tesla, voltage, dB or proven field sensitivity.
4. Unitful geometry may include finite zero; soil/target depth `burial_depth_m >= 0`; `standoff_m >= 0`; yaw/roll/pitch are radians. Synthetic geotags are `virtual_lat_deg`, `virtual_lon_deg` with declared synthetic reference origin; never label them as real GNSS measurements.
5. Every scenario has a saved integer `seed`, unique `scenario_id` and `schema_version`. Scenario generator must not rely on existing global RNG state; use a locally scoped deterministic `RandStream` (or save/restore state), with downstream channel-specific seeds derived reproducibly and recorded. Different scenario IDs or seeds must not be accidentally reused across training/held-out splits.
6. **Ground-truth firewall:** `TargetTruth` and the hidden target state are consumed only by scenario generation, *forward* physical-response simulators, and evaluator. Navigation planners, detector, fusion and RL observations receive **no `TargetTruth`, `label`, `burial_depth_m` or target-object coordinates through their public inputs**. Forward models return observations, not labels. Evaluation receives predicted events and truth in a distinct call.
7. Missing readings are represented explicitly by `valid=false` and `NaN` in numeric measurement fields, accompanied by `invalid_reason`; never replace missing values with true target labels, forced zero, or invented confidence. No detection if both modalities missing. A remaining single modality can yield a specifically tagged single-channel result only if accepted by documented detection logic.
8. Detection classification uses `status='SUSPECTED'`. No output, chart or export may assert `SAFE`, `CLEARED` or `CONFIRMED MINE`. `confidence_0_1` is a *model score* until validated/calibrated.
9. All MATLAB public function signatures, field spellings and units below are stable for version 1.0. Any changed field requires a separate documented `schema_version` increment, migration note and regression test before merging.

## 2. Typed records — canonical MATLAB `struct` / `table` mapping

Use `struct` for a single configuration/scenario/result, and MATLAB `table` for repeated rows. No toolbox-specific class is required by the contract. Empty records must retain all columns with typed zero-row arrays, not an ambiguous 0x0 double.

| Type | Required fields and exact MATLAB-compatible meanings | Ownership / visibility |
|---|---|---|
| `ExperimentConfig` | `schema_version` (string = `mg-contract/1.0`), `scenario_id` (string), `seed` (nonnegative finite integer), `x_min_m`, `x_max_m`, `y_min_m`, `y_max_m` (double, strict min<max), `terrain_id` (string), `grid_spacing_m` (positive double), `dt_s` (positive double), `sampling_hz` (positive double), `altitude_m` (nonnegative double), `speed_mps` (positive double), `noise_seed` (integer), `target_count` and `clutter_count` (nonnegative integers), `min_separation_m` (nonnegative double), `soil_class` (string), `model_version` (string) | Config accepted by scenario, navigation, sensor model and experiment driver; do not embed secret keys or field mine coordinates |
| `ScenarioGeometry` | `schema_version`, `scenario_id`, `bounds_enu_m` (1x4 numeric `[x_min x_max y_min y_max]`), `terrain_id`, `terrain_model` (descriptive struct, non-sensitive), `exclusion_polygons_enu_m` (cell array of Nx2 coordinate arrays; empty cell permitted) | Shared with planner and plotting; excludes target locations and labels |
| `TargetTruth` | MATLAB table: `target_id` (unique string), `x_east_m`, `y_north_m` (finite doubles in bounds), `burial_depth_m` (nonnegative double), `material_type` (string, descriptive), `label` (categorical string `target|clutter`), `soil_class` (string); additional optional `surface_exposed` logical | **Evaluator and forward physics only.** Include a separate typed zero-row table for an empty field; never send to detector, policy or app's inference callbacks |
| `Scenario` | `config` (`ExperimentConfig`), `geometry` (`ScenarioGeometry`), `hidden_truth` (`TargetTruth`), `environment` (struct with documented soil/thermal parameters and units). This wrapper is *restricted*. | Generator hands restricted scenario to orchestrator; orchestrator shares only appropriate subrecords per module |
| `PoseSample` | table: `pose_sample_id` (unique string), `t_s`, `x_east_m`, `y_north_m`, `z_up_m`, `roll_rad`, `pitch_rad`, `yaw_rad`, `virtual_lat_deg`, `virtual_lon_deg`, `gps_sigma_m`, `waypoint_id` (string), `mission_state` (string enum `INIT|SURVEY|COMPLETE|ABORTED`) | Navigation/virtual telemetry, downstream sample association and UI. `virtual_*` values may be NaN with `gps_sigma_m=NaN` if not configured |
| `SensorSample` | table: `sample_id` (unique string), `pose_sample_id`, `t_s`, `sensor_kind` (string `thermal|em`), `temperature_K` (double, NaN for EM), `response_norm` (double, NaN for thermal), `noise_sigma` (nonnegative double in the same channel unit: K for thermal, normalized units for EM), `standoff_m`, `footprint_radius_m` (nonnegative doubles), `valid` (logical), `invalid_reason` (string, empty for valid) | Simulator output consumed by detector; no hidden label/target IDs in public readings |
| `DetectionEvent` | table: `event_id` (unique string), `t_s`, `x_est_m`, `y_est_m`, `confidence_0_1` (double in [0,1] or NaN if unavailable), `uncertainty_m` (nonnegative/NaN), `thermal_sample_id` (string or empty), `em_sample_id` (string or empty), `method_name` (string), `threshold` (numeric model threshold), `status` (string always `SUSPECTED`), `valid` (logical) | Detectors/fusion→map/app/export; estimated positions not exact truth |
| `ExperimentResult` | `schema_version`, `scenario_id`, `seed`, `algorithm`, `coverage_fraction` (double [0,1]), `mission_time_s` (>=0), `distance_m` (>=0), `tp`, `fp`, `tn`, `fn` (nonnegative ints), `precision`, `recall`, `f1`, `false_alarm_rate` (double [0,1] or NaN if denominator 0), `localization_error_m` (>=0 or NaN), `matlab_release`, `toolbox_manifest`, `git_sha`, `split_id`, `scenario_seed` | Evaluator only produces metrics with withheld `TargetTruth`; report with uncertainty/sample denominator and synthetic qualifier |

### Schema scope and version normalization

Earlier draft `DATA_CONTRACTS.md` used `lat_deg/lon_deg`, `measurement_value`, `class_pred` and `score_0_1`. For v1.0, use the unambiguous `virtual_lat_deg/virtual_lon_deg`, channel-specific `temperature_K/response_norm` and `confidence_0_1` names above. **Do not mix aliases.** Historical draft names remain documented in `DATA_CONTRACTS.md` as a migration note. If a module cannot support a value, carry explicit NaN/invalid flags rather than silently changing field names.

## 3. Folder ownership and public MATLAB API surface

These are *planned* function names/files, not pre-existing or already tested implementations. Every module accepts and returns the exact records in Section 2.

| Task | Proposed relative file / function signature | Output + invariant | Uses which source |
|---|---|---|---|
| MG-004 | `matlab/+mineguard/+scenario/generateScenario.m`: `[geometry, truth, environment] = generateScenario(config)` | Valid `ScenarioGeometry`, private `TargetTruth`, environment; same seed yields equal fields and positions; placement within bounds, non-overlapping where required | `ExperimentConfig` |
| MG-004 | `matlab/+mineguard/+scenario/validateScenario.m`: `validateScenario(config,geometry,truth)` | Throws `mineguard:InvalidScenario` for invalid bounds, seed, IDs, geometry or target overlap | `ExperimentConfig`, `ScenarioGeometry`, `TargetTruth` |
| MG-005 | `matlab/+mineguard/+navigation/makeGridRoute.m`: `route = makeGridRoute(config,geometry)` | Nx3 route points in ENU metres, no illegal/excluded coordinates, independent of hidden truth | config + **geometry only** |
| MG-005 | `matlab/+mineguard/+navigation/simulatePose.m`: `poses = simulatePose(config,geometry,route)` | Typed `PoseSample` table; monotonic `t_s` and legal positions; zero truth leakage | config + geometry + route |
| MG-007 | `matlab/+mineguard/+sensors/simulateThermal.m`: `samples = simulateThermal(config,scenario,poses)` | Typed `SensorSample` table, `sensor_kind='thermal'`, `temperature_K` in kelvin, EM output NaN; physics assumptions logged | restricted scenario and pose |
| MG-007 | `matlab/+mineguard/+sensors/simulateEM.m`: `samples = simulateEM(config,scenario,poses)` | Typed `SensorSample` table, `sensor_kind='em'`, `response_norm` unitless, thermal output NaN; long-range falloff checked | restricted scenario and pose |
| MG-009 | `matlab/+mineguard/+detection/detectAnomalies.m`: `events = detectAnomalies(config,poses,samples,model)` | `DetectionEvent` table from **observations only**, no `Scenario`/truth parameter | config, poses, sensors |
| MG-009 | `matlab/+mineguard/+evaluation/scoreDetections.m`: `result = scoreDetections(config,events,truth,runMetadata)` | `ExperimentResult`, one-to-one association under declared tolerance; no label leakage to detector | estimated events and **evaluator-only** truth |
| MG-011 | `matlab/+mineguard/+app/openMissionApp.m`: `app = openMissionApp(runBundle)` | Replays pose/sensor/events and clearly labels SIMULATION; hidden truth not fed into detection callbacks | redacted run bundle |
| MG-015 | `matlab/+mineguard/runExperiment.m`: `runBundle = runExperiment(config)` | Reproducible orchestration, provenance, held-out truth only for metrics, logging/export | all components after integration |
| MG-013 (optional) | `matlab/+mineguard/+rl/selectSurveyCell.m`: `action = selectSurveyCell(observation,allowedCells,policy)` | Only observable map/pose/budget; no privileged truth | observation + policy |

**Minimum MG-004 deliverable:** implement `generateScenario` + `validateScenario` and `matlab/tests/testMG004Scenario.m` using MATLAB `matlab.unittest` (or reproducible assertions as an interim test). Do **not** build UI, fusion, RL or external datasets in MG-004. Prefer core MATLAB types and a small deterministic fixture. The exact public signatures above are frozen.

## 4. Scenario generator requirements (handoff to Rahil for MG-004)

- `x_min_m < x_max_m`, `y_min_m < y_max_m` in metres. Default academic fixture (clearly **test only**, not physical UAV performance): rectangle [0,20] m east × [0,20] m north, seed 42, flat datum height 0 m, scenario ID `S0-seed42`, `target_count=1`, `clutter_count=1`, and `min_separation_m=0.5` for a geometry-only test fixture. It is not a real minefield or hazardous-site map.
- The generator must define `environment` with named soil class and thermal/EM model-parameter placeholders with units, **not** fabricate calibrated physical constants or claim genuine sensor detection.
- Ensure positions finite and within bounds (optionally apply a documented boundary margin), target IDs unique, depths nonnegative, object coordinates in ENU. A zero-target scenario must work and return correctly typed empty truth.
- If number of requested objects exceeds physically placeable capacity under configured separation, fail with `mineguard:InvalidScenario` or a bounded explicit attempt error; **never infinite-loop** placement.
- Save/replay seed and config; same seed and config yields bitwise-equal geometry/truth on the tested MATLAB R2026b installation. Different seeds are not required to yield unique layouts for every pair but should differ statistically across a sampled set.
- Explicitly separate `geometry` visible to navigation from `truth` visible only to forward physics/evaluator. The planner API must not accept `truth` or `scenario` containing it.

## 5. Contract and sanity test IDs (actual MATLAB execution is Rahil's responsibility)

| Test ID | Scope | Required invariant |
|---|---|---|
| C-01 | Scenario config | Reject NaN/Inf, inverted or zero bounds, negative seed, invalid count, malformed exclusions; errors contain actionable identifiers |
| C-02 | Determinism | `generateScenario(config)` twice: equal geometry/truth/environment for same fixed seed |
| C-03 | Geometry | Every ground-truth coordinate finite and within `bounds_enu_m`; duplicate IDs impossible |
| C-04 | Empty field | Zero target/clutter count produces valid zero-row `TargetTruth`; downstream interfaces do not crash |
| C-05 | Privacy/truth firewall | `ScenarioGeometry` has no `hidden_truth`, `TargetTruth`, `label`, target count or target coordinates; navigation signatures accept geometry only |
| C-06 | Data units | All x/y/z/depth in metres, temperatures in K, angles in rad and EM `response_norm` unitless |
| C-07 | Impossible placement | Overcrowded bounds with minimum-separation rules produce bounded clear error, not hang |
| C-08 | Future sensor validity | Single invalid sensor remains NaN/invalid; detector cannot read hidden truth; missing-all-modality result is empty |
| C-09 | Future scoring | Zero metric denominator → NaN with denominator recorded; never report unvalidated mine-detection accuracy |
| C-10 | UAV boundary | ENU to NED conversion tested at north/east/up basis directions when adapter first introduced |

Tests C-01–C-05 and C-07 are **MG-004 minimum acceptance**; the others are later task gates. A green GitHub Node `task-gate` means governance checks passed, *not* that any MATLAB tests ran.

## 6. Integration interfaces, data flow and error policy

```text
ExperimentConfig -> generateScenario -> [ScenarioGeometry + private TargetTruth + Environment]
                                        |
                geometry-only -> makeGridRoute -> simulatePose -> PoseSample
                                        |
                physics-only hidden state + PoseSample -> simulateThermal / simulateEM
                                        |
                SensorSample + PoseSample (NO truth) -> detectAnomalies -> DetectionEvent
                                        |
                DetectionEvent + TargetTruth (EVALUATOR ONLY) -> ExperimentResult
                                        |
                redacted RunBundle -> App Designer / exports
```

- Forward models may use physical hidden state as simulator inputs; they may not attach true labels/coordinates to `SensorSample`.
- `ScenarioGeometry` must be serializable without protected/private data and remain stable for route planning.
- Error identifiers should begin `mineguard:`; invalid input must throw, not silently clip. `ABORTED` is an explicit simulated mission state, never a false pass.
- `RunBundle` aggregates config, geometry, poses, sensor samples, detections, result and non-sensitive provenance; **private truth is not in the App/telemetry export bundle** unless explicitly labelled as a separate evaluator-only training fixture.
- Experiment filenames should include scenario ID, seed, ISO date and Git commit; deterministic content tests must exclude inherently variable wall-clock metadata from equality assertions.
- Units, data types, function signatures and privacy guarantees are **frozen now**; physically calibrated model constants, solver choice, sampling cadence, PPO architecture and exact numerical accuracy targets remain explicitly **NOT FROZEN**, since no representative measurements justify them.

## 7. Objective traceability and feature gates

| FR | Frozen objectives | Tasks | Minimal evidence |
|---|---|---|---|
| FR-01 deterministic simulated scenario | O1, O2 | MG-004 | MATLAB C-01–C-05/C-07, seed/config and real logs |
| FR-02 grid navigation | O1 | MG-005 | boundary check, pose log and coverage |
| FR-03 thermal+EM model | O2 | MG-006, MG-007 | parameter provenance, standoff/soil/negative tests |
| FR-04 detector/fusion | O2 | MG-008, MG-009 | held-out metrics, ablations, no truth leakage |
| FR-05 virtual geotag | O3 | MG-005, MG-009 | ENU source, coordinate error and timestamp |
| FR-06 app mission view | O3 | MG-010, MG-011 | simulation UI replay and export test |
| FR-07 PPO comparison | O1 | MG-012, MG-013, MG-019 | actual training + same-budget held-out comparison; optional for core integration |
| FR-08 evidence/export | O2, O3 | MG-014, MG-015 | Git SHA, seed, MATLAB release, true run results |
| FR-09 personnel-free virtual survey | O4 | MG-015, MG-018 | simulation autonomy demonstration and safety limitation |

## 8. Change control and sign-off

This is a **documentation specification freeze**, not proof of a built MATLAB application. Shabaz reviews the PR and green GitHub CI; the change becomes authoritative only after merge to `main` and MG-003 is marked DONE in a separate status-transition PR.

**Handoff:** Once MG-003 is officially DONE on `main`, Rahil should fetch latest main, read **Sections 2–5** (no need to reread all docs), start MG-004 on `task/MG-004-...`, implement the two scenario functions and tests, run MATLAB R2026b via official MCP, and open a PR with actual commands, logged observations and no claims of field mine detection.
