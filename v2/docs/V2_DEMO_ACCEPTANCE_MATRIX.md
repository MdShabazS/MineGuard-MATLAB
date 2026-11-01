# MineGuard Advanced V2 — Final Demonstration Acceptance Matrix (V2-001)

**Owner:** Shabaz · **Date:** 2026-11-01 IST · **Revision:** 1.0  
**Scope:** contractual requirements and future test plan, **not** an executed V2 MATLAB regression.  
**Basis:** V2_SYSTEM_REQUIREMENTS.md, V2_TECHNICAL_ARCHITECTURE.md.

## 1. Acceptance levels

- **MUST** = mandatory for V2-010 demonstration signoff. If impossible on macOS, document failing evidence and formally revise scope with Shabaz and guide; do not silently mark PASS.
- **SHOULD** = quality target; optimize based on measured results, record limitations.
- **OPTIONAL** = research or presentation enhancement, without holding up safety/engineering core.
- Tester must report **PASS / FAIL / NOT RUN / NOT APPLICABLE**, with Git SHA, MATLAB version, toolbox list, seed, host details, commands, console output, screenshot/video paths and responsible member.
- The guide can see the full demonstration without an internet connection; no drone or peripheral attached.
- **Simulation truth**, **model estimates**, and **independent evaluation** are separately labeled. Human safety and mine clearance are NEVER inferred from this demonstration.

## 2. Feature acceptance matrix

| Test ID | Requirement & method | Pass criterion | Responsible task |
|---|---|---|---|
| AC-001 | Start a seeded scene from one application entry point | UI reaches PREFLIGHT then mission state sequence without source-file editing or separate manual figure setup; run ID & seed visible | V2-002, V2-007 |
| AC-002 | Full autonomous virtual flight | Takes off from terrain, reaches configured AGL, follows legal survey region, returns to designated home, lands; COMPLETE only after landing; no unexplained jump | V2-002 |
| AC-003 | Genuine evolving simulation | Position/control/sensors computed on successive clock ticks, not a pre-generated playback masquerading as LIVE; pause freezes simulation time and emissions | V2-002, V2-005 |
| AC-004 | Physical plausibility of motion | Positions/velocities/altitude continuous under configured speed/acceleration limits; nonzero yaw/attitude changes during turns; logged violations = 0 on nominal case | V2-002 |
| AC-005 | 3-D live scene | Visible correctly scaled and oriented quadcopter above terrain; terrain features visible; follow and free-orbit viewpoints work with no lost aircraft | V2-003 |
| AC-006 | Map initialization | Local offline map shows survey boundary, home, planned route, pose/heading and virtual coordinates before launch | V2-006, V2-007 |
| AC-007 | Map synchronization | 3-D and map positions agree after frame conversion within 0.5 m for a synthetic surveyed landmark; sensor footprints attach to correctly timestamped poses | V2-006, V2-008 |
| AC-008 | Coverage integrity | Planned, traversed, sensor-valid, sensor-invalid and unobserved cells distinct; 100% route coverage cannot imply detector accuracy or safe land | V2-006 |
| AC-009 | Offline / satellite-style map | Mission runs fully offline with local base map; if online satellite imagery cannot load, the actual live map remains operational and indicates offline fallback | V2-006, V2-007 |
| AC-010 | RGB moving frames | View is a time-varying generated aerial image of the same terrain/objects; screenshot sequence and projected landmark pose show geometry alignment; no unrelated stock video | V2-003, V2-005 |
| AC-011 | Thermal moving frames | View is colorized from numeric Kelvin array with correct temperature legend; palette switch leaves Kelvin samples unchanged; frame timestamp and FOV shown | V2-004, V2-005 |
| AC-012 | LiDAR moving frames | Sample point cloud/ground height corresponds to virtual terrain geometry and pose; example geometry test within documented numerical tolerance, invalid samples explicitly marked | V2-005 |
| AC-013 | Sensor clock agreement | SensorSample t_s equals the trajectory/pose timestamp associated with pose_id to within one simulation tick; late/invalid frames stay labelled and do not gain false timestamps | V2-005, V2-008 |
| AC-014 | Environmental stress | Day/low contrast, noise or dropout scenario changes sensor validity/observations at fixed seed; this is shown without claimed mine detection | V2-004, V2-005 |
| AC-015 | Suspected event | A synthetic test scenario generates at least one **SUSPECTED** event through detector computation on observations; map marker uses estimated location, never truth coordinates | V2-006 |
| AC-016 | Event evidence inspector | Clicking an event shows time, sensors used, numeric score with "uncalibrated", RGB/thermal observations if available, estimated map location and quality/invalid info | V2-006, V2-007 |
| AC-017 | Truth firewall | Code-level negative tests prevent detector, navigation, app and exports from receiving TargetTruth / buried-target identity or coordinates; separate evaluator only | V2-004, V2-006, V2-008 |
| AC-018 | Mission controls | Start, pause, resume, abort, replay, reset and export are enabled only when appropriate; no duplicate timers, cursor drift, random reseeding or app freeze | V2-007, V2-008 |
| AC-019 | Export round-trip | Run manifest, telemetry, metadata, sample refs, events, coordinate frame and provenance read back with same data/hash; private truth excluded; failure does not report success | V2-008 |
| AC-020 | No false scientific certainty | Explicit SIMULATION and SUSPECTED labels; V1 sealed weighted TP 0/FP 26/TN 470/FN 4 retained as historical baseline, not overwritten by V2 fixture | V2-009 |
| AC-021 | Negative controls and errors | At least 1 target-absent scenario, 1 sensor-dropout case, 1 camera/LiDAR invalid ray case and 1 mission fault clearly reported; reproducible seeds | V2-004, V2-008 |
| AC-022 | Guide-ready end-to-end run | Shabaz personally reviews full simulation from start through report with all three sensor windows and map visible on user's Mac; signoff recorded | V2-009, V2-010 |
| AC-023 | Academic objective trace | Final engineering report retains original four Phase-1 objective wordings unchanged, marks only simulated contributions as accomplished, and names unachieved real-world goals | V2-009, V2-010 |
| AC-024 | Native macOS compatibility | All MUST tasks execute on user's MATLAB R2026b+UAV Toolbox Mac, including a rebooted/clean checkout, with actual command/log evidence | V2-008 |
| AC-025 | Performance observation | Actual wall time, simulation time, 3-D refresh and RGB/thermal/LiDAR update rates recorded; target usability checked, not assumed | V2-008 |

## 3. Quantitative initial *targets*, not measured results

| Metric | Provisional target | Evidence / adjustment policy |
|---|---|---|
| Simulation integration | nominal fixed dt = 0.05 s / 20 Hz | No missed or duplicated time steps; adjust based on benchmark and keep accurate provenance |
| Scene refresh | aim >= 10 FPS; stretch goal 15–20 FPS | Report measured median, 5th percentile and frame stalls on Mac |
| Operator telemetry/map | ~5–10 updates/s while active | Show timestamp and stale warning if behind |
| RGB frame | target 320×240 minimum, >= 2 fresh generated FPS | Preferred 640×360 at >=5 FPS if viable; report source model and actual rate |
| Thermal frame | target 160×120 numeric Kelvin, >=2 FPS | Include scale and numeric data, not cosmetic color only |
| LiDAR | target >=1 scan/s, 2 scans/s preferred | Ground-referenced point/range output and explicit invalidity |
| 1× presentation | 60 simulated seconds should take <= 75 wall seconds on measured host with configured "demo quality" | Requirement subject to honest benchmark; if not achieved, optimize, document and seek review rather than fake real-time |
| Geometric match | ENU/NED round-trip <=1e-8 m; map/3-D landmark localization <=0.5 m | Unit tests with random asymmetric points + selected corner cases |
| Sensor clock | at most one dt tolerance to pose_id sample t_s | Exact tick matching preferred |
| Determinism | Same seed/config/version produces same trajectories, event IDs and numeric samples, within documented floating-point tolerance | Compare serialized outputs in repeated runs |
| Out-of-domain behavior | Missing/invalid measurement remains NaN or absent with explicit reason | No silent zero-fill / synthetic "100% accurate" callout |

These are engineering design targets, **not passed benchmarks or scientific sensitivity results**. V2-003 and V2-005 must provide performance and fidelity tradeoff evidence before an acceptance revision can be requested.

## 4. Demonstration script outline (final V2-010 refines)

| Moment | Action | Guide should observe |
|---|---|---|
| Preflight | Choose "Training Field — Synthetic", seed and altitude, inspect mission map and sensor availability | Full plan, virtual home, measurement labels and sample rates |
| Takeoff | Press START SIMULATION | Drone rotates/ascends; virtual clock and AGL update |
| Survey | Follow camera, glance at live map | Drone moves and turns; footprint and observed coverage grow as sensor samples are taken |
| Multisensor | Expand RGB then thermal then LiDAR | All views show same changing location and scene with different physical modalities |
| Observation | Visit deliberately ambiguous surface clutter + synthetic anomaly | Suspected event appears only from model output; not always a correct detection |
| Inspect | Click map event | Matching captured frames, score, quality flag, estimated position and time |
| Conditions | Toggle low-contrast or dropout scenario in a separate seeded run | Some sensing invalid or anomalies missed; no silent accuracy inflation |
| Return | Let planned survey finish | Drone returns, descends, lands and mission status COMPLETE |
| Report | Export simulation package and review summary | Route distance, coverage vs usable coverage, event evidence, errors and limitations |
| Science | Open separate evaluation report | V1 frozen negative held-out result clearly distinguishable from V2 synthetic fixtures |

**Presentation boundary:** this is a humanitarian research/academic simulator. No operational military validation, weapon targeting, certified detection, demining clearance or safety certificate.

## 5. Proof required before any task goes DONE

For each BUILD task, commit **v2/evidence/V2-XXX.md**, with:

- Task: V2-XXX
- Owner: Rahil
- Tester: actual human tester
- Environment: OS, MATLAB version, UAV Toolbox and installed dependencies
- Command: exact MATLAB test commands used
- Observed output: actual results and screenshots or logs, distinguishing screenshot from expected concept
- Result: PASS only for tested cases; otherwise FAIL / NOT RUN
- Research: source URLs, code/algorithm basis
- Commit SHA; seed, scenario ID; relevant exports
- Known failures and limitations

For DOC tasks, owner Shabaz must commit a substantive evidence file with task identifier, date, source-backed decisions, reviewed artifacts and acknowledgement that text alone does not establish simulation execution.

CI Node tests and the guide portal only check governance and web/JavaScript, not licensed MATLAB. Final V2-010 acceptance requires a guide-facing run and Shabaz's actual review. Passing this architecture document **does not** mark future implementation tasks as complete.

## 6. Safeguards against a misleading V1-style "100%"

- The guide portal displays V1 and V2 independently; a percentage is task status, not algorithm accuracy.
- Every core sensor and map requirement has a visible GUI acceptance case above. If a promised sensor view is missing, V2-010 is not complete even if a task was marked DONE.
- New detector studies must be pre-registered and evaluated on fresh held-out synthetic groups, not the consumed V1 TEST. A confidence score is not a probability without calibration.
- Real hardware, physical detection performance and clearance are out of this phase and cannot be inferred.
- Scientific limitation text remains in all exported guide-facing materials.
