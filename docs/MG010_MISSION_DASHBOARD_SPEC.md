# MG-010 — MATLAB Mission Control Dashboard: UI, Data and Acceptance Contract

Task: MG-010
Owner: Shabaz
Date: 2026-10-31
Kind: DOCUMENTATION / executable UI acceptance specification (not an implemented application)
Dependency: MG-003 DONE. Downstream: MG-011 (Rahil) requires MG-005, MG-009 and MG-010 DONE.

**Authoritative software interface:** `app = mineguard.app.openMissionApp(runBundle)` in [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md), `mg-contract/1.0`. This document adds **presentation-side requirements** and a *proposed view-only adapter*; it does **not** change a frozen public function signature, rename schema fields, approve a real drone, or imply the app exists.

**Persistent disclosure:** `SIMULATION — synthetic data; not validated for real mine detection or clearance.` Every primary view, exported report, screenshot and legend must convey that. Only `SUSPECTED` anomalies may be shown; never `SAFE`, `CLEARED`, `CONFIRMED MINE` or proof of non-hazard.

## 1. Implementation scope and staged delivery

**MG-011 minimum (must be truly implemented and tested):** a local MATLAB R2026b **desktop** mission-control app using App Designer `.mlapp` or a documented `uifigure` source-backed fallback. It opens a **precomputed, redacted synthetic replay** from an actual MATLAB run, presents 2-D ENU route + UAV position + readings + suspected-event map, offers play/pause/seek/reset and speed, reveals invalid/missing readings honestly, and exports reproducible data and an app snapshot. The required entry point is `mineguard.app.openMissionApp(runBundle)`.

**Later MG-015 (NOT a reason to fabricate MG-011 controls):** fully integrated experiment execution from UI buttons, simulation controller, cross-module orchestration and robust one-command demo. Until that driver is available, launch/replay from existing computed run records and label any generator settings **"Run metadata / replay only"**. Never advertise Start as controlling a physical UAV. A separate *Generate/Run Simulation* control can be added only after genuine invocation and end-to-end tests.

**Optional, feature-gated:** `uavScenario` 3-D view, PPO comparisons (MG-013/MG-019), richer interactive mapping, multi-run experiment explorer, image playback. When input, licence or tested implementation is absent, show **NOT AVAILABLE / NOT RUN** rather than placeholder or invented values. Core MG-011 must not depend on PPO or a 3-D renderer; default to 2-D `uiaxes`.

**Platform boundary:** Rahul's/Rahil's MATLAB R2026b on Windows is available as documented in MG-002. Mac GUI compatibility is **NOT VERIFIED** until independently tested, and a desktop GUI is not a web dashboard. The separate Render Guide Portal is a task-status website only, not mission control.

## 2. Data ownership, app trust boundary and view-only adapter

### 2.1 Non-negotiable truth and provenance firewall

Flow (logical, not a new MATLAB module API):

```text
MG-004 scenario + restricted truth
    -> MG-005 navigation / MG-007 sensor forward models
    -> MG-009 detector on observables ONLY -> DetectionEvent
    -> MG-009 evaluator only receives withheld truth -> aggregate ExperimentResult
    -> redaction + validation performed by app-facing adapter
    -> openMissionApp(redactedRunBundle) -> replay / plots / export
```

The app (including all callbacks and exported "inference" rows) must **never** receive `Scenario.hidden_truth`, `TargetTruth`, target counts/locations/depth/material, full unredacted `ExperimentConfig`, training/test labels or private evaluator matching pairs. Do not use ground-truth targets as heatmap centres or known "detections"; map suspected events by `DetectionEvent.x_est_m` and `y_est_m` only. Metrics from an evaluator may be displayed as **aggregate synthetic evaluation** values, on a distinct panel, only when explicitly present and properly labelled. No app callback may reclassify truth into sensor detection.

The `DetectorConfig`/model threshold may be *displayed* when provided as safe detector metadata; it must not be recomputed or silently tuned in the UI based on test truth. `temperature_K` is Kelvin; `response_norm` is dimensionless; `NaN` means unavailable, **never zero**.

### 2.2 Recommended MG-011 redacted view adapter (proposed, not frozen)

The frozen `openMissionApp(runBundle)` signature does not specify the exact fields of `runBundle`. To unblock implementation without amending `mg-contract/1.0`, use a **documented presentation adapter** to supply this minimum set, with optional fields explicitly marked:

| View field | Source and constraints | Required |
|---|---|---|
| `schema_version`, `scenario_id` | Must equal frozen contract, match every stream/scenario | yes |
| `geometry` | MG-003 `ScenarioGeometry` only; bounds/exclusions/terrain without hidden truth | yes |
| `poses` | MG-005 exact typed `PoseSample` table with pose IDs, monotonic `t_s`, ENU positions and optional `virtual_*` | yes; can be typed empty in IDLE |
| `thermal_samples`, `em_samples` | MG-007 exact 11-field typed `SensorSample` tables, including validity, time, channel fields | yes; typed zero-row permitted |
| `events` | MG-009 exact 12-field typed `DetectionEvent` table; empty is a real no-events case | yes; typed zero-row permitted |
| `result` | MG-009 evaluator `ExperimentResult` **aggregate**, must have declared `split_id`, denominators/metric units supplied separately | optional |
| `provenance` | `scenario_id`, seed(s), `model_version`, `matlab_release`, `git_sha`, source run timestamp/ID, manifest/toolboxes, split ID, simulation flags and **actual recorded** values | yes; unknown metadata is `NOT_RECORDED` |
| `comparison` | Future, clearly typed multi-run metrics and fair baseline/PPO protocols | optional |
| `display_settings` | Safe visual preferences only, e.g. replay speed, time window, optional detector threshold/decision rule | optional |

These view-only field names are **MG-010's proposed adapter**, not additions to frozen `PoseSample`, `SensorSample`, `DetectionEvent`, `ExperimentResult` or the `openMissionApp` call signature. Rahil should implement and document the actual adapter in MG-011 and test it against real MG-005/007/009 outputs.

**No extra keys carrying truth:** reject restricted wrappers and known forbidden fields recursively, including nested structs, cells, tables and future metadata additions. A raw `TargetTruth` table may never be stored inside this view record; the adapter should use an allowlist rather than pass-through. Export reuses this redaction and cannot serialize the unredacted simulator `Scenario`.

**Run identity checks:** reject mismatched `scenario_id`, `schema_version`, seed/provenance and valid `pose_sample_id` references; require valid `SensorSample.sensor_kind`; an event's `thermal_sample_id`/`em_sample_id` must reference a sample or explicitly be empty when unavailable. No "helpful" linking by hidden coordinates. Stable ordering for identical time stamps is time then input index or documented ID order.

**Run-data integrity:** run data are treated as immutable after opening. UI cursor and plot decimation may change, but no mutation of stored sample/pose/event values, model result, seeds, validity or returned IDs. Avoid external I/O at module import time. On invalid input display actionable error in the app (or throw a documented `mineguard:InvalidRunBundle` before UI creation); do not show mock plots.

## 3. User journey and information architecture

Proposed desktop layout (2-D map is primary; keep UI readable at common laptop resolutions such as 1366x768, measure actual use):

```text
+-----------------------------------------------------------------------+
| MINEGUARD SIMULATION | Scenario ID | Replay state | t_sim | Version   |
| SIMULATION — synthetic data; not validated for mine detection/clearance|
+----------------------+----------------------------+-------------------+
| Mission / Replay     | Survey map (ENU metres)    | Sensors / Events  |
| Load / Info          | legal survey region        | Thermal K [valid] |
| Play / Pause / Step  | route + vehicle marker     | EM norm [valid]   |
| Reset / Speed / Seek | waypoints + exclusions     | sampled time      |
| Seed / Method        | surveyed vs unvisited      | suspected list    |
| Export               | suspected event markers    | thresholds / NaN  |
+----------------------+----------------------------+-------------------+
| Evidence, metadata, optional evaluation | Warnings / missing assets     |
+-----------------------------------------------------------------------+
```

**View A — Mission & replay:** authoritative run ID, seed, scenario bounds, simulation clock `t_s`, replay status, elapsed *simulation* time vs measured wall-clock if shown, method name, and supported modules. Controls: Load actual run, Play, Pause, Step, Seek/slider, Reset, selectable replay rate (documented units), Export. A "Start Mission" label must be **"Play Simulation"** until MG-015 generates actual simulation runs from user configuration.

**View B — Navigation:** fixed ENU x east [m], y north [m] with correct axis orientation and aspect ratio, legal bounds and exclusions, planned waypoints/route, actual virtual pose trace and current marker. Coverage comes from MG-005 `computeCoverage` or committed run metadata; it must not be inferred from visual path colour alone. Virtual lat/lon display only if provided/finite; otherwise **"Virtual GPS unavailable"**. A heading/altitude label must be ENU datum altitude, not necessarily ground clearance. For 3-D optional view show that it is kinematic simulation.

**View C — Sensor readings:** thermal time curve labelled K (optional explicit °C conversion shown only in UI); EM `response_norm` time curve labelled dimensionless; validity bars/markers and `invalid_reason` tooltips/detail table. Individual modality can be absent; do not silently overlay EM against a kelvin axis or synthesize values. Threshold overlays require a declared matching score/feature transformation; a detector score threshold is not automatically a raw temperature/EM threshold.

**View D — Suspected anomalies:** predicted `DetectionEvent` list and map markers with `status="SUSPECTED"`, event ID, timestamp, estimated ENU coordinates and optional uncertainty. If `confidence_0_1` is NaN say **"Uncalibrated / unavailable"**; even numeric values require an explicit calibration provenance before display as probability; otherwise label **"Model score"**. No truth overlay in normal replay. For zero events say **"No suspected events in this simulated run"**, never "all clear".

**View E — Evaluation & comparison (conditional):** only if `result` is available, show scenario/split and clearly state **cell-level evaluable-cell** TP/FP/TN/FN and derived ratios from MG-008. Display scored/excluded cell counts when metadata supplies them, and NaN ratios as **"Undefined (zero denominator)"**. Event-target localization error may be shown as a separate evaluation-only aggregate (no target coordinates or matches imported). Thermal-only, EM-only, OR, AND and weighted comparisons require **actual same-scenario held-out runs** with clearly marked method/seeds; PPO comparison is disabled/NOT RUN until MG-013/MG-019 exist and satisfy fairness. Do not turn missing method rows into 0% or display a demo bar based on invented numbers.

**View F — Evidence / export:** export redacted `PoseSample`, `SensorSample`, `DetectionEvent` tables, permitted summary and screenshot to a **user-selected, writable destination**. Record exact file names, column names, number of rows, scenario ID, MATLAB release, git SHA, model/sensor versions, split ID and run ID where available; unknown fields are `NOT_RECORDED`. Use UTC for real export creation time explicitly separate from synthetic `t_s`. If the event table is genuinely empty, export zero rows with column headers and a labelled "no suspected events" summary. Failed export never reports success.

## 4. Playback state machine and callback policy

| Current | Action | New state | Observable behaviour |
|---|---|---|---|
| IDLE | load validated run | READY | Show first frame and metadata; no invented event/metrics |
| IDLE/FAILED | play | unchanged | Disabled until valid data |
| READY/PAUSED | play | RUNNING | Cursor begins/resumes from saved `t_s`; never edits data |
| RUNNING | pause | PAUSED | All displays stop advancing, cursor preserved |
| READY/PAUSED | step | PAUSED | Advance to next valid pose time, exactly one replay step |
| READY/RUNNING/PAUSED/COMPLETE | seek | PAUSED | Reconstruct view **deterministically** through selected `t_s`, no stale future events |
| Any loaded | reset | READY | Rewind to initial cursor; do not resample noise or create new scenario |
| RUNNING | end of data | COMPLETE | Show final frame, accurate summary, no additional synthetic events |
| RUNNING/any loaded | malformed record / unrecoverable UI failure | FAILED | Actionable error without silently declaring completion |
| Any | close | CLOSED | Stop timer/callbacks, detach resources, no later writes |

**Pause/seek details:** a paused cursor must not drift; events only appear at/earlier than current `t_s` (tie ordering deterministic). Seeking backward removes future event markers/samples from visible **current** traces; the complete run remains accessible separately with clearly titled "Full Run" view. Step means one stored pose time, **not** wall-clock 1 second. Reset does not regenerate random streams.

**Implementation guidance backed by current MATLAB docs:** `uifigure` + `uiaxes` are available in the target release. Precompute model arrays, decimate only **plot rendering**, reuse graphic handles, and throttle playback redraws with `drawnow limitrate` where appropriate, which can skip UI frames but must not skip simulation records or event logging. Keep callbacks responsive; `drawnow limitrate nocallbacks` is **not** the normal interactive playback option because it defers user callbacks. For callback reentrancy, guard current play state / owner of a single active playback update mechanism. Timers (if used) must be stopped/deleted on app close or reset.

**Performance:** no promised FPS, 20 Hz UI or instantaneous launch without measurement. Test a small fixture and a long replay, record update cadence, pause responsiveness and maximum input row count on the actual R2026b Windows setup. The underlying `PoseSample`, samples and events must remain complete even if UI decimates display. Prefer 2-D graphics first.

**MATLAB official docs (checked for R2026b on 2026-10-31):**
- `uiaxes` (UI figure axes): https://www.mathworks.com/help/matlab/ref/uiaxes.html
- `drawnow limitrate` and callbacks: https://www.mathworks.com/help/matlab/ref/drawnow.html
- `exportapp(fig, filename)` saves UIFigure/App Designer snapshots as PNG/JPEG/TIFF/PDF (not MAT/CSV): https://www.mathworks.com/help/matlab/ref/exportapp.html
- App performance advice: https://www.mathworks.com/help/matlab/creating_guis/improve-app-performance.html

For data export use MATLAB table/struct persistence tools (`writetable` for CSV, `save` for MAT) and preserve schema. PNG snapshots via `exportapp` capture UI; `exportgraphics` can capture plots. None of these functions alone proves screenshot/report reproducibility—read files back in acceptance tests.

## 5. Validation and failures the user must actually see

- Invalid `runBundle` schema/ID/seed/time/pose/sample references: refuse to replay; show `Invalid run bundle` and reason. A missing required table cannot be silently replaced with made-up rows.
- Real empty run: remain valid, show no recorded pose/no events, disable Play/Step/Seek; state READY or explicit EMPTY (UI label), not COMPLETE with fictitious metrics.
- Invalid thermal and EM samples: show gaps and `invalid_reason`; both-invalid is **unavailable**, not 0 or "target absent".
- EM beyond model cutoff is `MODEL_OUT_OF_DOMAIN`, not a zero coil reading. Distinguish sensor not licensed/configured vs sensor values below a chosen threshold.
- If geotags are NaN/missing, still show ENU positions and label virtual GPS unavailable; do not use a physical online map or claim GPS fix.
- Missing `ExperimentResult`, `split_id`, PPO checkpoint, or calibrated confidence: corresponding panels are **NOT RUN / NOT RECORDED**, not an aggregate guessed from a painted map.
- Export dialog cancelled/unwritable destination: no files changed; show cancelled/error status. An interrupted write must not leave a claimed successful partial export; use temp files where practical.
- UI launch in headless CI/without display: explicit SKIPPED/UNAVAILABLE; do not call a noninteractive test proof of rendered UI.
- Unsupported platform or renderer: show 2-D fallback or document NOT TESTED; no fabricated 3-D visual evidence.
- Buttons/actions do not invoke UAV/RC telemetry, internet data streaming or minefield handling.

## 6. MG-011 acceptance-test matrix (tests specified here, NOT executed)

Rahil must produce real MATLAB R2026b `matlab.unittest` or UI testing evidence for all cases. Use at least one seeded actual MG-004/005/007/009 replay bundle assembled by an **observables-only adapter**, plus controlled invalid fixtures, not manually fabricated "passed" screens.

| ID | Test | Required pass evidence |
|---|---|---|
| UI-01 | Launch from real redacted, nonempty `runBundle` | Frozen `openMissionApp(runBundle)` works; visible persistent simulation banner; scenario/seed shown correctly |
| UI-02 | Strict input schema & mismatch | Invalid/missing `schema_version`, scenario ID, duplicated IDs, monotonic timestamps, pose/sample link mismatch give actionable error |
| UI-03 | Privacy firewall | Recursive restricted-field injection in nested struct/cell/table rejected; no truth labels/coordinates in UI callbacks, events or export |
| UI-04 | Mission replay controls | READY→RUNNING→PAUSED→READY/COMPLETE; play/pause/resume/step/reset/seek exact time cursor and valid button states |
| UI-05 | Backward seek | Current-view trace/events never retain later timestamps; returning forward deterministically recreates the same view |
| UI-06 | Map and boundaries | Route/pose/exclusion polygons in correct ENU metre axes; waypoint/altitude/coverage values match MG-005 output |
| UI-07 | Virtual GPS missing/present | Finite synthetic reference geotags labelled VIRTUAL; missing NaN values show UNAVAILABLE, no real GPS fix |
| UI-08 | Thermal/EM units | Thermal Kelvin vs normalized EM displayed with separate axes/units, no unit-mixing or implicit °C conversion |
| UI-09 | Sensor invalids and dropouts | Dropped/out-of-domain readings show gaps, NaN and reason; never convert invalid to 0 or false negative |
| UI-10 | Suspected events | Only actual valid MG-009 `DetectionEvent` markers; correct time/estimated coordinates; status `SUSPECTED`; no truth coordinates |
| UI-11 | Empty field and empty events | Correct no-events text and zero-row table, without "safe" or "cleared" |
| UI-12 | Missing results/undefined metrics | Missing score shows NOT RUN; NaN precision/F1/FPR show undefined; cell metrics separated from localization metric |
| UI-13 | Model score vs probability | Uncalibrated numeric score labelled model score; NaN unavailable; never claim real-device likelihood |
| UI-14 | Comparison feature gate | PPO absent -> NOT RUN; no invented PPO result; actual baseline comparison only under same held-out run conditions |
| UI-15 | Export completeness and redaction | CSV/MAT/PNG (or documented PNG-only UI snapshot + required data formats) written, reopened/verified: exact row counts/columns/seed/SHA; no secret/truth |
| UI-16 | Export failure and cancellation | Unwritable path/cancel produce no false success; app remains interactive |
| UI-17 | Long replay responsiveness | Record actual tested row count, UI redraw cadence, measured pause response/CPU; no frozen UI and no lost underlying sample/event rows |
| UI-18 | Close/reset lifecycle and portability | No residual timers or callbacks; MATLAB Windows screenshots/logs collected; macOS marked NOT TESTED until independently executed |
| UI-19 | Simulated-only controls | "Play Simulation" cannot arm/command hardware; source/GUI audit detects no operational real UAV/telemetry use |
| UI-20 | Deterministic replay & provenance | Opening same redacted run twice reproduces frame/events; displayed split/model/version/seed/git SHA are from run metadata or NOT_RECORDED |

**Minimum MG-011 submission:** implementation file(s) and exact launch command, documented actual runBundle adapter, redaction/input-validation tests, 2-D UI screenshots captured from running MATLAB, full UI-01..UI-20 executed or explicitly marked BLOCKED with reason, Windows R2026b MATLAB release/toolbox log, example redacted exports that can be reopened, run provenance, measured UI responsiveness, limitations and `tasks/evidence/MG-011.md`. Preserve independent human review and GitHub Task Gate. Do not report an unexecuted UI test as PASS.

## 7. Objective mapping and scientific limits

| Original objective | MG-010 UI requirement | Evidence/limit |
|---|---|---|
| O1 autonomous planned survey | Waypoints, pose trajectory, coverage/time and simulated replay state | Map displays MG-005 synthetic kinematic survey, not physical autonomy |
| O2 subsurface detection by coil/thermal fusion | Two sensor traces, validity, threshold annotation, suspected-event list | No real mine detection, even if simulated F1 is high |
| O3 GPS geotag/GCS | ENU and optionally virtual geotags, event estimated coordinates, exports | Virtual time/coordinates; no live field GCS or GPS performance |
| O4 reduced exposure | Remote virtual observation story, persistent simulation caveat | No demonstrated real-world safety improvement |

Related: [DASHBOARD.md](DASHBOARD.md), [ACCEPTANCE_MATRIX.md](ACCEPTANCE_MATRIX.md), [MG008_FUSION_DATASET_AND_METRICS.md](MG008_FUSION_DATASET_AND_METRICS.md), [QUALITY_GATES.md](QUALITY_GATES.md), [SECURITY_ETHICS_AND_PUBLICATION.md](SECURITY_ETHICS_AND_PUBLICATION.md).

**MG-010 definition of DONE:** the design, unambiguous redaction boundary, screen/state contracts and UI-01..UI-20 acceptance criteria have been reviewed and merged with evidence on protected main. No UI implementation or actual MATLAB screenshots are required for this documentation task—those belong to MG-011.
