# Objective-to-Test Traceability Matrix (Review and Viva)
**Original objectives remain verbatim in [PHASE1_BASELINE.md](PHASE1_BASELINE.md).** This document operationalizes the simulation tests without replacing wording.

| Original objective | Implementation component | Verification evidence | Pass means | Pass DOES NOT mean |
|---|---|---|---|---|
| O1 autonomous pre-programmed flight | Scenario + grid route + UAV pose log | Real MATLAB flight-run log, waypoint coverage, completion and replay | Simulated drone followed pre-programmed survey without user piloting | Physical autonomous flight or flight safety |
| O2 subsurface coil + thermal fusion, minimize false detections | Physically limited EM/thermal models, fusion, held-out benchmark | Standoff/depth sweeps, threshold/AI performance, confusion matrices, negative controls | Code/models respond consistently under documented synthetic parameters; false alarms measured | Accurate airborne buried-mine detection in real terrain |
| O3 GPS geo-tag, real-time remote GCS | Synthetic coordinate mapping and App Designer display/log | Map screenshot with timestamped run, exported sample/detection CSV and link to actual log | Virtual positions associated with simulated events and displayed in run | Actual GNSS precision or remote hardware link |
| O4 eliminate human exposure | Virtual unattended mission scenario and personnel-free simulator | Automated mission demo, operator physically outside simulator scenario, risk narrative | Survey control concept demonstrated without entering *simulated* field | Proven reduction in real casualties or hazard avoidance |

## Top-level acceptance threshold
No subjective '90% done' without per-task deliverable status. For each O1–O4, report **Not started / Implemented not tested / Tested in simulation / Unverified external feasibility** with links to actual evidence and known gaps.

## Core tests
| ID | Test | Input | Expected invariant |
|---|---|---|---|
| AT-01 | Seed reproducibility | same seed/config twice | identical scenario/truth and consistent logs |
| AT-02 | Mission bounds | waypoints at extreme edges | all inside configured polygon |
| AT-03 | Sample continuity | known route/time step | timestamps monotonic; sensor IDs linked |
| AT-04 | EM altitude stress | 0.2m vs 5m coil separation | model-dependent attenuation documented; no unjustified high-altitude success |
| AT-05 | Nonmetallic EM control | purely nonmetallic target | no deterministic metallic response attributed to it |
| AT-06 | Thermal false positive | hot harmless rock | confidence/failure reported; not auto-labelled mine |
| AT-07 | Fusion consistency | one modality missing | explicit invalid/fallback, no truth leakage |
| AT-08 | Synthetic geotag | known local coordinate target | expected projection/coordinate uncertainty |
| AT-09 | Empty field | no targets | valid run and honest false alarms |
| AT-10 | Collision/exclusion | route conflict | reject or constrained reroute; no silent overlap |
| AT-11 | PPO fairness | held-out same scenarios | grid and PPO use identical budgets/conditions |
| AT-12 | Dashboard status | no completed run | no fake metrics; simulation banner visible |
| AT-13 | Export reproducibility | known seed/SHA | metadata and files retrievable |
| AT-14 | Mac compatibility | installed MATLAB on both | real open/run logs, else NOT RUN |
| AT-15 | Source/licence audit | selected third-party code/dataset | verified licence/attribution before inclusion |

## MG-010 dashboard UI acceptance

MG-010 canonical dashboard contract: [MG010_MISSION_DASHBOARD_SPEC.md](MG010_MISSION_DASHBOARD_SPEC.md). Its **UI-01…UI-20** tests are required *later* for Rahil's MG-011 MATLAB App Designer implementation, not passes claimed by MG-010 documentation. In particular, AT-12 "no completed run" means disabled replay/no invented metrics; AT-13 export provenance must be read back from actual saved files; FR-05 virtual geotags must never be described as physical GPS. A synthetic alarm is always **SUSPECTED**, never proof of a cleared area. An evaluator-only aggregate cell confusion matrix can be displayed without sharing private truth with app callbacks.

## MG-012 optional PPO survey policy acceptance

The formal observation/action/reward specification, paired grid comparison and executable checks **P-01…P-20** are defined in [MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md](MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md). MG-012 documents requirements only: it has **not** executed RL training or reported an achieved reward/coverage improvement. MG-013 owns PPO MATLAB implementation and testing; MG-014 owns locked test-scenario planning; MG-019 is optional integrated comparison. O1/FR-07 are supported by same-budget measured synthetic coverage/time/distance, not a presumed PPO win. No detection accuracy, field deployment, human-safety or physical flight claim follows from policy reward.

## MG-014 locked integrated evaluation and demonstration acceptance

The authoritative predeclared **L-01…L-24** integration/negative-control matrix and **D-01…D-10** guide demonstration gates are in [MG014_LOCKED_TEST_MATRIX_AND_DEMO.md](MG014_LOCKED_TEST_MATRIX_AND_DEMO.md), using the [30-family 18/6/6 scenario manifest](../experiments/locked/mg014_scenario_manifest.json). MG-014 is a DOCUMENTATION task and does **not** execute or pass any L-test. Rahil's MG-015 must run and document core L-01…L-22, while PPO and cross-platform/3-D/portal L-23/L-24 are conditional; Shabaz's MG-016 checks evidence independently. The original O1…O4 wording, cell-unit confusion versus object matching, undefined NaN metrics and absence of validated landmine detection are preserved.

## Metrics and interpretation
```text
precision = TP / (TP + FP)
recall = TP / (TP + FN)
specificity = TN / (TN + FP)
FPR = FP / (FP + TN)
F1 = 2 TP / (2 TP + FP + FN)
coverage = visited_valid_cells / total_valid_cells
```
Undefined denominators → NaN or defined convention, explicitly reported. Classification matches require agreed location tolerance and one-to-one association to avoid multiple hits artificially inflating TP.

**Do not assign any numerical acceptance cutoff for mine-detection accuracy before representative data and guide approval.** Tests of *software correctness* may have deterministic exact assertions; performance conclusions require distributions, confidence intervals where practicable and interpretation.

## Proof and grading rules
A test is PASS only if executed by a named tester/CI with command, output, environment and code SHA. Static GitHub workflow PASS is *not* MATLAB algorithm PASS. Rendering an attractive heatmap is not a confusion-matrix test.
