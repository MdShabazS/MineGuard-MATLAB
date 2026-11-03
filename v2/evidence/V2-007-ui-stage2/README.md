# V2-007 UI contribution, Stage 2: display performance and visual refinement (not task completion evidence)

Task: V2-007 (owner Rahil; state unchanged). This is a contribution record, not `v2/evidence/V2-007.md`.
Contributor: Shabaz. Executed by Claude Code (Opus 5.5) through the MathWorks MATLAB MCP Server on Shabaz's Mac; Shabaz's human review is pending.
Environment: macOS 27.0.1, MATLAB R2026b Update 1 (26.2.0.3433840), UAV Toolbox 26.2. Seed 2002, run `V2RUN-NOMINAL-0001`.
Code under test: `fb22740013e155902b20947480d46bac0087cd38`. V2-006 is not integrated.
SIMULATION ONLY: synthetic sensors on a synthetic scene. No detection capability is shown or claimed.

## Tests (one run, clean tree at the SHA above)

| Suite | Tests | Passed | Failed | Incomplete | Time |
|---|---|---|---|---|---|
| testV2002MissionEngine | 22 | 22 | 0 | 0 | 2.2 s |
| testV2003Scene | 22 | 22 | 0 | 0 | 40.1 s |
| testV2005Sensors | 28 | 28 | 0 | 0 | 88.4 s |
| testV2007MissionControlUI (25 Stage 1 + 10 new) | 35 | 35 | 0 | 0 | 369.0 s |
| **Total** | **107** | **107** | **0** | **0** | 499.7 s |

0 figures and 0 timers before and after. A test confirms sensor checksums and poses equal a headless run over 200 ticks.

## Root causes from profiling

| Finding | Evidence |
|---|---|
| The reported 2-3 s "stalls" were the window's first paint before takeoff, counted as a mission frame | Slowest `drawnow` was refresh #1 of 702 in all early runs (1800-2311 ms); the slowest in-flight frame was 186-233 ms unpaced. No in-flight gap reached 1 s |
| Time goes to `drawnow`, then sensors | Stage 1 unpaced: `drawnow` 55-63 s, sensors 36-43 s, engine 10-12 s, panel code 4 s |
| Scene cost is camera motion | Isolated: camera move 19 ms; aircraft transform, trail and shadow under 2 ms each |
| Any uilabel change costs about 8 ms | Isolated single-label flush; Stage 1 changed 7 labels per refresh |
| `colormap` re-applied per thermal frame | About 7 ms, against 1.85 ms for thermal `CData` alone |
| Automatic axes work | Profiler: `AxesLayoutManager.doUpdate` 0.81 s over 600 ticks; LiDAR frames p95 23 ms |
| No effect found | Terrain lighting, `SortMethod`, hidden trail: within noise, so not changed. JVM GC time 0.00 s in every run |

## Performance (full mission, visible 1440x880 window, 139.95 s simulated, 3 runs each)

"Refresh" means a scene update plus a synchronous `drawnow`. It is **not a measured screen FPS**; displayed FPS was not measured. Stage 1 and Stage 2 were run the same way, and Stage 1 frame figures exclude its first paint.

| Metric | Stage 1 unpaced | Stage 2 unpaced | Stage 1 paced 1x | Stage 2 paced 1x |
|---|---|---|---|---|
| Scene refreshes per wall s | 6.77, 5.85, 6.57 | 10.01, 9.54, 11.21 | 5.02, 5.02, 5.02 | 9.66, 9.66, 9.02 |
| Sim/wall | 1.350, 1.165, 1.311 | 1.000, 0.953, 1.120 | 1.000 x3 | 1.000 x3 |
| Render median (ms) | 77.8, 89.2, 80.0 | 62.3, 64.2, 54.6 | 57.6, 52.7, 55.1 | 50.0, 50.4, 51.3 |
| Render p95 (ms) | 117.8, 129.5, 113.7 | 93.2, 101.5, 83.3 | 92.2, 72.5, 71.3 | 82.7, 85.2, 93.3 |
| Render max (ms) | 185.8, 233.0, 208.2 | 242.6, 224.3, 142.7 | 172.3, 102.7, 104.1 | 176.5, 145.7, 222.8 |
| Gap median (ms) | 143.0, 166.8, 148.0 | 104.7, 104.7, 90.0 | 199.4, 200.7, 201.1 | 119.9, 120.2, 132.9 |
| Gap p95 (ms) | 200.4, 233.8, 206.0 | 185.6, 198.7, 164.3 | 243.0, 236.7, 236.2 | 198.9, 200.7, 208.5 |
| Gap max (ms) | 313.6, 342.6, 284.8 | 360.3, 337.3, 254.9 | 355.2, 277.5, 267.2 | 256.1, 333.1, 494.4 |
| Gaps over 250 ms | 5, 22, 4 | 8, 12, 1 | 20, 10, 10 | 3, 6, 14 |
| Gaps over 1 s | 0, 0, 0 | 0, 0, 0 | 0, 0, 0 | 0, 0, 0 |
| Late pacing checks | n/a | n/a | 493, 303, 378 | 975, 949, 1263 |
| Scene frames dropped | n/a | 0, 0, 0 | n/a | 49, 49, 139 |
| Max behind clock (s) | not recorded | n/a | not recorded | 0.247, 0.409, 1.133 |

Host variation is large. Sensor code is unchanged, yet sensor time changed between batches: paced 26-28 s at `f8fa821` and 35-39 s at the final SHA. At `f8fa821` (same code except LiDAR limits) the same benchmark gave 14.42, 13.04, 11.46 refreshes/s unpaced and 9.97, 10.01, 10.01 paced, with 0-2 gaps over 250 ms paced.

**Outcome:** the 10/s scene target is not reliably met. Paced runs at the final SHA reached 9.02-9.66/s. Refresh rate improved in every comparable batch; p95 gap improved, but maximum gap did not.

Other measurements at the final SHA unless stated: startup 2.41 s, separate from mission frames (4.00 s in one earlier launch at `f8fa821`); abort plus reset 1143-1282 ms. At `f8fa821`: resize 219-433 ms (Stage 1: 291-425 ms); camera change 19-85 ms (Stage 1: 22-50 ms).

## Screenshots (exportapp, this folder)

- `stage2-wide-t0-configured.png`, `stage2-wide-survey.png`, `stage2-wide-complete.png`, `stage2-wide-sensor-dropout.png`
- `stage2-compact-960x640.png`, `stage2-compact-tall.png` (1000x801, shows the top of LiDAR)

`exportapp` ignores the scroll position, so the compact telemetry and event rows are not shown in a screenshot; their scrolled positions were only read programmatically.

## Remaining defects

- Refresh cadence is uneven: about half of gaps exceed 100 ms, because full frames also carry sensor generation.
- One paced run fell 1.133 s behind the clock before recovering; the end-of-run sim/wall stayed 1.000.
- Reset blocks for about 1.2 s (rebuilds the renderer, engine and sensors); startup takes 2-4 s.
- The scene's camera re-render is the largest display cost. `SceneRenderer` and terrain resolution were left unchanged.
- The hidden `SceneRenderer` HUD still receives text on each update (about 3.5 ms isolated).
- LiDAR height ticks are crowded in the wide layout because of equal axis scaling.
- Not done: fullscreen panels, Celsius, event inspection, replay, export, V2-006 integration; Battery shows NOT MODELLED. Windows not run.

## Measurement notes

- Early baseline runs were contaminated: a scratch benchmark did not close its windows. It was fixed and every reported run asserts no open figures first. The application and the tests did not leak.
- The benchmark harness is scratch tooling and is not committed.
