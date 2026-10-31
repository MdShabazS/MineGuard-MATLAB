# MG-008 — Fusion, Dataset Splits and Honest Evaluation Contract

Task: MG-008
Owner: Shabaz
Specification date: 2026-10-31
Status: DOCUMENTATION SPECIFICATION; **implementation and numerical tests pending MG-009**.
Dependencies: MG-006 DONE on protected main. MG-007 sensor implementation is a separate Rahil task; MG-009 depends on BOTH MG-007 and MG-008.

This specification is normative for Rahil's MG-009 baseline. It **does not** change `mg-contract/1.0`, the frozen functions or data fields in [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md). It uses the MG-006 physics validity specification in [MG006_SENSOR_PHYSICS_AND_TESTS.md](MG006_SENSOR_PHYSICS_AND_TESTS.md). All results are from a **synthetic simulator only**, never evidence of actual explosive detection, minefield clearance or safe use in real terrain.

## 1. Frozen module boundary and truth firewall

```matlab
events = mineguard.detection.detectAnomalies(detectorConfig, poses, samples, model);
result = mineguard.evaluation.scoreDetections(config, events, truth, runMetadata);
```

- `detectAnomalies` has ONLY the frozen four inputs. Its `DetectorConfig` is an orchestrator-supplied narrow view, containing exactly the frozen MG-003 fields `schema_version`, `scenario_id`, `association_tolerance_s`, `threshold`, `method_name` and an explicit missing-modality rule. **Never give the detector `ExperimentConfig`, truth, target count, target coordinates, burial depth or scenario wrapper**.
- The `model` argument may contain **frozen learned or validation-selected parameters**, version, training split ID, scaling parameters and calibration mapping. These may not encode any held-out test labels, withheld target layout or test-specific truth.
- `poses` is a typed `PoseSample` table, `samples` comprises typed thermal/EM `SensorSample` observations with no true labels. Position estimates are taken from timestamped pose references **only**; never from hidden `TargetTruth`.
- `scoreDetections` is evaluator-only and may receive `truth`. `runMetadata` holds the declared evaluation grid, legal cells and test provenance/coverage; the detector must not see or read this evaluator-only metadata if it contains truth-dependent fields.
- Public detector output uses the **exact 12-field** `DetectionEvent`: `event_id`, `t_s`, `x_est_m`, `y_est_m`, `confidence_0_1`, `uncertainty_m`, `thermal_sample_id`, `em_sample_id`, `method_name`, `threshold`, `status`, `valid`. Every returned positive is **`status="SUSPECTED"`**.
- Empty detections must be a **typed zero-row DetectionEvent table**. No fabricated true-positive field in public events, no IDs of hidden objects, and no GUI/data export of evaluator `TargetTruth`.
- `ExperimentResult` retains all frozen fields from MG-003 without renaming: `schema_version`, `scenario_id`, `seed`, `algorithm`, `coverage_fraction`, `mission_time_s`, `distance_m`, `tp`, `fp`, `tn`, `fn`, `precision`, `recall`, `f1`, `false_alarm_rate`, `localization_error_m`, `matlab_release`, `toolbox_manifest`, `git_sha`, `split_id`, `scenario_seed`. Metric denominators and excluded cells should be preserved in **separate evaluator-only evidence/metadata**, without altering these frozen fields.

## 2. Synchronization and sample validity

1. Link every `SensorSample.pose_sample_id` to exactly one existing pose; reject duplicate IDs, unmatched pose refs and schema/unit mismatches. Validate that the sample's `t_s` is consistent with its linked pose time within the configured tolerance. ENU metres, thermal kelvin and dimensionless normalized EM are non-negotiable.
2. For thermal/EM pairing, select the closest valid opposite-modality observation by absolute time difference **≤ `association_tolerance_s`** (in seconds). Require consistent or valid pose association; use timestamp then lexicographic `sample_id` for deterministic ties. Do not allow the same sample to join multiple detection candidates without an explicitly documented one-to-many measurement model.
3. For a missing or invalid reading, preserve `valid=false`, `NaN` active-channel value, the original `sample_id` and `invalid_reason`. **Never** replace NaN with 0, a ground-truth-derived value, another sensor's observation, or a fabricated probability. Joining a valid thermal to an invalid EM sample does not make the EM reading valid.
4. If both modalities are missing/invalid for the same candidate region/time, emit **no valid suspected events** and count that region as **not assessable**, not as a true negative. No `NaN` is permitted to pass a threshold through implicit comparisons.
5. The frozen `DetectorConfig` must state the selected missing-modality rule, e.g. `"abstain"` (strict two-channel method), `"single_valid"` (degraded single-channel fallback) or `"require_both"`. These are illustrative **allowed choices within the existing field**, not new top-level DetectorConfig fields. Invalid or unrecognised rule must be rejected.
6. `association_tolerance_s=0` means exact-time match. Too-large tolerances must be pre-specified, reported as a sensitivity parameter and **not tuned using test labels**. No future-frame interpolation without declaring latency; baseline uses nearest observation only.

## 3. Simple reproducible detection/fusion baselines

To preserve comparability, MG-009 must implement at least:

| Method | Observation/features | Rule | When modality invalid |
|---|---|---|---|
| T-only | thermal `temperature_K` and its model-defined background | Fixed validation-selected **signed contrast/anomaly magnitude** threshold; not absolute temperature without baseline | thermal invalid: abstain |
| EM-only | valid `response_norm`, after documented background adjustment | Fixed validation-selected EM threshold | EM invalid: abstain |
| OR | valid individual boolean T/EM threshold outputs | Flag either modality positive | `single_valid` uses present modality; `require_both` abstains |
| AND | both independently exceed thresholds | Flag only if both present/positive | strict abstention when either missing |
| Weighted | training-defined feature normalization, weights and validation-fixed final threshold | `score = w_T * z_T + w_EM * z_EM` with explicit fixed weights; no undocumented refitting | either abstain or use explicit stored single-channel fallback, never silently renormalize a missing channel |

- The `threshold` in `DetectorConfig` is the **model decision score threshold** appropriate to the selected `method_name`. Single-channel component thresholds and weights are frozen inside a versioned model/config artifact selected **before** test evaluation.
- `z_T` and `z_EM` are finite feature scores (e.g. training-fitted normalized anomaly deviations). Estimate means, scales, background and imputation policies only from **TRAIN** data. Handle zero-variance scale explicitly (reject or documented stable rule), not accidental division-by-zero.
- Never compare temperatures in K against dimensionless EM scores directly. Both channels must be transformed to explicit dimensionless comparable features before weighted fusion; OR/AND first threshold their own units/scores.
- `confidence_0_1` may only contain a calibrated probability if calibration was fitted on **validation/train, never test**, with calibration method recorded. Otherwise `NaN` (unavailable) is honest; do not equate an arbitrary normalized score to probability. `uncertainty_m` is `NaN` unless actually estimated.
- De-duplicate adjacent/temporally repeated positives into an **event** via a fixed pre-declared temporal window and spatial radius, without consulting truth. Report how many raw threshold exceedances became events. Avoid many consecutive samples counting as multiple independent alarms.
- Learned classifiers are optional. MATLAB toolboxes must first be verified available; the simple deterministic baseline must work in core MATLAB without Sensor Fusion and Tracking Toolbox.

## 4. Split unit and immutable dataset protocol

**Required baseline:** team-created, reproducible synthetic experiments from MG-004 + MG-005 + MG-007. Do not claim real-image or real EMI datasets were ingested. Candidate external datasets listed in [DATASET_AND_LICENSING.md](DATASET_AND_LICENSING.md) remain **PENDING RIGHTS/FORMAT VERIFICATION**, and handheld EM data do not constitute a calibrated airborne coil signal.

### Dataset manifest (separate evaluator-only artifact)

Each scenario group must record `split_id` (`train|validation|test`), `scenario_id`, scenario `seed`, `noise_seed`, derivation of thermal/EM/navigation seeds, `soil_class`, scenario/model version, sensor parameter set version, altitude, footprint and configuration checksum. The **private** manifest may reference truth for evaluation; the detector only receives redacted feature/observation tables. Avoid publishing a combined `events+truth` export as an inference input.

### Split rules

1. Split by the **whole underlying scenario/environment generation group**, never by pose row, sensor frame or overlapping patch. All samples, augmentations, replicate noise versions and time slices from the same base target layout belong to one split.
2. Scenario IDs and scenario seeds are disjoint across TRAIN, VALIDATION and HELD-OUT TEST. If a common master seed spawns several noise seeds, its entire family is assigned to one split. Save a versioned immutable seed list and grouping key. Do not generate test scenarios on demand based on observed classifier performance.
3. For a reproducible initial development proposal (not executed results), use **60/20/20** scenario-group proportions. The exact counts, seeds and class prevalence are chosen and frozen **before testing**, not implied by this percentage.
4. Set training feature scaling, optional model weights and background-estimation policy on TRAIN only; select all thresholds, dropout policy, spatial event-clustering radius, matching radius and optional probability calibration on VALIDATION. Freeze these decisions before the final TEST evaluation. Record chosen thresholds **without retroactively tuning on TEST**.
5. Keep a meaningful representation of **empty fields**, metallic and nonmetallic synthetics, rocks/roots/hot clutter, shallow/deep burial, alternate soil classes, altitude/footprint variability and low/high noise. Avoid accidentally leaking the target count via configuration into the detector.
6. **Stress test** changed altitude, soil/moisture proxy, heat contrast sign, noise, invalid/standoff-domain samples and time skew. For out-of-distribution stress sets, label them `stress` with versioned condition; do not pool them into the ordinary test metric without stating separate breakdowns.
7. If external real recordings become usable later, verify licence, platform height, pairing, provenance and release permissions first. Evaluate as a **separate external domain test**; do not present synthetic accuracy as hardware performance.

## 5. Primary metrics: fixed-grid CELL unit for confusion matrix

**Reason:** The frozen `ExperimentResult` contains `tp,fp,tn,fn`. An *event-to-object* matcher has no natural population of true negatives. Mixing target-level TP/FP/FN with a guessed cell TN would make precision/FPR incomparable.

Therefore the baseline primary `ExperimentResult` counts **one legal evaluable survey cell per trial**, using the exact MG-005 planned grid definition and valid cells. This is an explicit evaluation convention; it does not imply that a cell's geometric centre has been physically observed.

Before computing any metrics, freeze:
- Cell dimensions / origin / half-open boundary rule and exclusion-zone policy (must equal or be explicitly reconciled with the MG-005 grid).
- Observation support policy: a cell is **evaluable** only when adequately visited/observed with a valid modality under the selected missing rule. Sample-footprint weighting, dwell/pose-hit threshold or visited-cell test must be versioned; sensor dropouts cannot turn unobserved cells into TN.
- True cell label: **positive iff a hidden `TargetTruth.label=="target"` location lies in that cell**. Pure clutter is negative even when thermally hot or metallic. A target on a cell boundary maps to one cell by the fixed boundary rule.
- Predicted cell label: **positive iff at least one valid `DetectionEvent` with `status=="SUSPECTED"` lies in that cell**. Multiple alarms in one cell still count only **one predicted positive**. Invalid/off-grid events cannot create a TP.
- Cells not assessed under the declared observation/coverage rule are **excluded from the scored population and counted separately**; do not silently mark negative. For an additional strict mission-wide report, count targets in unassessed cells as `unobserved_target_count` and explicitly distinguish that from detector misses.

A standard confusion table over **evaluable cells** is then coherent:

| | Truth cell positive | Truth cell negative |
|---|---|---|
| Predicted suspected | TP (one per cell) | FP (one per cell; may be hot clutter) |
| No suspected event | FN (one per cell) | TN (one per cell) |

Use **cell-unit counts** for `ExperimentResult.tp/fp/tn/fn` and all `precision`, `recall`, `f1`, `false_alarm_rate`. The evaluator-only report must explicitly state `metric_unit="evaluable_survey_cell"`, cell dimensions, how coverage was determined, confusion denominators, `excluded_cell_count`, `total_legal_cell_count`, and class prevalence. A field with 2 targets in the same cell has **one positive cell**: do not advertise cell recall as object-level recall.

### Exact arithmetic and undefined ratios

```text
precision        = TP/(TP+FP)              if TP+FP > 0, else NaN
recall           = TP/(TP+FN)              if TP+FN > 0, else NaN
f1               = 2*TP/(2*TP+FP+FN)      if denominator > 0, else NaN
false_alarm_rate = FP/(FP+TN)              if FP+TN > 0, else NaN
specificity      = TN/(TN+FP)              if TN+FP > 0, else NaN (supplemental)
coverage         = visited_valid_cells / total_valid_cells (MG-005 metric, separately)
```

These ratio denominator counts must be logged. No divide-by-zero warnings, no `NaN→0` substitution, no averaging NaNs as zeros, no undefined F1 presented as perfect success. Record micro-aggregated pooled cell counts and macro per-scenario metrics **separately**. The result must remain honest for an empty truth field and for a no-coverage or all-invalid case.

## 6. Secondary event-to-object matching for localization and alarm burden

To assess point estimates without artificially multiplying hits, match **valid suspected events** to true `TargetTruth.label=="target"` objects only at evaluation time using a fixed `localization_match_radius_m` chosen on VALIDATION. Use Euclidean ENU 2D distances. Among event-target pairs within radius, choose an unambiguous **one-to-one, maximum-cardinality matching, minimizing total distance among maximal matchings**; fixed deterministic tie breaks. A greedy nearest-neighbour search may lose matches: use a correct matching method or explicitly test adversarial cases.

Report these *separate* quantities as supplementary evidence:
- `object_event_matches`, `unmatched_events`, `unmatched_targets`; `event_localization_error_m` = mean point distance across matched pairs, **NaN when no matched pair**.
- `event_fp_per_mission` and optionally per metre/time with unit & denominator, never mislabeled as `false_alarm_rate` (cell FPR).
- Cases with multiple target objects in one positive cell; multiple events near one target; events in negative cells; unobserved targets. These demonstrate why cell confusion metrics and object localization metrics must **not** be mixed.
- Frozen `ExperimentResult.localization_error_m` receives the above matched-event mean; if no event-target pairs exist, put `NaN`.

**Alternative** if a future guide requires object-level TP/FP/FN as primary: create a clearly **versioned alternative metric schema with `tn=NaN`**, after a reviewed contract revision. Do **not** mix target-event counts with cell TN under the present frozen `mg-contract/1.0`. No schema revision is proposed by MG-008.

## 7. Validation matrix for MG-009 (specified, not executed)

| ID | Required test input | Pass condition / evidence |
|---|---|---|
| F-01 | Equal-time valid thermal+EM; threshold-controlled known observations | Correct pairing, units, deterministic OR/AND/weighted score and method field |
| F-02 | 0-tolerance and finite tolerance; unequal timestamps; tie times | Exactly documented valid joins, stable tie/ID selection, no duplicate sample use |
| F-03 / C-08 | Thermal invalid, EM valid; then reverse; then both invalid | Rule-dependent fallback/abstain, invalids remain NaN, **both invalid yields typed empty events** |
| F-04 | Hidden truth added to detector config or model; attempted truth/label use | Input rejected; source/API check shows detector never reads evaluator-only `TargetTruth` |
| F-05 | Re-run same observations/frozen threshold/seed twice | Identical events with stable IDs and positions; unchanged global RNG |
| F-06 | Kelvin/normalized EM swapped; invalid schema or unmatched pose id | Explicit informative failure; no silent cross-unit fusion |
| F-07 | Continuous adjacent high-score samples from one source | Frozen clustering produces bounded number of events; no duplicate alarm inflation |
| F-08 | Empty target truth, valid negative cells, zero events | All evaluable cells TN, TP=FP=FN=0; precision/recall/F1=NaN; FPR=0 if TN>0 |
| F-09 / C-09 | Zero evaluated cells or all sensor observations invalid | All four count fields zero; undefined ratios NaN and denominators logged; no fictitious TN |
| F-10 | One positive/negative cell each and threshold events | Exact manually checked TP/FP/TN/FN and resulting ratios; duplicate detections in cell do not inflate TP |
| F-11 | One harmless hot rock/metal debris event in an otherwise negative cell | Cell FP, **never** target TP or 'mine found' |
| F-12 | Two targets in one cell; one target in a different cell; multiple event peaks | Correct cell labels and independent one-to-one event/object localization counts |
| F-13 | Ambiguous crossing distances where greedy object matching fails | Maximum-cardinality one-to-one matching selected; localization matches reproducible |
| F-14 | Train/validation/test with shared seed, repeated layout or nearby frames | Split validator rejects overlapping groups; no test threshold/normalizer fitting |
| F-15 | Identical held-out scenarios/poses/missing mask across five methods | T-only, EM-only, OR, AND, weighted evaluated under matched conditions; no claims fusion always wins |
| F-16 | Changed soil/thermal contrast/EM standoff, skew, noise, dropout | Per-condition sensitivity reports and failure cases, no unsupported high-altitude detection |
| F-17 | Synthetic geotag noise and missing virtual origin | ENU estimates used consistently, invalid geotags marked; location error includes declared uncertainty |
| F-18 | Result/export metadata with `seed`, `split_id`, toolbox, SHA | Exact frozen `ExperimentResult` fields, provenance recorded or marked `NOT_RECORDED`; public bundle has no truth |

**MG-009 completion requires** actual MATLAB execution, command and full pass/fail output for F-01…F-18, frozen split manifests and threshold/model files, versioned confusion + event-matching result records, negative controls and ablations, plus software code/test evidence. Test correctness does **not** demonstrate real buried-mine detection. MATLAB R2026b runtime execution has **NOT** been performed for MG-008.

## 8. Practical ablation/report format

For every held-out scenario and stress condition, record the same `scenario_id`, seeds, route, noise masks, sensor model versions, `split_id`, method, frozen thresholds/model hash, number of legal/evaluable/excluded cells, TP/FP/TN/FN, precision/recall/F1/FPR, event count, event-to-object match count, mean localization distance, altitude and model-domain invalid fraction. Show total counts, per-scenario spread and at least one empty-field/clutter counterexample. Where possible report binomial uncertainty (Wilson intervals on pooled class-conditional rates) without falsely treating adjacent frames as independent observations.

Methods compared under same test conditions:
1. thermal-only
2. EM-only
3. OR
4. AND
5. weighted (optional classifier in a separately labelled experiment)

No threshold or weight may be silently updated between the test scenario examples to improve a headline result. If fusion underperforms, report it. An experimental synthetic metric cannot be described as a real mine-clearance rate.

## 9. Provenance, ownership and source record

**Design lineage**: [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md) (public data schemas, truth firewall), [MG006_SENSOR_PHYSICS_AND_TESTS.md](MG006_SENSOR_PHYSICS_AND_TESTS.md) (sensor units, model limitations), [EXPERIMENTS.md](EXPERIMENTS.md) (E3/E4 held-out design), [DATASET_AND_LICENSING.md](DATASET_AND_LICENSING.md) (rights gate), and [ACCEPTANCE_MATRIX.md](ACCEPTANCE_MATRIX.md) (confusion ratios and acceptance gates).

**Scientific caveat**: physically plausible sensing and calibrated field performance are not established. Thermal false positives, nonmetallic targets, unpaired sensor observations, excessive sensor height and data-domain mismatch must be explicitly documented, not hidden behind AI terminology.

**MG-008 owner** Shabaz: this documentation, acceptance tests, split/evaluator conventions and handoff; no MATLAB code execution claimed. **MG-009 owner** Rahil: implement `detectAnomalies` and `scoreDetections`, execute the F tests and deliver actual reproducible evidence after both MG-007 and MG-008 DONE. Follow protected PR gate and separate TODO→IN_PROGRESS and IN_PROGRESS→DONE transitions.
