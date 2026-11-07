# V2-007 Stage 3 final Mac verification and #91 review

SIMULATION ONLY. Contribution record, not task completion. Rahil owns V2-007 (IN_PROGRESS on `main`); no status changed. No TRAIN selection, VAL or TEST ran, no detector file or threshold changed, and `mgv2DetectorEquivalence` was not run. G07 VALIDATION remains 0 of 4. **Phase G remains BLOCKED: #91 is unreviewed by its required reviewer and not merged.**

**Execution SHA: `92f2c266e3a2fa52e03ce516c2d27d2661495a2d`.** Host: macOS 27.0.1, arm64, MATLAB 26.2.0.3433840 (R2026b Update 1). Local combination `38e89b4` = this code + #91 head `43da051` (disposable, never pushed).

Benchmarks ran at `ef09959` (combination `e39057c`). The only later change is event table columns and headings, so **benchmarks were not repeated at `92f2c26`**. Stage 2 is `57363dc`.

## Tests

| Tree | V2-002 | V2-003 | V2-005 | V2-006 | UI GUI | Bridge | Total | Failed / incomplete |
|---|---|---|---|---|---|---|---|---|
| `92f2c26` UI | 22 (at `ef09959`) | 22 (at `ef09959`) | 28 (at `ef09959`) | 28 (at `ef09959`) | 62 | - | **162/162** | 0 / 0 |
| `38e89b4` combination | - | - | - | 28 | 62 | 25 | **115/115** | 0 / 0 |

GUI tests ran in the desktop MATLAB with real windows. Detector fingerprint: `fnv1a64:d6d364f988f04bb4`, the same as Rahil's record. `checkcode` on `+mgv2/+ui`: 1 message, a stale suppression that predates this work.

Discarded, as harness faults and not evidence: "tamper refused" from `fUse` (a syntax error in the script), "pause handled 1 ms" (timed only the handler), and one timed-out call with no results.

## Host state

TeamViewer stayed at 0-1% CPU in all samples and was not touched by me. **The host was not idle.** A `qemu` VM reached 690%, `java` 332% and load 27, none under my control. Power switched between battery and AC during the session. Load includes MATLAB itself (about 250-380%). Samples every 10 s: `host-load-samples.csv`; per-run lines: `benchmark-log.txt`.

A "refresh" is a scene update plus synchronous `drawnow`. **Displayed FPS was not measured.** Dropped means scene frames dropped; no simulation tick or sensor sample was dropped. Every mission reached COMPLETE with 2799 ticks and 3080 samples at 5, 5, 2 and 10 Hz.

## Set 1: order fixed, no load control. **INCONCLUSIVE**

Load and version are confounded: the two best Stage 2 runs were the only runs in this group with `qemu` idle.

| Config | Sim/wall | Refreshes/s | Gap p95 (ms) | Worst gap (ms) | Dropped | Mean load |
|---|---|---|---|---|---|---|
| Stage 2 | 1.000, 1.000, 1.000 | 9.71, 9.94, 9.93 | 197, 194, 194 | 456, 253, 286 | 43, 11, 11 | 6.24, 5.42, 4.95 |
| Stage 3 | 1.000, 1.000, 0.894 | 8.40, 9.22, 7.06 | 213, 180, 333 | 594, 428, 767 | 226, 111, 295 | 6.34, 6.25, 5.88 |
| R20 | 0.828, 0.845, 0.757 | 4.15, 4.24, 3.80 | 573, 600, 641 | 1848, 807, 1704 | 699, 698, 698 | 15.57, 10.02, 6.50 |
| R100 | 0.995, 0.910, 0.772 | 6.61, 4.57, 3.90 | 265, 339, 507 | 822, 1095, 1797 | 472, 698, 695 | 7.74, 8.77, 11.12 |

## Set 2: gated. Controlled at start, not a clean-host result

Each mission started only after outside CPU stayed under 150% for 30 s, waiting at most 5 minutes (`gate-log.txt`). The gate does not hold during a run. g2 failed the gate and ran anyway, as recorded. Order ABBAAB in each group.

| Config (runs) | Sim/wall | Refreshes/s | Render p50 (ms) | Gap p95 (ms) | Worst gap (ms) | Dropped | Max behind (s) | Mean load | Mean qemu % |
|---|---|---|---|---|---|---|---|---|---|
| Stage 2 (g1, g4, g5) | 1.000 x3 | 9.56, 9.63, 9.57 | 54.4, 53.0, 53.7 | 193, 195, 191 | 297, 478, 281 | 64, 54, 62 | 0.31, 0.40, 0.21 | 6.55, 6.30, 4.46 | 24, 17, 0 |
| Stage 3 (g2, g3, g6) | 1.000 x3 | 8.96, 9.13, 9.41 | 55.6, 54.1, 59.9 | 201, 188, 177 | 713, 326, 310 | 148, 123, 84 | 0.79, 0.52, 0.31 | 7.56, 8.93, 4.16 | 159, 106, 0 |
| R100 (g7, g10, g11) | 1.000, 1.000, 0.988 | 7.70, 6.67, 6.40 | 62.0, 67.8, 69.5 | 217, 235, 250 | 860, 836, 828 | 324, 468, 494 | 1.20, 3.04, 4.60 | 4.97, 4.66, 5.31 | 0 |
| R20 (g8, g9, g12) | 0.854, 0.861, 0.843 | 4.83, 4.58, 4.68 | 77.0, 75.2, 73.1 | 599, 614, 678 | 766, 941, 927 | 610, 657, 624 | 24.4, 23.2, 26.6 | 4.87, 5.54, 5.78 | 0 |

Detector rebuilds: R100 median 281-313 ms, max 544-624 ms, 29 per mission. R20 median 281-291 ms, max 592-690 ms, 140-141 per mission.

**Stage 2 versus Stage 3.** Both hold 1× with all data intact. The only pair with `qemu` idle (g5, g6) gives 9.57 against 9.41 refreshes/s, 62 against 84 drops, gap p95 191 against 177 ms, worst 281 against 310 ms. So Stage 3 appears to cost a small refresh rate while gaps at p95 are similar or better, **from one comparable pair**. A Stage 3 cost larger than this under outside load cannot be ruled out, and the rest of the Stage 3 runs carried more `qemu` load.

## Acceptability with the detector, Mac

| Question | R100 | R20 |
|---|---|---|
| 0.8× minimum, gated | **Met 3 of 3** (0.988-1.000) | **Met 3 of 3** (0.843-0.861) |
| 1× goal, gated | Met or within 1.2% | **Not met** |
| 0.8×, uncontrolled load | 2 of 3 | 2 of 3 |
| Event age, largest gap between rebuilds | 5.05-5.20 s | 1.05-1.20 s |
| Refreshes/s against the 10/s target | **Missed**, 6.40-7.70 | **Missed**, 4.58-4.83 |
| Worst visible hold | 828-860 ms | 766-941 ms |

- **Repeatability:** 0.8× is repeatable only while outside load stays low. It is **not** repeatable under the heavy outside load seen in Set 1. A Mac demo needs that load kept off.
- **Freshness:** R100 can show events about 5 s old. The age is displayed, and its colour flags above 5 s, so it may flicker to the stale colour just before each rebuild. R20 is much fresher but runs 15% behind the clock and falls up to 27 s behind. Choosing between them is a decision for Shabaz and Rahil; the measurements favour R100.
- **Rendering:** usable but visibly uneven. Holds near 0.8-0.9 s follow rebuilds, and a third to two-thirds of scene frames are dropped.
- **Interaction, one 1400-tick run each at `e39057c`:** event-loop lateness R100 p50 87, p95 226, max 920 ms; R20 p50 93, p95 212, max 844 ms. Click-to-evidence while paused: 81 and 15 ms at `38e89b4`. While running it can include a rebuild and was not measured separately.
- **No person judged the dashboard.** These are measured engineering checks, not a user acceptance result.

## Real detector checks at `38e89b4`, through a scratch subclass using the accessor

Plain launch, no `bindSession`: 79-82 events at tick 2201, table click, 4 verified records, a thermal crop and "RGB evidence: none". Tampered log refused with `mgv2:EvidenceMismatch` and no crops shown (at `e39057c`). After reset: old accessor `mgv2:StaleSensorLog`, old id `mgv2:EventNotFound`, selection cleared, 0 rows, 0 events. Thermal dropout scenario, 1400 ticks: all 151 thermal samples in 10-40 s invalid with `SENSOR_DROPOUT`, 0 refused, 25 events including single-channel bases. **Unmodified #91, plain launch:** the inspector shows `EVIDENCE NOT AVAILABLE`, as Rahil's PR states, with no substitute.

The default scene has no scenario targets, so it is a target-free run in that sense. **84 events on it are not correct detections; they show the false-alarm behaviour already on record.**

## Independent review of #91 and the #85 changes

**No blocker found in the bridge's operational files.** Read and tested at `43da051`; this does not replace the required human review.

| # | Finding | Severity | Owner |
|---|---|---|---|
| 1 | `inspect` needs a sensor log, so a plain launch cannot show evidence. Patch below | Must fix for UI-09 | Rahil, with UI seam from this branch |
| 2 | Default `RefreshTicks=20` misses 1× and is what a plain launch uses | Decision needed | Shabaz, Rahil |
| 3 | `bindSession` then becomes redundant, and reading `Session.Sensors.Log` should go with it | Clean-up | Rahil |
| 4 | `inspect` calls `rebuild` while running, so a click can stall for a rebuild | Note, measure | Rahil |
| 5 | `mgv2DetectorEquivalence` calls `mgv2.eval.buildScenario` on permitted TRAIN and DEMO groups without requesting truth, and `mgv2PerfProfile` reads private detector data through `struct()`. Neither is on the app path, but both sit in the operational folder | Move or label, with science review | Rahil, Shabaz |
| 6 | #91 brings about 60 #85 evidence and tool files; the Windows figures used forced high QoS | Reviewer should separate them | Rahil |

Checked and sound: no change under `+ui`, `+detect`, `+map`, `v2/data` or status; terminal phases match the engine; memo skips only the contract scan, on an exact `isequaln` match, and always repeats run and evidence checks; no truth in the operational bridge files; `events_as_of_tick` changes with output; no personal data found by search in the diff. #86 was not used. **Equivalence of the #85 read-path changes to frozen outputs was not rerun here,** and the detector itself is unchanged by #91.

## Source changes since the last record

- `AnomalySource`: optional `bindSensorLog(logFcn)`.
- `MissionSession`: `RunGeneration`, `readSensorLog`, and an independent check of every evidence record against the current run's log.
- `EventInspectorPanel`: columns and two-line headings. The earlier width change claimed whole ids but still clipped them, and this corrects it.
- Two new GUI tests and test double support.

## Not run or not met

Windows on this head. Displayed FPS. A clean idle host. INT-12 and all of Phase G. RGB evidence crop on the real detector (the inspected event had thermal evidence only). A person using the dashboard.

## Screenshots

`integrated-*` are real detector, local combination `38e89b4`. `event-table-normal-size-TEST-DOUBLE.png` uses arbitrary test-double values at `92f2c26`. Earlier screenshots in the parent folder predate the table correction.
