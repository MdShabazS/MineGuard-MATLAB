# MG-001 Research Plan — Frozen Scope, Evidence and Handoff

**Status:** researched and proposed 2026-10-31; this is a simulation design, not executed detection evidence. **Owner:** Shabaz. **Original source:** `Review1Phase1.pptx`, verified in `SOURCE_VERIFICATION.md`.

## Research question

Can a reproducible, parameter-constrained MATLAB/Simulink experiment demonstrate autonomous grid surveying, separate simulated thermal and electromagnetic responses, evidence-grounded fusion, virtual geotagging and remote visualization of **suspected** subsurface-related anomalies? Which conditions make an airborne sensor incapable of detecting a target, and how much does an optional PPO survey strategy alter coverage, time and false alarms compared with a fixed grid?

This is **not** a claim that a physical UAV can certify a field safe or identify actual explosives.

## Source and objective traceability

| Frozen Phase-1 objective | Simulation deliverable | Acceptance/evidence boundary | Follow-up task |
|---|---|---|---|
| O1: autonomous pre-programmed flight | Seeded field + bounded fixed-grid route, virtual pose and navigation log | Deterministic route coverage/time and waypoint-boundary tests; not a real aircraft flight | MG-004, MG-005 |
| O2: metal coil and thermal fusion, accurate subsurface detection | Depth/standoff-limited synthetic thermal + EM signals; clutter/noise; late fusion | Sweep burial depth, flight height, soil/time parameters; held-out confusion matrix and negative controls; not field accuracy | MG-006–MG-009 |
| O3: GPS geotags and real-time GCS | Timestamped synthetic coordinates, estimated anomaly map, App Designer controls | Reproducible mapping/export with clearly virtual GPS reference and latency measured in an actual MATLAB run | MG-010, MG-011 |
| O4: eliminate human exposure | Demonstrate an operator-free **virtual** survey run | Video/log of simulated autonomous mission and explicit unvalidated real-world safety note | MG-015–MG-018 |

Original wording is authoritative only in `PHASE1_BASELINE.md`; this table operationalizes it and does not replace it.

## Sequential methods and go/no-go tests

**P0 — Source and scientific guardrails (MG-001, this task):** Verify original slide text and document real literature. Mark historical slide-5 author labels as unverified. No unverifiable performance thresholds.

**P1 — Freeze data contracts (MG-003, after MG-001 and MG-002):** Define one configuration record with seed, area dimensions [m], time step [s], coordinates [m] and virtual latitude/longitude [deg], target depth [m], vehicle altitude [m], thermal measurement [K or °C, explicitly chosen], EM response [specified proxy unit and sensitivity model], validity/missing-sample indicators, separated truth and observation fields. Specify scenario/telemetry/detection/export schemas and tests before Rahil implements the generator.

**P2 — Deterministic baseline (MG-004, MG-005):** Seeded scenario/ground-truth generator and conventional lawnmower route. Run same seed/config twice; assert identical truth, legal waypoints, monotonic time and bounded coverage.

**P3 — Physical sensitivity and fusion (MG-006–MG-009):** Fix only documented parameter ranges; impose altitude/standoff-dependent attenuation, nonmetallic EM null controls, thermal confounders, additive noise and dropouts. Create labelled *simulated* tests with scenario-disjoint training/validation/held-out seeds. Report thermal-only, EM-only, fusion and naive baseline under matched conditions; do not let detector access hidden truth.

**P4 — Guide-facing demo (MG-010, MG-011, MG-014, MG-015):** MATLAB App Designer mission control with simulation banner, GPS-like tag/map, sensor trace, suspected anomaly markers and evidence exports. Produce real MATLAB run logs, configuration, Git SHA, seed, MATLAB release/toolboxes and captured outputs; avoid mock screenshots.

**P5 — Optional PPO research (MG-012, MG-013, MG-019):** Only after stable fixed-grid baseline. Policy chooses admissible survey cells from observations, never hidden target labels. Compare identical scenario seeds, coverage/time budgets, collision constraints and uncertainty; provide multiple seeds and explicit underperformance if present. PPO is **not** a prerequisite for core integration.

**P6 — External validity and report (MG-016–MG-018):** Review held-out MATLAB execution evidence. Clearly distinguish synthetic test metrics from real landmine detection; report limits and next steps for safe inert-target validation only, not minefield deployment.

## Published evidence and bounds on claims

- Forero-Ramírez et al. (2021), *Engineering Proceedings* 8(1), 25, https://doi.org/10.3390/engproc2021008025 — reports performance on particular UAV thermal image acquisitions; not interchangeable with simulation or general buried-mine sensitivity.
- *Detection of anti-personnel mines of the “leg breakers” type by analyzing thermographic images captured from a drone at different heights*, *Infrared Physics & Technology* 142 (2024), 105567, https://doi.org/10.1016/j.infrared.2024.105567 — real test images at 1–5 m; near-surface and acquisition-height constraints.
- Hu et al. (2024), *International Journal of Thermal Sciences* 205, 109282, https://doi.org/10.1016/j.ijthermalsci.2024.109282 — soil moisture/heat transport complicates an IR-only physical model.
- *A Comparative Evaluation of UAV-Based Remote Sensing and Geophysical Techniques for Landmine Detection on a Seeded Minefield*, *Remote Sensing* 18(13) (2026), 2182, https://www.mdpi.com/2072-4292/18/13/2182 — source-specific comparison of UAV imaging with ground-based methods; not a licence to assume airborne coil success at arbitrary height.
- MathWorks R2026b UAV Scenario Simulation, https://www.mathworks.com/help/uav/scenario-simulation.html — supports UAV environment/trajectory/sensor simulation, **not** automatic buried-mine physics.

Reference titles/DOIs and claims were checked against the public publisher pages on 2026-10-31. More detail: `LITERATURE_REVIEW.md`.

## Data rights and experimental controls

- Begin with team-generated synthetic data: store source model, seeds, parameters and train/validation/test split IDs, not arbitrary image files.
- Candidate public datasets: Forero-Ramírez Mendeley DOI `10.17632/732ngnf4r3.1`; Demining Research Community Zenodo DOI `10.5281/zenodo.19100554`. **No data imported.** Confirm exact reuse/licence, modality alignment, sample counts and georeferencing before downloading or training. Handheld EMI and aerial thermal readings may not be temporally paired.
- No actual minefield coordinates, student identifiers, hardware secrets or unlicensed third-party material in public GitHub.
- Accuracy cannot be promised in advance. Report precision, recall, false-positive rate, false-negative rate, coverage, runtime, location error and failure cases with denominator/sample size and scenario conditions.

## Release blockers and evidence discipline

- Unknown physically defensible EM response constants and thermal parameters: record assumptions, stress-test plausible ranges and report negative results; do not invent measurements.
- MG-002 local toolboxes/MCP verified in Rahil's PR evidence, but its DONE status counts only after merge to `main`.
- All engineering acceptance relies on **actual MATLAB execution**; Node `task-gate` is a governance check only.
- Main project target: **02 November 2026**. Deliver a validated end-to-end fixed-grid baseline before optional PPO if schedule becomes constrained, documenting any unbuilt features instead of changing original objectives.

## Ready-to-hand-off

This document and `REQUIREMENTS.md`, `DATA_CONTRACTS.md`, `ACCEPTANCE_MATRIX.md`, `PHYSICS_AND_FEASIBILITY.md` guide MG-003's interface freeze. `MG-004` must not start until MG-003 DONE on `main`.
