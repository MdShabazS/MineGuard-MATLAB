# Mission Control App — MG-010 Acceptance Index

**Canonical implementation-facing design:** [MG010_MISSION_DASHBOARD_SPEC.md](MG010_MISSION_DASHBOARD_SPEC.md).
This index retains original requirements but defers exact UI behaviour, the observables-only run-bundle adapter, state machine, export constraints and **UI-01…UI-20** tests to the canonical specification.

**Technology:** MATLAB App Designer (`.mlapp`) or source-backed `uifigure` fallback. The entrypoint remains the MG-003 frozen `mineguard.app.openMissionApp(runBundle)`. The first **MG-011** implementation is a *local 2-D synthetic replay* of actual recorded MATLAB outputs, **not** a physical drone controller, web application, or integrated mission generator. End-to-end simulation orchestration belongs to MG-015.

## Required views

- **Mission / replay**: run identity, seed, method, simulation clock and play/pause/seek/step/reset with explicit READY/RUNNING/PAUSED/COMPLETE/FAILED states; generate-run controls are unavailable until implemented and tested.
- **Navigation**: ENU [m] route, exclusion zones, actual virtual UAV poses, waypoint time, coverage from MG-005, optional virtual (never measured) geotags.
- **Sensor readings**: actual MG-007 `temperature_K` and `response_norm`, per-sample validity/reason; show NaN/invalid as unavailable rather than zero.
- **Suspected map**: MG-009 `DetectionEvent` estimates with `status="SUSPECTED"`, time, optional model score and uncertainty; **never** display ground-truth target coordinates during inference.
- **Evaluation and comparison (conditional)**: MG-008 evaluator-only **aggregate** cell-unit metrics, explicit undefined denominators, scenario/split. PPO panels disabled or labelled NOT RUN until real results exist.
- **Evidence**: redacted CSV/MAT run tables and actual app/axes PNG snapshot, version/seed/SHA/provenance, failure handling. No fake screenshots or copied hidden truth.

**Display banner on every primary view and export:** `SIMULATION — synthetic data; not validated for real mine detection or clearance.`

**What MG-010 does not prove:** No App Designer application has been built, rendered, performance-tested or run by this DOC task. Rahil must implement/test the UI-01…UI-20 cases under MG-011 with MATLAB R2026b evidence. It cannot start until MG-005, MG-009 and MG-010 are DONE on `main`.
