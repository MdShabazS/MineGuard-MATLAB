# V2-006 limitations: root causes and a successor proposal

**Research proposal. Not a change to V2-006.** V2-006 stays DONE. SIMULATION ONLY. VALIDATION remains **NEGATIVE**: G07 0 of 4 targets with 45 fused false alarms, and G08 32 fused false alarms on a target-free group. Nothing here changes that, and no result here shows that a detector works.

**Code and results SHA: `8a860e38026c6506247f6863c83ba41144143089`.** Host: macOS 27.0.1, arm64, MATLAB 26.2.0.3433840 (R2026b Update 1). Output: `results/console_at_tested_sha.txt`, with CSVs alongside.

## Boundaries kept

- No detector, sensor, threshold, dataset or study file changed. Fingerprint stays `fnv1a64:d6d364f988f04bb4`.
- VAL and TEST were not run and VAL tables were not read for any design decision here. The VAL figures above are copied from `v2/evidence/V2-006.md`.
- `mgv2x` lives outside `v2/matlab`, and a test confirms no application file refers to it. The live dashboard does not use it. #86 was not used.
- **Data used:** new synthetic frames (D1), committed TRAIN tables and TRAIN evaluator truth (D2), public landmarks (D3), and the DEMO FIXTURE (D4, D5).

**How to read TRAIN figures:** TRAIN is consumed tuning data. These counts describe the frozen detector's outputs and are not accuracy estimates. D2 reproduces the frozen TRAIN result exactly, at 2 TP, 301 FP and 13 FN.

## Findings

| # | Weakness | Exact cause | Measured | Class | Safest route |
|---|---|---|---|---|---|
| 1 | RGB halo | The 31 px box mean includes the object, so nearby background gets a residual of about contrast × object area / 961. With the 2 DN spread floor, z > 4 fires near 8 DN, and z drops the sign, so disc and halo join | Inflation begins where the prediction crosses about 8 DN. A 0.90 m disc at DN 40 measures 2.03 m. A 1.20 m landmark on simulated frames measures a median 1.77 m and passes the size limit in 28% of sightings | **Design limitation** of the frozen form | Successor only |
| 2 | False alarms | Mixed, and not fully itemised. 176 of 303 TRAIN events lie within 1 m of a public rock or bush, and 155 have LiDAR height above 0.15 m | These overlap and show association, not proven cause | **Scientific limitation** | Successor, evaluated |
| 3 | Events outside boundary | No boundary rule exists, while the footprint extends past the polygon | 213 of 303 TRAIN events are outside, by a per-group median of 1.5-11.7 m | **Post-validation model change** | Successor, with care below |
| 4 | Pose assumption | Georegistration uses `T_world_sensor`, the reference pose, while `pose_sigma` assumes 0.10 m | On DEMO, navigation minus reference: horizontal median 1.37 m, p95 2.06 m, mean offset 1.32 m. Declared sigma 0.87 m | **Scientific limitation**, already disclosed. Not a code defect: it is the stated design | Successor must test noisy pose |
| 5 | Uncertainty | `pose_sigma` enters `sigma_obs` and is added again | Excess, gsd 0.075 m, no scatter: 21.6% at n=2, 9.4% at n=5, 2.5% at n=20, 0.5% at n=100. Calibration: landmark per-axis errors, 24 values, 83% within 1 sigma and 100% within 2, median error 0.20 m | **Formula defect in a reported value**, with no effect on event decisions by code inspection | Successor. Changing it would alter reported values of the accepted detector |
| 6 | LiDAR unscored | Context only, by design | Dropping protruding events: FP 301 to 146, TP unchanged at 2 | **Design limitation** | Successor |
| 7 | Score | Saturating strength, look ratio, and mean over modalities that had looks. No calibration | 38 of 303 events score the cap of 1.0. The 2 TP score 0.307 and 0.401; 66.8% of FP score at least the best TP | **Scientific limitation** | Calibrate only on a new TRAIN |
| 8 | Association | Greedy nearest track, 1 m gate, 0.6 m merge, stored order | Event nearest neighbour under 1 m: 28 of 303; under 2 m: 80; median 3.64 m. **Whether these are duplicates was not established** | **Unresolved** | Needs a dedicated fixture |

Thermal uses the same box-mean form (25 px, 1 K). Its halo was **not measured** here.

### Descriptive filters on TRAIN

Each row applies one rule to the frozen FUSED events.

| Rule | TP | FP | FN |
|---|---:|---:|---:|
| None (frozen) | 2 | 301 | 13 |
| Inside polygon | 2 | 88 | 13 |
| Inside polygon + 1 m | 2 | 120 | 13 |
| Not LiDAR protruding | 2 | 146 | 13 |
| More than 1 m from public objects | 2 | 125 | 13 |
| Overlaps survey phase | 2 | 284 | 13 |
| Both modalities | **0** | 137 | **15** |

**These don't show that any filter works.** All have only 2 true positives, and they use consumed data.

- **Boundary artefact:** **all 15 TRAIN targets lie inside the polygon by construction**, so a boundary rule cannot lose one here. A new evaluation needs targets near and beyond the edge, or a stated operating rule that only the polygon is in scope.
- **Requiring both modalities removes both TPs.** This is a warning against the most obvious false-alarm rule.
- **An object rule may hide protruding targets.** Scenario features are flat, so this data cannot show that risk.

### Experimental background forms

`mgv2x.detect.rgbResidualCandidates` keeps the frozen constants and changes only the stated form.

| DEMO frames (71) | Frozen form | Polarity split | Clipped |
|---|---:|---:|---:|
| Landmark measured diameter, median (true 1.20 m) | 1.77 m | 1.33 m | 1.29 m |
| Landmark sightings within size limit | 28% | 83% | 100% |
| All components per frame, median (max) | 8 (23) | 10 (40) | 5 (15) |
| Components within size band, median (max) | 2 (8) | 5 (16) | 3 (8) |
| Residual time, median | 5.5 ms | 6.1 ms | 11.9 ms |

On the synthetic sweep, clipped measures each disc to its true size at every tested contrast and radius.

- **Clipped is worth evaluating. It is not shown to be better.** In-band candidates per frame rise from a median of 2 to 3, so **false alarms could increase**, because a fixed halo no longer removes objects by accident.
- **The first clipped form failed.** It removed the discs entirely because the support guard counted masked pixels as missing. That output is kept in `results/d1_halo_sweep_first_clipped_form_FAILED.csv`. The fix is a design correction, and no threshold changed.
- Time roughly doubles, on a loaded host, for this one step.
- It is the same idea as the guard window in dual-window anomaly detection.

## Safe engineering corrections

No frozen decision may change, so these are proposals and **none was applied**:

1. V2-006 evidence §8 item 8 calls the double count "slightly". For a 2-observation track it is about 22% in this example, so its wording could carry that number.
2. The UI may want to display 0.87 m navigation sigma next to event uncertainty, so a reader does not take 0.1-0.3 m as real-world accuracy. This belongs to V2-007 and is not raised on its branches.

Changes to image processing, event selection, scoring, uncertainty or boundary filtering all belong to a successor.

## Proposed evaluation: `MGV2X-EVAL-0.1`

**Status: proposal, not started, nothing generated.** It needs separate approval.

1. **Identity.** A new detector ID and fingerprint. `MG-V2-INTERPRETABLE-BASELINE` 1.0.0 stays as the frozen comparator.
2. **Scenarios.** New groups with seeds disjoint from G01-G10, hashed in a manifest before any simulation. G09 and G10 stay sealed for V2-008.
3. **Split by group, suggested:** 24 TRAIN, 12 VALIDATION, 12 TEST, each covering all families. The target count must be set by a stated precision requirement. The present 4 VAL targets cannot support any estimate.
4. **Families.** Mixed targets, target-free, clutter, low contrast, dropout, with camera altitude and off-nadir variation. Include **protruding targets, targets close to the polygon edge and beyond it**, and a share with no signature.
5. **Primary metrics, fixed in advance.** Event-level recall and false alarms per hectare in each scope, with one-to-one matching at the existing 1 m, reported overall and for target-free groups. Report precision and F1 as secondary, and duplicates per matched target.
6. **Comparison.** Baseline and each candidate on identical samples, paired by group, with group-level bootstrap intervals. One ablation per change: background form, boundary, LiDAR, pose source.
7. **Uncertainty.** Empirical coverage on matched events and landmarks, using reference pose and using the noisy navigation pose. The pose term is one term in the model, fitted on TRAIN only.
8. **Score.** Calibration only on the new TRAIN, reliability checked on VALIDATION. Scores stay labelled uncalibrated until that has passed.
9. **Freeze.** All settings, code SHA and fingerprint before VALIDATION, and again before TEST. **One TEST run, only with separate written authorisation.** Report failures as they are, with no retuning on TEST.
10. **Stop rule.** If VALIDATION shows no improvement over the baseline, publish that and do not open TEST.

## Scientifically unverified

Detection capability of any form. Whether clipped reduces or raises false alarms at event level. Causes per false alarm. Duplicate rate. Uncertainty coverage on small objects or with noisy pose. Thermal halo. Windows behaviour. Real sensors, terrain or targets: all figures are synthetic.

## References

MATLAB functions used: `conv2`, `inpolygon`, `median`, `readtable`, documented at mathworks.com/help/matlab. Image Processing Toolbox is installed, and `bwconncomp` and `medfilt2` are options a successor could consider; neither was tested here.

From memory and **not re-read for this report**, so please check before citing: Reed and Yu, IEEE Trans. ASSP, 1990 (RX anomaly detection); Bar-Shalom and Fortmann, *Tracking and Data Association*, 1988; Niculescu-Mizil and Caruana, ICML 2005 (probability calibration).

## Reproduce

```matlab
addpath('v2/matlab', 'v2/research/V2-006-successor', 'v2/research/V2-006-successor/diagnostics');
d1_haloSweep(); d2_trainAnatomy('v2/data/V2-006'); d3_landmarkCoverage('v2/data/V2-006'); d4_poseAssumption(); d5_landmarkSizeOnFrames(1400);
runtests('v2/research/V2-006-successor/tests/testV2006xDiagnostics.m')
```
