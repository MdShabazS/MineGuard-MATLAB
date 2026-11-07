# MineGuard V2.1 — Release record

**MINEGUARD V2.1 — INTERNAL SOFTWARE IMPLEMENTATION COMPLETE**

Date: 2026-11-04 · Repository `main` at `a9f6ad5`, whose product code equals the verified F1 fix commit `ccb2f9e`; this record adds documentation only · Windows 11, MATLAB R2026b Update 1 (26.2.0.3433840), UAV Toolbox and Navigation Toolbox 26.2.

SIMULATION ONLY. V2.1 is an interactive synthetic simulation. It is **not** a validated landmine detector, a field-tested drone or a physically validated sensor system, and it has **no** formal guide approval. Every marker is a SUSPECTED anomaly with an uncalibrated score. Virtual targets are private synthetic hypotheses.

## 1. What V2.1 delivers

| Feature | How |
|---|---|
| Mission setup before flight | `mgv21.ui.MissionSetupApp` |
| Three synthetic environments | `TRAINING_FIELD_A`, `ROCKY_UPLAND`, `DRY_FLATS` (`mgv21.scenario.presetIds`) |
| Survey boundary | Rectangle fields or a polygon vertex table (convex, 3–32 vertices) |
| Grid and route | Line spacing 2–30 m, heading, altitude 6–60 m AGL, speed; generated route preview; validation errors shown instead of a route |
| Target placement | NONE, MANUAL (click to add, move or delete; signature VISIBLE_DISTURBANCE or NONE; burial depth) or RANDOM (count and seed, reproducible) |
| Lock and blind flight | LOCK & START removes every marker; the flight runs in the original V2 dashboard with the chosen world and grid |
| Private forward model | Visible-disturbance targets become flat surface features seen only by the RGB and thermal models; LiDAR cannot see them; no-signature targets are unobservable |
| Post-run evaluation | A separate EVALUATION VIEW window opens when a live run ends. It reveals the targets (matched, missed, missed with no signature) and the events (matched, false alarm) from the evaluator's own pairing, with TP, FP, FN, precision and recall (NaN when undefined) |
| Export and replay | Package `mg-v2-runpkg/1.1` with the scene config and a **salted** SHA-256 commitment to the private features (salt kept only in the private evaluation file; fix F1, #134), never their positions. Replay uses recorded data and is never re-evaluated. A private evaluation file is written only on request, outside the package |
| V2 unchanged | `mgv2MissionControl` keeps the V2 world and V2 export `1.0` |

## 2. How to run it

```matlab
cd <clone of github.com/MdShabazS/MineGuard-MATLAB>
addpath('v2/matlab'); addpath('v2_1/matlab');
L = mgv21MissionControl;          % Mission Setup opens; LOCK & START opens the flight dashboard
```

Demonstration sequence:
1. Choose a preset.
2. Adjust the boundary and grid, and check the route preview.
3. Choose MANUAL and click targets on the map, or choose RANDOM with a count and seed.
4. Press LOCK & START. The markers disappear.
5. Press START SIMULATION and let the survey finish.
6. The EVALUATION VIEW opens with the results.
7. Optionally press EXPORT, then REPLAY.

Keep the MATLAB window in front: Windows slows background MATLAB.

## 3. Data separation

- **Public** (`pub`): preset, scene configuration, mission, environment and survey. It is used by the engine, sensors, detector, map and export.
- **Private** (`priv`): truth and surface features. It is held only by `RunController`, passed to the sensors as surface features, and to the evaluator after the run.
- **Firewall:** the live view, evidence context and operator package all pass `mgv21.scenario.assertPublic`, and no text file in a package contains a target coordinate. These are tested.

## 4. Evidence

**Final verification, at the F1 fix commit `ccb2f9e`** (clean tree, desktop MATLAB, Claude Code, no human watching). `main` `a9f6ad5` differs from it only in documentation and evidence:
- Full regression: V2 nine suites **305/305**, V2.1 seven suites **88/88**, checkcode 59 files 0 messages (`v2_1/evidence/V21-008/regression_ccb2f9e.txt`).
- Application check: **51/51** (`v2_1/evidence/V21-008/v21_demo_check_ccb2f9e.txt`). The four flights gave the same counts as below.

Earlier release verification, before the fix:

Release verification on a **fresh clone of `main` at `8188804`**, clean tree, desktop MATLAB (`v2_1/evidence/V21-release/release_tests_8188804.txt`). Run by Claude Code in Rahil's session; no human watched.

| Suite | Result |
|---|---|
| V2.1 Scenario / Placement / Evaluation (foundation) | 20 / 15 / 15 |
| V2.1 RuntimeSeam / RunController / SetupUI / EvaluationView | 9 / 9 / 12 / 7 |
| **V2.1 total** | **87/87** |
| V2 MissionEngine / MissionControlUI / ExportReplay (the suites the seam touches) | 22 / 73 / 21 = **116/116** |
| Application check: four full blind flights through the real windows, plus the V2 entry point (`v21_demo_check_8188804.txt`, 12 screenshots) | **51/51** |

The full V2 + V2.1 regression, 389/389, ran at `79c4537`, whose product code is identical to `main` (`v2_1/evidence/V21-008/regression_79c4537.txt`). Shabaz's foundation was verified separately at `b92eb9d` (46/46).

Demonstration flights, frozen detector, 1.0 m match radius:

| Flight | Targets | Events | TP | FP | FN |
|---|---:|---:|---:|---:|---:|
| MANUAL, ROCKY_UPLAND, 8 m lines, heading 0° | 4 (1 no-signature) | 38 | 0 | 38 | 4 |
| RANDOM seed 2101, DRY_FLATS | 8 (1 no-signature) | 26 | 0 | 26 | 8 |
| NONE, TRAINING_FIELD_A | 0 | 112 | 0 | 112 | 0 (recall undefined) |
| MANUAL, one no-signature target | 1 | 112 | 0 | 112 | 1 |

Every flight replayed exactly from its export (38/38, 26/26, 112/112 and 112/112 events), and every package passed the truth firewall. The results equal the earlier runs at `74fbe63`.

## 5. Scientific and performance limits

- **Detection:** the frozen V2-006 detector found **0 of 12** placed targets across four full Windows demonstration flights, with 26 to 112 false alarms per flight. This matches its negative V2-006 VALIDATION result (0 of 4). The synthetic true-positive fixtures in the tests check the software and are not detector evidence.
- **Scores:** uncalibrated. Georegistration uses the noise-free pose. Many events fall outside the survey boundary, because the detector has no boundary filter.
- **Speed:** unpaced full flights take about 200–250 s on this laptop. Paced 1× holds only when MATLAB is in front and the laptop is quiet (V2-008).
- **Shape and colour:** non-convex boundaries are refused (V2 planner). Presets cannot change soil colours.
- **Fixed after review:** F1, the unsalted export commitment found by Shabaz's Mac review (#132, limitation L1), fixed by #134.
- **Not done:** a Mac run, a human-witnessed V2.1 demonstration, and guide approval.

## 6. Tasks and pull requests

| Task | Owner | Status | Merged in |
|---|---|---|---|
| V21-001 contract | Shabaz | DONE | #122, status #127 |
| V21-002 scene/grid | Shabaz | DONE | #123, #127 |
| V21-003 placement | Shabaz | DONE | #124, #127 |
| V21-004 evaluation | Shabaz | DONE | #124, #127 |
| V21-005 setup UI | Rahil | DONE | #125, #128 |
| V21-006 runtime | Rahil | DONE | #126, #129 |
| V21-007 export/replay | Rahil | DONE | #126, #130 |
| V21-008 verification | Rahil | DONE | #126, #131 |
| F1 fix (V21-007) | Rahil | merged | #134; acceptance matrix #132 |

Merged by Rahil's Claude Code session under Shabaz's V2.1 release authorization, relayed by Rahil and not posted on GitHub by Shabaz. There was no second human review.
