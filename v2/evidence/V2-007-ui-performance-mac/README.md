# V2-007 UI performance on the Mac (contribution record, not task completion)

Task: V2-007 (owner Rahil; status unchanged). No detector integration. Executed by Claude Code (Opus 5.5) through the MATLAB MCP Server on Shabaz's Mac (macOS 27.0.1, R2026b Update 1); human review pending.
Baseline A: `57363dcae315015cb759eb9c50b629c00bca90bc` (PR #67). **Execution SHA B: `2e96a83ce1fa6f93a4c3598ad60de27766835fad`.** This evidence is a later commit.
SIMULATION ONLY. A "refresh" is a scene update plus a synchronous `drawnow`. **Displayed screen FPS was not measured.**

## Tests at the execution SHA (one run, clean tree)

| Suite | Tests | Passed | Failed | Incomplete |
|---|---|---|---|---|
| V2-002 | 22 | 22 | 0 | 0 |
| V2-003 | 22 | 22 | 0 | 0 |
| V2-005 | 28 | 28 | 0 | 0 |
| V2-007 UI (35 + 3 new) | 38 | 38 | 0 | 0 |
| **Total** | **110** | **110** | **0** | **0** |

The baseline passed 107/107 before any change. Four existing tests changed because frames moved to odd ticks: the tick-sequence, pause-tick and sensor-label expectations in `sceneRunsFasterThanSensorPanels` and `pauseButtonFreezesAndResumeContinues`.

## What profiling found

Full visible mission at 1x, baseline: `drawnow` 59-60 s, sensors 29 s, engine 9-10 s, panel code 3.6 s (of 139.9 s wall).

| Candidate | Finding | Action |
|---|---|---|
| Sensor generation and full-panel drawing on the same tick | Gaps of 162 ms into that frame, 33 ms after it | **Fixed** |
| Light-desktop appearance | White table and buttons in a dark layout | **Fixed** with a fixed figure theme |
| Status labels in `'fit'` rows | Within noise | Not changed |
| Axes interaction settings | Within noise | Not changed |
| Axes position constraint | Within noise; MATLAB warns in a grid | Not changed |
| Camera re-render | Largest scene cost; about 27 ms scene-only `drawnow` | Not changed; would need renderer or terrain changes |
| JVM garbage collection | 0.00 s in every run | None needed |

The fixed-row, interaction and constraint comparison is one round of 600 ticks, because the second round stopped on a scratch script error; treat it as indicative.

## Change

Frames now fall on odd ticks, so sampling ticks carry no drawing. Images and map draw one tick after their samples; telemetry, LiDAR, events and clock labels draw half a period later. A status frame dropped while behind returns on the next sensor frame. The dashboard's figure theme is fixed to dark.

## Before and after (full mission, 139.95 s simulated, visible 1440x880 window, alternating order, 3 runs each)

**Paced 1x**

| Metric | A: Stage 2 | B: this branch |
|---|---|---|
| Sim/wall | 1.000, 1.000, 1.000 | 1.000, 1.000, 1.000 |
| Scene refreshes per wall s | 9.90, 9.95, 9.96 | 9.97, 9.98, 9.97 |
| Render p50 (ms) | 46.2, 45.6, 45.3 | 49.8, 49.7, 48.3 |
| Render p95 (ms) | 74.8, 73.1, 74.7 | 67.8, 70.0, 71.1 |
| Render max (ms) | 152.3, 147.7, 120.5 | 159.9, 150.1, 190.7 |
| Gap p50 (ms) | 113.1, 107.9, 111.6 | 99.4, 99.4, 99.8 |
| Gap p95 (ms) | 198.1, 192.4, 191.5 | **136.9, 136.9, 137.2** |
| Worst gap (ms) | 326.2, 320.3, 283.2 | **200.4, 219.6, 227.0** |
| Gaps over 250 ms | 1, 1, 1 | 0, 0, 0 |
| Late pacing checks | 616, 512, 550 | **92, 72, 86** |
| Scene frames dropped | 16, 9, 7 | 6, 5, 6 |
| Max behind clock (s) | 0.272, 0.233, 0.205 | 0.205, 0.170, 0.212 |

**Unpaced (capacity)**

| Metric | A: Stage 2 | B: this branch |
|---|---|---|
| Sim/wall | 1.302, 1.314, 1.300 | 1.245, 1.226, 1.243 |
| Scene refreshes per wall s | 13.04, 13.15, 13.02 | 12.47, 12.27, 12.44 |
| Gap p95 (ms) | 142.8, 140.0, 142.1 | 132.3, 135.3, 132.5 |
| Worst gap (ms) | 229.1, 228.4, 268.0 | 199.8, 201.9, 244.2 |

**Honest reading:** paced cadence improved clearly. The refresh rate is still just under 10.00 per wall second, because the schedule asks for exactly 10 and a few frames drop, so the 10/s target is met only to within 0.3%. Unpaced capacity fell by about 5% and total `drawnow` time rose by about 10%: two medium frames cost more than one heavy and one light. Both remain above the 0.8x minimum and above 1x on this host.

## Integrity

All 12 runs ended COMPLETE with 2799 ticks and 3080 samples, and every sample's checksum, time, tick and frame id equals a headless run. Refresh and label changes do not touch simulated data. Images and map draw one tick (0.05 s) after their sample, so the map's UAV marker can be about 0.3 m ahead of the RGB footprint at survey speed. Each label shows its sample's own time.

## Responsiveness (2 runs each, one-tick-resolution harness timer at 5 Hz during a 1x run)

| Measure | A | B |
|---|---|---|
| Timer lateness p50 (ms) | 110.9, 110.9 | 99.5, 105.0 |
| Timer lateness p95 (ms) | 191.9, 193.9 | 194.4, 197.2 |
| Timer lateness max (ms) | 201.4, 491.9 | 226.1, 204.1 |
| Pause handled (ms) | 17.8, 26.2 | 40.6, 43.4 |
| Reset (ms) | 1397, 1457 | 1391, 1420 |

Pause froze the clock in every run. Responsiveness is essentially unchanged; reset still blocks for about 1.4 s.

## Screenshots (this folder)

`dark-desktop-wide.png`, `light-desktop-wide.png`, `compact-960x640.png`.

## Limits

No detector was integrated, and Windows was not run. One host and three runs per mode. The harness's timer exists only for the measurement; the application has none.
