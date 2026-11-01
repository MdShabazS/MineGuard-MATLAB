# V2-004 — Detection Limits, Synthetic Experiments and Evaluation Protocol

**Owner:** Shabaz + ChatGPT | **Date:** 2026-11-01 | **Status:** Prespecified design ONLY; no V2 inference model, trial, or held-out test executed.  
**Contract:** mg-v2-sensors/1.0 (V2_004_SENSOR_CONTRACTS.md).  
**Scope:** distinguish physically plausible sensor/geometry behavior, synthetic scenario generation, anomaly-flag generation and independent *quantitative evaluation*.

## 1. What is actually being claimed

V2 can demonstrate autonomous *virtual surveying*, GPS-like location logging, sensor-field simulation, mapping and **synthetic suspected-anomaly** decisions. It cannot conclude that a particular surface pattern is a real buried landmine, that the observed field is safe, or that virtual thermal/EM/LiDAR predictions have real-world generalization.

**Frozen V1 research result remains visible:** once-only consumed held-out synthetic TEST for weighted fusion had **TP 0, FP 26, TN 470, FN 4**; sensitivity 0/4 in that sample. Attractive V1 S0 demonstration TP1 FP4 TN395 FN0 is a *display fixture*, never held-out test performance. PPO has no validated performance advantage in the relevant feasible comparisons. These are V1 historic metrics, not a V2 baseline that we can re-evaluate on the consumed test.

The V2 public display must say **SIMULATED / SYNTHETIC / SUSPECTED**; confidence score is **uncalibrated model score** unless independent calibration has actually occurred. "Observed/covered" = camera/sensor evidence acquisition, **not land release or cleared ground**. Real land release has independent legal/process requirements per IMAS 07.11.

## 2. Independent research questions and falsifiable hypotheses

| Study | Research question / hypothesis to test | Null / failure that must remain possible |
|---|---|---|
| G1 — geometrical correctness | RGB and thermal scene landmarks map into consistent ENU coordinates under known camera pose | Camera optical axis, rotation or mirror errors break landmark agreement |
| G2 — thermal model validity | Environmental controls change Kelvin field or radiance proxy in the declared deterministic direction, within synthetic model assumptions | Low contrast and emissivity mismatch produce overlap, wrong sign or no detectable signal |
| G3 — lidar scene integrity | LiDAR ranges agree with ray–shared-mesh intersections for valid returns | No-hit, occlusion, tilt and range clipping expose invalid samples |
| G4 — anomaly false positives | Clutter-only scenarios may trigger model-based suspected events | The detector cannot distinguish all dry rocks / sun-warmed soil from hypothetical features |
| G5 — generalization | Threshold selected on TRAIN/VAL preserves utility across *unseen* scene families | Performance collapses on novel lighting/soil/scene geography |
| G6 — fusion advantage (exploratory) | Properly aligned multimodal features might outperform fixed RGB-only or thermal-only baseline on new held-out synthetic scenes | Naïve fusion increases false positives; no positive result expected or guaranteed |
| G7 — missing modalities | Explicitly missing thermal/LiDAR samples reduce observation quality and possibly suppress events | False full-confidence outputs under dropout must fail |
| G8 — time and pose consistency | Sensor observations and anomaly marker locations refer to the exact tick/pose that generated them | Timestamp reuse or map-camera mismatch yields false geolocation |
| G9 — counterfactual truth isolation | Changing only hidden truth *without changing the observable forward response* cannot change detector output | If detector changes, hidden label or metadata leaked |

These questions are test plans, not results. Do not predeclare a favorable conclusion or "achieved >95%" threshold.

## 3. Data partitions: pre-register BEFORE training/model tuning

### 3.1 Scenario-level split unit

Use **scene family/terrain tile + environmental scenario + source capture group** as the grouping key, not individual frame or random pixel. Adjacent drone frames are highly correlated and may contain the same visible clutter; per-frame random split leaks spatial/temporal context. Scenes derived from the same seed, texture patch, object layout, thermogram or geometry model must remain in the same group.

- TRAIN: initial suggested 60% of **scenario groups**. Choose feature forms, any supervised model and learned parameters here.
- VALIDATION: suggested 20% of mutually exclusive scenario groups. Choose thresholds/calibration, hyperparameters and policy, with tuning log.
- NEW HELD-OUT TEST: final suggested 20% of mutually exclusive scenario groups, disjoint by seed/terrain/texture/environment (and any recorded-source session). Select split manifests and hash them **before** algorithmic optimization. TEST usable once after implementation freeze and review; no tune → retest loop.
- Report actual **counts of scene groups, frames, cells and positive/negative labels**. If a split contains zero positives, sensitivity is **undefined**, not 100% and not zero by default.
- Synthetic and external recorded research imagery are **distinct domains and reports**. Never combine scores without explaining dataset identity/ground-truth limitations. Public datasets are optional reference data, not proof the simulated drone recorded real measurements.

### 3.2 Positive/negative and nuisance balance

Define ground-truth targets *privately* only in scenario generator/evaluator. New case groups:
- target-present with **visible surface perturbation** (document that this can be perceptible from RGB);
- target-present but **no visible/thermal surface perturbation**, to show model blind spots (buried, occluded, low contrast);
- target-absent visually confusing rocks, metal-colored scrap, wet patches, vegetation, shadow and exposed soil;
- target-absent thermal anomalies with emissivity/sunlight variation;
- terrain-only with no targets and no artificial hotspot;
- low-contrast dawn/dusk and environmental changes;
- dropout/no-hit/tilted camera and non-nadir geometric distortions;
- out-of-distribution material, textures and terrains.

Ensure positive-looking clues are not universal or perfectly label-correlated in synthetic training. Prefer independent randomization of nuisance factors; ablate hidden label influence by suppressing response while keeping truth for counterfactual tests. Otherwise the simulator teaches a classifier its own invented visual rule, not operational detection.

### 3.3 Randomization, provenance and review lock

Derive independent deterministic streams by (master_seed, scenario_id, sensor_id, submodule); store actual seed derivation version and code hash. Split IDs and scenario metadata must be fixed prior to training. Protect held-out output against overwrite; hash split manifest and test run manifest. Evaluator runs on private truth only after the public detector output file and model/threshold parameters are frozen.

No code should contact the V1 test-run lock; V2 tests are **new** and use separate namespace, seeds and files. Require distinct directory and run identifier; no "just once more" use of V1 frozen TEST.

## 4. Detection protocol and allowed inputs

V2-006 must publish an explicit detector contract before choosing any learned model. First baseline should be interpretable:

1. Extract **observable** RGB surface contrast/texture/candidate objectness, numeric thermal apparent-K residual relative to local surroundings (with validity/emissivity quality) and LiDAR **surface** height/range/roughness geometry.
2. Georegister samples by actual pose, camera intrinsics/extrinsics and timestamps; reject unmatched samples outside documented tolerance (nominal ≤1 sim tick) rather than falsely fuse.
3. Apply a **fixed baseline threshold** or documented TRAIN-fitted model; classify only SUSPECTED. Use training-derived score weights, prespecified missing-channel handling and calibrated probability only if validated on separate data.
4. Associate candidate events spatially and temporally by observation-derived location, with duplicate policy and error estimate; record evidence frame_ids, sensor valid masks and detector model/hash.
5. Export only observation-derived data; actual hidden truth match, target type, target location and burial depth remain in evaluator.

**No direct detection from LiDAR of buried objects.** LiDAR can detect surface morphology / elevation anomalies but is not a landmine identity sensor. Thermal emission is from surfaces and environment; artificial "buried target" thermal signatures in simulations are hypotheses. RGB is principally suited to visible surface objects, not underground sensing.

### Missing/failure policy

- If RGB, thermal and LiDAR all invalid at same place/time → no event, mark unobserved/invalid.
- If only one modality valid → either emit no event or clearly labeled SINGLE_CHANNEL_SUSPECTED subject to predetermined policy, never synthesize absent channels.
- No observation = no assertion of a hazard-free cell.
- Stale frames do not gain new time; failed georegistration cannot be hidden.
- A flat uniform thermal frame need not yield one hotspot; forced fixtures are allowed only in **DEMO FIXTURE** mode and excluded from accuracy reports.

## 5. Metrics and their units — do not mix denominators

**Predefine analysis unit** separately for each experiment. Recommended:
- Cell-level grid evaluation at a declared **2-D cell size** and area; positive if private truth within that cell according to pre-registered geometric boundary. Do not mix target-, cell- and image-level TP/FP.
- Event-level evaluation with maximum match distance r_match_m defined **before** seeing test, one-to-one assignment, duplicate penalty, multiple observations policy, IoU optional for bounding boxes; distinguish event localization error.
- Mission/sensor quality: planned path coverage %, **valid observed sensor coverage %**, dropped frame %, invalid ray %, wall-time vs simulated time, false alarms per surveyed hectare, localization error distribution.

For a chosen binary unit:
- TP = predicted suspected with matching private target; FN = positive truth without matching prediction; FP = predicted suspected where private truth negative; TN = truth-negative without predicted suspect.
- Precision = TP/(TP+FP); recall/sensitivity = TP/(TP+FN); specificity = TN/(TN+FP); F1=2TP/(2TP+FP+FN); false-positive rate FP/(FP+TN). If denominator zero → report "undefined / NA"; do not coerce to 0 or 100.
- Report raw TP, FP, TN, FN first, with unit, per-scenario counts and confidence intervals; small sample estimates have wide uncertainty. Use scenario-group bootstrap CIs, not frames pretending to be independent observations.
- If apparent confidence score is uncalibrated, **do not call it probability** or report Brier/ECE as calibrated without a documented calibration split.
- Report false alarms per hectare or per **valid observed** area only with correct hectares/units and with coverage denominator included; extremely low valid coverage must not improve accuracy deceptively.

**Fixed baseline comparisons:** RGB-only, thermal-only, fused RGB+thermal (and plus LiDAR only as terrain-context feature), fixed survey grid. Experimental PPO may be evaluated separately on new experiments, not "winner by default." Keep common scenes/seeds and equal observation budgets when comparing routes.

### New held-out research reporting rules

- Retest only if formally declaring a new experiment version and fresh previously unused holdout; never recycle the locked holdout as "new".
- If held-out result is poor, publish it clearly with sample count and missed targets; **do not swap in an attractive S0 fixture**.
- Negative controls must be included in the report, not removed from denominators for cosmetic scores.
- Note that synthetic generalization tests cannot directly validate real mine-detection sensitivity/specificity, even if accuracy is high.

## 6. Test order, acceptance matrix and ownership

| Gate | Test | Owner (execution) | Expected evidence (not assumed PASS) |
|---|---|---|---|
| EVAL-01 | Verify scenario group hashes disjoint TRAIN/VAL/TEST, and split manifest frozen | Shabaz specification; Rahil execution | Group IDs, hashes, counts, seed manifests |
| EVAL-02 | No truth fields in public observation structs, nested structs, exports, filenames and UI | Rahil V2-006/008 | Automated negative test with injected forbidden fields and rejection |
| EVAL-03 | Golden known-geometry RGB thermal ray and LiDAR intersection tests | Rahil V2-005 | Numeric expected/observed values + tolerances |
| EVAL-04 | Kelvin thermal palette invariance and emissivity/ambient nuisance model | Rahil V2-005 | Numeric array hashes, display palette changed only |
| EVAL-05 | Hidden target counterfactual with identical observable samples yields identical detector events | Rahil V2-006 | Paired deterministic output comparison |
| EVAL-06 | Zero-target clutter/negative scenarios yield truthful false alarms if any, not forced 0 | Rahil V2-006/008 | Raw events and evaluator counts |
| EVAL-07 | Full sensor dropout, partial masks, stale frames | Rahil V2-005/006 | invalid_reason, valid mask, no fabricated outputs |
| EVAL-08 | Fixed transparent baseline vs fusion on VAL groups, threshold frozen before TEST | Rahil V2-006/008 | Baseline config, tuning log, locked model hash |
| EVAL-09 | One-time fresh held-out group evaluation with independent evaluator and exact counts | Rahil V2-008, Shabaz audit V2-009 | No destructive overwrite, TN/FP/FN/TP and variance |
| EVAL-10 | Exported guide report labels synthetic and suspected only, non-clearance | Rahil V2-008; Shabaz V2-009 | Screenshots and export text review |
| EVAL-11 | Disjoint RNG streams: enabling thermal does not change RGB stream | Rahil V2-005 | Per-channel deterministic sample hashes |
| EVAL-12 | Sensor geometry map alignment and time no-future leakage | Rahil V2-005/006 | Pose IDs and t_s comparisons |
| EVAL-13 | Real sensor vs recorded dataset not conflated with simulation | Rahil V2-008; Shabaz V2-009 | Provenance and human-readable captions |
| EVAL-14 | Original V1 frozen results remain unmodified | Shabaz V2-009 | Git diff and checksum review |

Gates EVAL-09 may be **NOT RUN** until appropriate complete models exist. These are requirements, not test outcomes. V2-004 itself is DOC only: no MATLAB algorithm evaluated by writing this plan.

## 7. External literature and applicability limits

- **Baur et al.**, Remote Sensing 2026, 18(13), 2182: https://www.mdpi.com/2072-4292/18/13/2182 — comparative 34 datasets, 143 seeded items, nine sensing families. RGB best for *surface* item appearance, thermal may show nonunique anomalies, LiDAR weak direct target discrimination. Authors note major airborne subsurface limitations. The paper's 94.8% RGB/83.7% thermal study-level surface rates are **not** our accuracy, and cannot be extrapolated to buried mine clearance.
- **Tenorio-Tamayo et al.**, Data in Brief 2023, 49, 109443: https://doi.org/10.1016/j.dib.2023.109443 — 2,700 thermographic drone images from controlled buried-object scenes at different heights, useful as environmental/appearance comparison; no guaranteed V2 simulator detector performance.
- **FLIR measurement fundamentals**: https://support.flir.com/docdownload/assets/web/27eh/en-us/ — emissivity, reflected apparent temp, distance and atmosphere all change apparent readings; thermal color alone is not physics.
- **IMAS land release 07.11**: https://www.mineactionstandards.org/standards/07-11/ — field survey, technical survey and clearance have evidence/organizational criteria that virtual image patterns cannot meet.
- **MathWorks UAV LiDAR**: https://www.mathworks.com/help/uav/ref/uavlidarpointcloudgenerator-system-object.html — sensor-frame point-cloud simulation with mesh geometry/noise.
- **MathWorks UAV sensor mounting**: https://www.mathworks.com/help/uav/ref/uavsensor.html — rate and mounting conventions.

## 8. Exact handoff to V2-005/006/008

1. Implement data schemas from V2_004_SENSOR_CONTRACTS.md, with validation and safe boundary wrappers.
2. Implement synthetic forward-model evidence that does not permit lookup of hidden target truth by detector or public UI.
3. Log the simulation run seed, scene family, exact sensor model versions and rendering technique.
4. Build geometry/Kelvin/LiDAR unit tests plus temporal/invalidity tests *before* rendering appearance improvements.
5. Implement anomalous-object decisions only after documented negative/positive clutter controls.
6. Reserve test groups by scenario and lock parameters/threshold before any fresh held-out evaluation.
7. Report **actual** results with full error denominators, negative controls, costs and failure cases.
8. Never say "landmine confirmed", "safe" or "cleared" in public outputs. Source research is not a substitute for executed MATLAB tests.

**Signoff boundary for V2-004:** acceptance means the research-backed virtual sensor contract, truth firewall, realistic limitations and prespecified evaluation tests are documented and reviewed; it does not mean any V2 sensor feed has been implemented or detection quality improved.
