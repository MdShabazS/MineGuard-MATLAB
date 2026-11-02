# V2-007 UI Stage 3 on the Mac (contribution record, not task completion)

Task: V2-007 (owner Rahil; status unchanged, `TODO` on `main`). Executed by Claude Code (Opus 5.5) through the MATLAB MCP Server on Shabaz's Mac.
**Execution SHA: `043a8969fd74a3f1aca83ffb377f8e12e8e5e24e`** (clean tree). Later commits on the branch are evidence only.
Host: macOS 27.0.1, Apple Silicon (arm64), MATLAB R2026b Update 1, UAV Toolbox 26.2. Display theme tests cover both desktop themes.

SIMULATION ONLY. Events are SUSPECTED with uncalibrated scores. The frozen VALIDATION result remains negative (G07: 0 of 4). No TRAIN selection, VAL or TEST study ran, and no detector file or threshold changed. PRs #85 and #86 were not used.

## Results at a glance

| Item | Result |
|---|---|
| UI-only regression at the execution SHA | **160/160 PASS**, 0 failed, 0 incomplete |
| Local bridge combination | **107/107 PASS**, not a pushed or accepted integration |
| UI-only full mission, paced 1x | COMPLETE, x0.997 to x1.000 in 3 runs |
| **Integrated full mission, paced 1x** | COMPLETE, **x0.66 to x0.81 in 4 runs under host load: below the 0.8 minimum in 3 of 4** |
| Refreshes per second, UI only, this load | **5.9 to 8.5, not 10** |

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

## Defects found by looking at real renders

Property checks had passed for the first two.

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

**This is a FAIL of the 0.8 minimum on this host state, not a pass.** It is single-run data, not the 3-run comparison issue #76 requires. Whether a quiet Mac reaches 0.8 at this head is **NOT RUN**; an earlier quiet run of older code reached x1.000. Every run kept all 2799 ticks and 3080 samples and dropped display frames only. With the clock this far behind, the display is not usable as a live 1x demonstration.

**Reliability at the execution SHA:** 6 run, abort and reset cycles gave identical checksums, a reset median of 1.76 s (max 1.87 s, this blocks the window), graphics objects constant at 17, and process memory 1835 MB to 1594 MB with no growth. After 5 more launches: 0 figures, 0 timers. Sensor rates and timestamps are covered by the V2-005 and UI tests. Dashboard memory during a full integrated mission was not profiled.

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
| **INT-10, AC-025 integrated performance** | **FAIL at this host state; 3-run NOT RUN** | |
| INT-12, final acceptance | **BLOCKED** | Needs Rahil's reviewed adapter |
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
