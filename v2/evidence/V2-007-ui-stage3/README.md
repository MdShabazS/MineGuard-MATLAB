# V2-007 UI Stage 3 on the Mac (contribution record, not task completion)

Task: V2-007 (owner Rahil; this branch makes no status change. `main` moved V2-006 to DONE and V2-007 to IN_PROGRESS through PRs #88 and #89 during this work). Executed by Claude Code (Opus 5.5) through the MATLAB MCP Server on Shabaz's Mac.
**Execution SHA: `043a8969fd74a3f1aca83ffb377f8e12e8e5e24e`** (clean tree). Later commits on the branch are evidence only.
Host: macOS 27.0.1, Apple Silicon (arm64), MATLAB R2026b Update 1, UAV Toolbox 26.2. Display theme tests cover both desktop themes.

SIMULATION ONLY. Events are SUSPECTED with uncalibrated scores. The frozen VALIDATION result remains negative (G07: 0 of 4). No TRAIN selection, VAL or TEST study ran, and no detector file or threshold changed. PRs #85 and #86 were not used.

## Results at a glance

| Item | Result |
|---|---|
| UI-only regression at the execution SHA | **160/160 PASS**, 0 failed, 0 incomplete |
| Local bridge combination | **107/107 PASS**, not a pushed or accepted integration |
| UI-only full mission, paced 1x | COMPLETE, x0.997 to x1.000 in 3 runs |
| **Integrated full mission, paced 1x, TeamViewer closed** | COMPLETE, x1.000, x1.000, x0.610 in 3 runs; the x0.610 run had load up to 21 from outside MATLAB |
| Refreshes per second, UI only, TeamViewer closed | **9.91 to 9.99 (just under the 10/s schedule)** |
| Refreshes per second, integrated, TeamViewer closed | **3.07 to 8.22: the 10/s target is missed** |

The tables below keep the earlier contended runs as history. The [TeamViewer-closed rerun](#rerun-with-teamviewer-closed) is the latest measurement.

## Tests

Commands: `addpath('v2/matlab','v2/matlab/tests'); runtests('v2/matlab/tests/<suite>.m')`

| Suite | Tests | Passed | Failed | Incomplete |
|---|---|---|---|---|
| V2-002 | 22 | 22 | 0 | 0 |
| V2-003 | 22 | 22 | 0 | 0 |
| V2-005 | 28 | 28 | 0 | 0 |
| V2-006 (merged on `main`) | 28 | 28 | 0 | 0 |
| V2-007 UI (38 + 22 new) | 60 | 60 | 0 | 0 |
| **Total** | **160** | **160** | **0** | **0** |

The 22 new UI tests use `V2007TestDoubleSource` where events are involved. **The test double is not a detector, and those results are UI-only.** One existing test now accepts a temperature range after the status text.

Local combination `54f6907` (this code + `main` + unmodified bridge `7e89e70`, in a scratch worktree, never pushed): V2-006 28/28, UI 60/60, bridge 19/19.

Earlier commit `5164885` failed its UI suite (3 of 60 passed) because of a coding error in the coverage key. It was never pushed and was fixed in `7984ba5`.

## Features added

- **Thermal:** palette and K / deg C selectors. They apply at once, also while paused, and change only the display. A range readout was added.
- **Map:** Terrain, Boundary, Planned, Traversed, Footprint, Coverage and Suspected toggles. Coverage and Suspected stay disabled until a source provides them. Coverage sits under the routes, with a colour key.
- **Sensor states:** the image itself says NO SAMPLE YET, STALE or NO VALID ..., with the reason.
- **Expanded inspection:** every panel can fill the window and be restored. Hidden panels keep receiving every view.
- **Mission:** scenario (As launched, Low contrast, Overcast, Thermal dropout) and mission seed, before START only. Reset keeps both. Seed changes sensor noise (6.57 m navigation difference at tick 60) but not the true path, the world or the plan.
- **REPLAY and EXPORT:** visible, disabled, labelled V2-008. They do nothing.
- **Event inspector:** row or map-marker selection by public `event_id`, position, uncertainty, score, sensors, missing modalities, timestamps and verified crops. Failures are shown, with no image in their place.

## Defects found and fixed

Real renders exposed the first three, after property checks had passed. A test exposed the fourth.

| Defect | Fix |
|---|---|
| Scene and thermal header dropdowns squashed, Expand buttons hidden | Fixed tool row, plus a test on rendered sizes |
| Coverage key swatches rendered without colour, so states could not be told apart | Real coloured chips, tested against the state colours |
| Event id and status clipped at normal size | Column widths and two-decimal format |
| Coverage drawn over routes | Stacked directly above the terrain |

## Performance

A refresh is a scene update plus a synchronous `drawnow`. **Displayed screen FPS was not measured.** Startup was not separately benchmarked in this stage.

**These runs were contended, so absolute numbers are not comparable with the earlier record.** TeamViewer, screen capture (`replayd`) and other apps were active, with load averages of 6 to 7. The earlier 9.97 refreshes/s record is not reproduced here, and neither is it refuted for a quiet host. Old and new code fell by similar amounts.

Paced 1x, visible 1440x880, no detector, alternating order. A = `7e52523`, B = `a17e4da`. Commits after B changed only the coverage key, which is not shown without a source, and the event table.

| Metric | A runs | B runs |
|---|---|---|
| Sim/wall | 1.000, 0.988, 1.000 | 1.000, 1.000, 0.997 |
| Refreshes/s | 7.04, 8.12, 5.81 | 6.29, 8.52, 5.92 |
| Render p50 (ms) | 81.3, 66.8, 94.0 | 85.5, 60.5, 90.0 |
| Render p95 (ms) | 130.9, 114.5, 146.4 | 128.1, 120.6, 129.9 |
| Render max (ms) | 225, 249, 223 | 211, 220, 294 |
| Gap p95 (ms) | 232, 213, 256 | 249, 226, 254 |
| Worst gap (ms) | 339, 638, 358 | 358, 370, 385 |
| Gaps over 250 ms | 30, 22, 48 | 42, 39, 46 |
| Scene frames dropped | 416, 250, 588 | 521, 209, 570 |
| Max behind clock (s) | 1.38, 2.17, 1.98 | 0.68, 3.18, 1.58 |
| Sensor generation total (s) | 42.9, 42.0, 46.5 | 48.1, 37.3, 49.5 |
| Engine total (s) | 12.9, 12.2, 13.8 | 13.8, 11.4, 14.1 |
| `drawnow` total (s) | 76.9, 76.2, 73.4 | 70.2, 72.0, 70.2 |

The spread within each version is larger than the difference between them, so no regression or improvement can be claimed from these runs. The whole-mission rate meets 60 simulated seconds in 75 wall seconds. Windows within the mission were not checked separately.

**Integrated, real detector through the bridge at `RefreshTicks=100`, paced 1x, one run per row, also contended:**

| Code | Sim/wall | Refreshes/s | Gap p95 (ms) | Worst gap (ms) | Dropped | Max behind (s) | Rebuild med / max (ms) |
|---|---|---|---|---|---|---|---|
| Old UI `7e52523` | 0.680 | 3.41 | 528 | 2191 | 699 | 66.9 | 549 / 880 |
| Stage 3 `a17e4da` | 0.747 | 3.75 | 453 | 2636 | 699 | 48.3 | 508 / 1482 |
| Stage 3 `a17e4da` | 0.764 | 3.84 | 536 | 1830 | 698 | 46.7 | 474 / 822 |
| Stage 3 `7984ba5` | 0.810 | 4.16 | 371 | 1764 | 683 | 34.0 | 389 / 784 |
| Stage 3 `043a896` | 0.660 | 3.41 | 499 | 1934 | 677 | 72.9 | 410 / 791 |

**This is a FAIL of the 0.8 minimum on this host state, not a pass.** It is single-run data, not the 3-run comparison issue #76 requires. The later TeamViewer-closed rerun answers this for the Mac. Every run kept all 2799 ticks and 3080 samples and dropped display frames only. With the clock this far behind, the display is not usable as a live 1x demonstration.

**Reliability at the execution SHA:** 6 run, abort and reset cycles gave identical checksums, a reset median of 1.76 s (max 1.87 s, this blocks the window), graphics objects constant at 17, and process memory 1835 MB to 1594 MB with no growth. After 5 more launches: 0 figures, 0 timers. Sensor rates and timestamps are covered by the V2-005 and UI tests. Dashboard memory during a full integrated mission was not profiled.

## Rerun with TeamViewer closed

Same code: A = `7e52523`, B = `043a896`. Integrated runs used scratch commits `3088079` and `c6aecd7` (each with unmodified bridge `7e89e70`, never pushed). Order: ABBAAB in each group. Two earlier sets were interrupted by laptop restarts and were discarded, without being used here. Raw data: [quiet-host-benchmark-log.txt](quiet-host-benchmark-log.txt) and, every 10 s, [quiet-host-load-samples.csv](quiet-host-load-samples.csv).

Measured host load: TeamViewer 0% in every sample, and no TeamViewer process afterwards. **The host was still not idle:** `replayd` was running, and Codex at the start. Load includes MATLAB itself (about 240-345% CPU). After the runs, a `qemu` virtual machine and `next-server` were seen; when they began was not recorded.

| Run | Code | Load mean (max) | Sim/wall | Refreshes/s | Render p50 / p95 / max (ms) | Gap p95 / worst (ms) | Dropped | Max behind (s) |
|---|---|---|---|---|---|---|---|---|
| u1 | UI A | 5.38 (6.45) | 1.000 | 9.96 | 47.0 / 70.8 / 136 | 138 / 199 | 7 | 0.18 |
| u4 | UI A | 4.73 (6.83) | 1.000 | 10.01 | 46.6 / 68.9 / 125 | 141 / 198 | 1 | 0.14 |
| u5 | UI A | 6.29 (9.18) | 1.000 | 9.75 | 48.8 / 80.3 / 273 | 153 / 401 | 37 | 0.61 |
| u2 | UI B | 5.25 (7.04) | 1.000 | 9.99 | 46.7 / 67.2 / 116 | 140 / 220 | 4 | 0.16 |
| u3 | UI B | 5.18 (6.38) | 1.000 | 9.98 | 45.4 / 66.6 / 120 | 136 / 231 | 5 | 0.22 |
| u6 | UI B | 6.97 (8.79) | 1.000 | 9.91 | 48.7 / 78.0 / 145 | 147 / 297 | 15 | 0.27 |
| i1 | Int A | 5.20 (6.28) | 1.000 | 7.76 | 59.8 / 107.4 / 814 | 218 / 936 | 315 | 2.25 |
| i4 | Int A | 5.37 (6.61) | 0.986 | 6.33 | 70.9 / 125.3 / 2461 | 265 / 2471 | 503 | 4.48 |
| i5 | Int A | 7.95 (9.10) | 0.918 | 4.60 | 87.1 / 273.2 / 879 | 474 / 1025 | 699 | 14.56 |
| i2 | Int B | 5.18 (6.22) | 1.000 | 8.22 | 54.3 / 87.1 / 692 | 201 / 803 | 251 | 1.05 |
| i3 | Int B | 6.19 (6.89) | 1.000 | 6.60 | 69.5 / 126.7 / 775 | 243 / 856 | 478 | 1.54 |
| i6 | Int B | **15.36 (21.43)** | **0.610** | 3.07 | 103.2 / 538.0 / 1147 | 806 / 2716 | 698 | 93.55 |

All 12 missions reached COMPLETE with 2799 ticks and 3080 samples. All 6 integrated runs had 84 events, 0 refused samples, 2800 poses and one subscription. Rebuild median 288-526 ms, largest 2327 ms (i4).

**Reading.**
- UI only: Stage 3 shows no slowdown. It holds x1.000 at 9.91-9.99 refreshes/s, just under the 10/s schedule.
- Integrated: B holds x1.000 at load near 5-6 (i2, i3), and 5 of 6 integrated runs meet the 0.8 minimum. **i6 fails it (x0.610) and is kept in the record.** Its load was about three times that of i2 and i3, but that association does not prove the cause; i6 alone cannot separate load from code.
- **All integrated runs miss 10 refreshes/s, with drops of 251-699 frames and gaps of 803-2716 ms.** Rebuild stalls are visible in the worst gaps. The detector's events can also be up to 5 simulated seconds old at this interval.
- INT-10: **PARTIAL on the Mac, FAIL under heavy load, Windows NOT RUN.** Displayed FPS was not measured.

## Rerun with host load logged (added after the first record; earlier tables are kept)

Same code: A = `7e52523`, B = `043a896` (integrated: each merged with unmodified bridge `7e89e70` in scratch worktrees). Raw lines, including load and TeamViewer CPU before and after each mission: [rerun-benchmark-log.txt](rerun-benchmark-log.txt).

TeamViewer restarted with the laptop and moved between about 0% and 45-65% CPU on its own. **Only u5 and u6 had it at 0% throughout. No integrated run was clean, and i1 was clean only at its start.** Load stayed around 5 to 8 during runs, so even u5 and u6 are not an idle host.

| UI only, 1x | TeamViewer | A | B |
|---|---|---|---|
| Clean pair (u5, u6) | 0% | x1.000, 9.80/s, gap p95 155 ms, worst 244 ms | x1.000, 9.84/s, gap p95 154 ms, worst 233 ms |
| Contended (u1 to u4) | 46-60% | x1.000, 9.40 and 8.40/s | x1.000, 6.85 and 6.88/s |

| Integrated, `RefreshTicks=100`, 1x, 3 runs each | A | B |
|---|---|---|
| Sim/wall | 0.980, 0.701, 0.848 | 0.641, 0.798, 0.835 |
| Refreshes/s | 4.94, 3.52, 4.26 | 3.22, 4.01, 4.20 |
| Worst gap (ms) | 1247, 1685, 1071 | 1886, 1322, 970 |
| Max behind clock (s) | 9.0, 60.3, 26.7 | 79.4, 36.3, 29.4 |
| Rebuild median / max (ms) | 385-479 / 648-936 | 448-512 / 760-958 |

All 12 missions reached COMPLETE with 2799 ticks and 3080 samples. All 6 integrated runs had 84 events, 0 refused samples, 2800 poses and one subscription.

**Reading.** UI only, the clean pair shows no Stage 3 slowdown and is close to the 10/s schedule, but it is one pair. Contended, B was slower than A in u1 to u4, so sensitivity to load cannot be ruled out. Integrated, **the 0.8 minimum was missed in 1 of 3 A runs and 2 of 3 B runs**, and the 10 refreshes/s target was missed in all. B's mean is lower (0.758 against 0.843), but the runs were contaminated and overlap, so a Stage 3 integrated regression is **neither shown nor excluded**. INT-10 was **FAIL at that host state**; the TeamViewer-closed rerun above supersedes this reading.

## Integrated observations (local combination, simulated)

84 SUSPECTED events, all in the session's run, 0 rejected. 3080 samples, 0 refused. 2800 poses for ticks 0 to 2799, exactly once, one subscription. Reset gave tick 0, 0 events and an empty table. Final coverage cells: 11072 VALID OBSERVED, 8528 UNOBSERVED. Inspecting SUS-00006 showed 4 verified records, a thermal crop and "RGB evidence: none". This scene has no targets from a scenario, so **these events say nothing about detection and are not correct detections**.

The bridge subscribes to poses and binds itself, so the new `bindRun` and `onPose` paths have been exercised only by the test double.

## Requirement status

| Case | Status | Note |
|---|---|---|
| UI-01 start, UI-02 flight | PASS (UI) | Full mission to COMPLETE |
| UI-03 camera views | PASS (UI) | Zoom is camera-mode based; no free mouse orbit test |
| UI-04 map | PASS (UI) | Time-correct surveyed area shown only with a source |
| UI-05 layers | PARTIAL | Coverage, suspected, terrain and routes. No temperature or LiDAR map layer |
| UI-06 RGB, UI-07 thermal, UI-08 LiDAR | PASS (UI) | |
| UI-09 event selection | PASS with test double; **real detector shown locally through `selectEvent`** | The table click is exercised through its callback. Bridge not reviewed |
| UI-13 labels | PASS (UI) | Permanent banner, SUSPECTED only |
| INT-01, INT-02 | PASS locally through the bridge's own binding | Bridge review pending |
| INT-03, INT-04, INT-05 | PASS locally | Same condition |
| INT-06 click-through with tamper | **Not run on real detector**; tamper cases pass with the test double | |
| INT-07 reset, INT-11 bounded view | PASS locally | |
| INT-08, target-free and missing-sensor with detector | **NOT RUN** | UI-only dropout passes |
| INT-09 themes | PASS (UI) on real renders from the theme test | Contrast of new controls not separately measured |
| **INT-10, AC-025 integrated performance** | **PARTIAL: 5 of 6 Mac runs meet 0.8, one fails at load 15; 10/s missed; Windows NOT RUN** | See the TeamViewer-closed rerun |
| INT-12, Phase G final acceptance | **BLOCKED** | Rahil's bridge has no PR or review, and still uses its own binding |
| Windows | **NOT RUN** | |

## Known limitations

- Images and map draw one tick after their sample, so the UAV can sit about 0.3 m ahead of the footprint.
- A selected event's evidence is fetched once per selection, and the bridge's `inspect` can stall for a rebuild.
- Map markers can overlap, and a click picks the nearest listed event.
- No person clicked the controls; tests press real buttons or call their callbacks.
- Replay and export are not implemented (V2-008).

## Contracts and dependency

See [UI_INTEGRATION_CONTRACT.md](UI_INTEGRATION_CONTRACT.md).

## Screenshots (real MATLAB exports)

`ready-wide`, `paused-wide-celsius-turbo`, `expanded-lidar`, `compact-960x640`, `dropout-thermal`, `mission-complete` are UI-only at the execution SHA. `event-inspection-TEST-DOUBLE` uses arbitrary test-double values. `integrated-*` come from the local combination `54f6907` with the real detector.
