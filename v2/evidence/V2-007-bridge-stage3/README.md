# V2-007 bridge on UI Stage 3: Windows evidence

SIMULATION ONLY. Outputs are suspected anomalies with an uncalibrated score. This is not a completed-dashboard claim, not field detection, and V2-007 stays IN_PROGRESS. G07 VALIDATION 0/4 remains a negative result; nothing here reruns TRAIN selection, VALIDATION or TEST.

| Item | Value |
|---|---|
| Tested SHA | `2bca2f881ad645b677966dfe6154d130503045f4`, clean tree |
| Contains | UI Stage 3 `10d5f5b` (execution SHA `043a896`), main `0b33357`, issue #76 branch `9f5cc83` |
| Not contained | PR #86 proposal. UI commit `c720230` (Mac evidence files only) |
| MATLAB | 26.2.0.3433840 (R2026b) Update 1, PCWIN64 |
| Detector | Unchanged, fingerprint `fnv1a64:d6d364f988f04bb4` |

## Tests

| Suite | Tests | Pass | Fail | Incomplete in -batch |
|---|---:|---:|---:|---:|
| testV2002MissionEngine | 22 | 22 | 0 | 0 |
| testV2003Scene | 22 | 22 | 0 | 0 |
| testV2005Sensors | 28 | 28 | 0 | 0 |
| testV2006Detection | 28 | 27 | 0 | 1 |
| testV2007Bridge | 25 | 25 | 0 | 0 |
| testV2007MissionControlUI | 60 | 59 | 0 | 1 |
| **Total** | **185** | **183** | **0** | **2** |

The 2 incomplete tests need a desktop (`d28_demoLabelsReadableInBothDesktopThemes`, `dashboardLooksTheSameInBothDesktopThemes`). Both then passed in a desktop MATLAB at the same SHA: `desktop_theme_tests_2bca2f8.txt`. The two sessions together account for all 185. Log: `regression_batch_2bca2f8.log`.

## Adapter

`+mgv2/+bridge/V2006AnomalySource.m` binds through `bindRun` and `onPose`, so a plain `mgv2MissionControl('AnomalySource', src)` gives events, layers and coverage. It also survives reset and scenario change (b07, b24).

**Contract gap.** `bindRun` does not carry the sensor log. Without it, `inspect` raises `mgv2:EvidenceLogUnavailable` instead of reporting an unchecked record as verified (b23). Until the seam changes, evidence inspection needs `src.bindSession(app.Session)`. Proposal for the UI owner: pass the sensor log, or an accessor for it, through the seam. The UI was not changed here.

## Windows performance, 2bca2f8

18 full default-scene missions, one MATLAB process, in the order logged. Raw: `bench_stage3_2bca2f8.jsonl`. Runner: `bench_stage.m`, `run_bench.ps1`. Sim/wall is simulated seconds over wall seconds. `drawnow` is that run's median.

| Setup | Unpaced round 1 | Round 2 | Round 3 | Paced 1× single run |
|---|---:|---:|---:|---:|
| UI_NULL | x0.745 (84 ms) | x0.850 (52 ms) | x0.667 (93 ms) | x0.895 (112 ms) |
| UI_R100 | x0.605 (91 ms) | x0.581 (96 ms) | x0.604 (92 ms) | x0.784 (105 ms) |
| UI_R20 | x0.764 (48 ms) | x0.626 (56 ms) | x0.528 (93 ms) | x0.868 (56 ms) |
| H_R100, nothing drawn | x1.827 | x1.716 | x1.721 | not run |
| H_R20, nothing drawn | x1.331 | x1.276 | x1.241 | not run |

**Against the target, on this Windows host only:**
- 1×: not met by any UI run, including UI_NULL with no detector.
- 0.8× minimum: no integrated unpaced run reached it. Paced, UI_R20 did (x0.868, one run) and UI_R100 did not (x0.784, one run). This is not a reliable pass.
- Mac: not measured at this SHA, so this says nothing about the Mac target.

**Reading these numbers:**
- CPU calibration was normal in every run (7.5 to 12.5 ms, normal about 8), so no run was excluded.
- `drawnow` moved between about 50 and about 95 ms during the session, and this moved UI results. The cause is unproven. UI_R100 only ran in the slow state, so **these runs do not show which of R20 and R100 is faster in the UI**. Headless runs, free of this effect, show R100 faster.
- UI_NULL has no bridge, yet ranged x0.667 to x0.850. Graphics alone already exceeded real time here.
- Paced runs beat unpaced ones partly because the app drops scene-only refreshes when behind: about 700 to 750 UI frames against 1400. Late ticks were 2759 to 2797 of 2799. No physics or sensor tick was skipped.
- Stage 2 on the same host reached UI_NULL x1.06 to x1.08 and UI_R100 x0.84 to x0.86 at `drawnow` about 47 ms. This Stage 3 session never gave R100 that state, and has one UI_NULL run near it (x0.850 at 52 ms). That is a possible Stage 3 slowdown on Windows, not an established one.

| Measured | R100 | R20 |
|---|---:|---:|
| Rebuilds per mission | 28 to 29 | 140 to 142 |
| Rebuild median, ms | 236 to 280 | 226 to 253 |
| Rebuild max, ms | 450 to 539 | 432 to 498 |
| Event age median / worst, s, UI | 2.4 / 5.1 | 0.4 / 1.1 |
| Worst UI frame gap, ms | 688 to 824 | 555 to 764 |

Ingest cost 15.0 to 19.1 s per mission. Worst single ingest 26 to 47 ms. UI_NULL worst gap 383 to 447 ms. No gap exceeded 1 s.

Consistent across all 18 runs: phase COMPLETE, 2799 ticks, 3080 samples, 3 invalid samples, sample digest `01696119`, pose digest `e649b54c`. All 12 bridge runs: 84 events, event digest `1e14af2e`, 1 bind, 0 refused samples. No errors. After each run, 0 figures and 0 timers remained. MATLAB memory settled near 4.2 GB after the first runs, growing about 10 to 30 MB per run.

## Earlier records, kept for comparison

Both are at `a1c7201` on Stage 2 UI.
- `bench_stage2_a1c7201_attempt1_runs11-19_THROTTLED.jsonl`: **runs 11 to 19 are excluded**, calibration 33 to 62 ms. High QoS had been applied to the launcher process, not the worker. Runs 1 to 10 are valid. Fixed in the runner for later attempts.
- `bench_stage2_a1c7201_attempt2.jsonl`: valid calibration, mostly slow `drawnow`.

## Limitations

- Windows only. No bridge run on Mac at this SHA.
- High QoS was forced on the MATLAB process, so this is not a normal demo setup.
- Measured screen frame rate and skipped rendered frames are not measured. UI refreshes are not screen frames.
- Automated runs with an idle operator. No person judged the dashboard.
- Paced results are one run each.
- `windows-integrated-r20-tick1400.png` is one paused screenshot, in a separate MCP session, with `bindSession`. Its 43 events are detector output on the simulated scene, not a measure of accuracy.
