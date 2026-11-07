# V2-007 UI contribution, Stage 1 (not task completion evidence)

Task: V2-007 (owner Rahil; state unchanged). This is a contribution record, not `v2/evidence/V2-007.md`.
Contributor: Shabaz. Executed by Claude Code (Opus 5.5) through the MathWorks MATLAB MCP Server on Shabaz's Mac; Shabaz's human review is pending.
Environment: macOS 27.0.1, MATLAB R2026b Update 1 (26.2.0.3433840), UAV Toolbox 26.2.
Code under test: `ec62a0a4f7c6aea07206c4801a74f29ee495e344`. Seed 2002, scenario run `V2RUN-NOMINAL-0001`.
SIMULATION ONLY: synthetic sensors on a synthetic scene. No detection capability is shown or claimed.

## Commands

    addpath('v2/matlab'); mgv2MissionControl
    runtests('v2/matlab/tests/testV2007MissionControlUI.m')

## Test results (one run, clean tree at the SHA above)

| Suite | Tests | Passed | Failed | Incomplete | Time |
|---|---|---|---|---|---|
| testV2002MissionEngine | 22 | 22 | 0 | 0 | 2.5 s |
| testV2003Scene | 22 | 22 | 0 | 0 | 44.8 s |
| testV2005Sensors | 28 | 28 | 0 | 0 | 105.9 s |
| testV2007MissionControlUI | 25 | 25 | 0 | 0 | 181.7 s |
| **Total** | **97** | **97** | **0** | **0** | 335.0 s |

After the run: 0 figures and 0 timers left. The UI tests open visible windows and use real `press` and `choose` gestures.
Display assertions compare graphics data with the sample the sensors produced.

## Measured performance (full mission, visible 1440x880 window, 139.95 s simulated, 2799 ticks, 702 refreshes)

| Measure | RealTime = 1 | RealTime = 0 |
|---|---|---|
| Wall time / sim-to-wall | 139.90 s / 1.000 | 101.17 s / 1.383 |
| Refreshes per wall second | 5.02 | 6.94 |
| Frame median / p95 / max | 66.7 / 105.1 / 2813.1 ms | 74.8 / 112.7 / 2088.2 ms |
| `drawnow` median / p95 / max | 61.9 / 97.6 / 2789.1 ms | 69.7 / 106.0 / 2073.8 ms |
| Panel update code median / p95 | 4.6 / 10.2 ms | 5.1 / 6.6 ms |
| Engine and sensor tick median / p95 / max | 1.5 / 59.9 / 125.9 ms | 1.2 / 65.8 / 150.5 ms |
| Frames over 100 ms | 50 | 52 |
| Pacing checks over 50 ms behind | 733 | not applicable |

Frame time is refresh code plus a blocking `drawnow`; it is not a measured screen frame rate. One run per mode on one host.
These are observations, not an acceptance result. The >= 10 FPS scene target (AC-025 table) is not met: refresh is
every 4 ticks by default and the unpaced capacity measured here is 6.94 per wall second. Single stalls of 2 to 3 s occurred.
The 60 s in 75 s target was not measured separately; the full mission finished at 1.000 when paced.

## Screenshots (exportapp, this folder)

- `stage1-wide-t0-configured.png`: tick 0; LiDAR on the pad labelled INVALID OUT_OF_RANGE
- `stage1-wide-survey.png`: t = 45 s, SURVEY
- `stage1-wide-complete.png`: full mission, COMPLETE
- `stage1-compact-survey.png`: 960x640 compact layout (scrolling content, banner fixed)
- `stage1-wide-sensor-dropout.png`: configured RGB and thermal dropout, no invented data

## Limitations

- Rahil's `+mgv2/+map/` is not on `origin` or in this checkout, so it was not inspected or integrated. Map overlays and events are tested only with a test double.
- Automated 3-D checks cover the aircraft transform, terrain mesh and a non-blank view, not visual quality.
- Not implemented in Stage 1: evidence crops, event selection, fullscreen panels, Celsius display, replay, export, and coverage (V2-006).
- Battery shows NOT MODELLED. Windows was not run.
- `SceneRenderer` figure annotations are hidden by `ScenePanel`, because they would overlay other panels. The perspective scene also draws beyond its axes, so the panel header has an opaque background.
