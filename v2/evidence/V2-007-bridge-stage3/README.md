# V2-007 bridge on UI Stage 3: Windows evidence

SIMULATION ONLY. Outputs are suspected anomalies with an uncalibrated score. This is not a completed-dashboard claim, not field detection, and V2-007 stays IN_PROGRESS. G07 VALIDATION 0/4 remains a negative result; nothing here reruns TRAIN selection, VALIDATION or TEST.

## Current record: code SHA `081cecbc38fef725374ea4f7f1f22cc0231fe070`

Clean tree, MATLAB 26.2.0.3433840 (R2026b) Update 1, Windows desktop session. Later commits on this branch add evidence files only. Windows results are diagnostic. Mac paced 1× is the primary target, and it has not been run at this SHA.

**Windows result: INCOMPLETE for acceptance.** Regression passes and results are deterministic, but UI_R20 misses 1× here and no Mac run exists.

### Tests and checkcode

197 of 197 passed in one desktop session, with 0 failed and 0 incomplete: V2-002 22, V2-003 22, V2-005 28, V2-006 28, V2-007 UI 60, bridge 37. Raw: `regression_desktop_081cecb.txt`. Checkcode reports 0 messages on all code files and 2 harmless messages in `tests/testV2007Bridge.m` (L43, L374): `checkcode_081cecb.txt`. V2-005 took 531 s against about 88 s in other sessions. The cause is unexplained.

### Determinism

All 30 missions (24 with the UI, 6 headless, 24 with the bridge) reached COMPLETE with no errors: 2799 ticks, 3080 samples, 3 invalid samples, sample digest `016961199e092dcbcf17466c91ec18b8c59766de71a3bbce35636547f88c239a`, pose digest `e649b54c9d02f9d56ce4d5eeea1879f583cf52a00713229b76d799c6dc5dc042`. All 24 bridge missions gave 84 events, event digest `1e14af2e0e3bac137c731f882f8f0efdadc30d2718c6e73fd9051af1fe9bc33a`, fingerprint `fnv1a64:d6d364f988f04bb4`, 1 bind, 0 refused samples. R20 and R100 give the same digests, also under throttling, and these match `2bca2f8`.

### Paced 1×, high QoS, three runs each

Raw: `bench_paced_highqos_081cecb.*`. **High QoS was forced on MATLAB, so this is not a normal demo setup.** Ranges cover three full missions. CPU calibration 7.9 to 13.2 ms, mean CPU busy 22 to 25%.

| Measured | UI_NULL | UI_R100 | UI_R20 |
|---|---:|---:|---:|
| Sim/wall | x1.000 | x0.996 to 0.997 | **x0.856 to 0.860** |
| Wall, s (140 simulated) | 140.0 | 140.4 | 162.8 to 163.5 |
| Most behind real time, s | 0.41 to 0.77 | 0.92 to 1.20 | **22.8 to 23.5** |
| `drawnow` median, ms | 45 to 47 | 53 to 57 | 60 to 63 |
| Frame gap median, ms | 123 to 125 | 163 to 176 | 182 to 183 |
| Frame gap p95, ms | 168 to 173 | 214 to 236 | 582 to 588 |
| Worst frame gap, ms | 325 to 404 | 689 to 796 | 651 to 681 |
| Gaps over 250 ms / over 1 s | 1 to 5 / 0 | 24 to 32 / 0 | 123 to 128 / 0 |
| Stalls over 100 ms | 1 to 6 | 34 to 39 | 143 to 145 |
| UI refreshes per wall second | 9.8 to 9.9 | 5.7 to 6.7 | 4.5 |
| Scene refreshes skipped | 9 to 28 | 466 to 608 | 660 to 668 |
| Bridge rebuilds | none | 29 | 140 to 141 |
| Rebuild median / max, ms | none | 255 to 264 / 449 to 459 | 233 to 243 / 446 to 447 |
| Ingest total, s / worst single, ms | none | 16.3 to 17.3 / 28 to 45 | 16.1 to 16.5 / 26 to 38 |
| Event age median / worst, s | none | 2.6 to 2.7 / 5.1 | 0.4 / 1.0 |

**20 ticks against 100, on this host:**
- 20 ticks is slower. It gives fresher events (worst age 1.0 s against 5.1 s), costs about 23 s of wall time per mission, and has about four times as many stalls over 100 ms.
- A single rebuild costs about the same at either interval. Median times count give about 33 s of rebuild work at 20 ticks and about 7.5 s at 100. That difference is close to the 23 s of extra wall time, but it does not prove the whole cause.
- UI_R100 meets 1× within 0.4%. UI_R20 misses 1× and clears the 0.8× provisional minimum. All three R20 runs agree.
- 20 ticks stays the provisional default as agreed. The Mac runs decide it. No claim is made that 20 ticks is faster.
- Paced bridge runs hold time by dropping scene refreshes, and 2686 to 2792 of 2799 ticks were late (UI_NULL 460 to 785). No physics or sensor tick was skipped.

### Normal process priority

Raw: `bench_paced_normal_081cecb.*`, `bench_diag_normal_081cecb.*`. Runs are in time order. *Perf* is mean processor performance percent, *cal* is calibration before and after in ms, normal about 8, and *MATLAB front* is the share of host samples with MATLAB in the foreground.

| Run | Sim/wall | Perf | Cal | MATLAB front | Worst gap, ms | Rebuild median, ms |
|---|---:|---:|---:|---:|---:|---:|
| Paced UI_NULL | x1.000 | 154 | 8.9 / 9.1 | 100% | 1106 | none |
| Paced UI_R100 | x0.994 | 160 | 9.8 / 8.5 | 100% | 827 | 251 |
| Paced UI_R20 | x0.867 | 160 | 9.1 / 9.7 | 100% | 697 | 224 |
| Paced UI_NULL | **x0.441** | 107 | 8.5 / 43.3 | 6% | 783 | none |
| Paced UI_R100 | **x0.818** | 139 | 36.1 / 51.2 | 69% | 3226 | 251 |
| Paced UI_R20 | **x0.242** | 107 | 39.4 / 51.9 | 0% | 2963 | 1118 |
| Paced UI_NULL | **x0.409** | 106 | 36.3 / 63.6 | 1% | 764 | none |
| Paced UI_R100 | x0.997 | 156 | 34.3 / 8.3 | 95% | 677 | 253 |
| Paced UI_R20 | x0.846 | 158 | 8.3 / 8.3 | 100% | 706 | 237 |
| Unpaced UI_R100 | x0.868 | 157 | 13.1 / 9.0 | 100% | 591 | 254 |
| Unpaced UI_R20 | **x0.281** | 113 | 8.2 / 62.3 | 15% | 2728 | 1117 |
| Unpaced H_R100 | **x0.648** | 117 | 34.0 / 32.4 | 0% | headless | 1107 |
| Unpaced H_R20 | **x0.412** | 110 | 33.4 / 35.2 | 1% | headless | 1107 |
| Unpaced UI_R100 | x0.911 | 153 | 32.8 / 7.7 | 95% | 546 | 239 |
| Unpaced UI_R20 | x0.761 | 156 | 8.3 / 7.8 | 98% | 518 | 234 |
| Unpaced H_R100 | x1.778 | 154 | 8.8 / 7.8 | 35% | headless | 241 |
| Unpaced H_R20 | x1.322 | 155 | 9.8 / 7.7 | 0% | headless | 230 |
| Unpaced UI_R100 | x0.851 | 155 | 7.8 / 8.2 | 45% | 2048 | 256 |
| Unpaced UI_R20 | **x0.306** | 116 | 45.6 / 10.5 | 18% | 2679 | 446 |
| Unpaced H_R100 | **x0.612** | 108 | 8.5 / 34.0 | 0% | headless | 1199 |
| Unpaced H_R20 | **x0.384** | 108 | 35.0 / 35.4 | 0% | headless | 1107 |

- Normal priority is **not repeatable on this host**, and the three-run criterion is not met here. Clean paced runs at normal priority match the high-QoS results, but there are too few: UI_NULL 1, UI_R100 2, UI_R20 2.
- Slow runs line up with a Windows CPU slowdown: perf about 107 against about 155, calibration up to about 7 times normal, and rebuilds about 4.6 times slower. UI_NULL slowed as well, and it has no bridge. The bridge is not the source of the slowdown.
- Every run with perf under 120 had MATLAB in the background for most of the run. Background alone is not sufficient: unpaced H_R100 and H_R20 at 35% and 0% ran at full speed. All 9 high-QoS runs stayed clean, including one with MATLAB in the foreground only 46% of the time. Windows power throttling of background processes fits this, but it was not proven.
- The computer was in normal use during these runs, as the foreground column shows. The normal-priority runs were not repeated with MATLAB held in the foreground, so a demo on Windows should keep MATLAB in front.
- Unpaced results, kept as diagnostics. UI, three runs: UI_R100 x0.851 to 0.911. Clean headless, one run each: H_R100 x1.778, H_R20 x1.322.

### What changed since `2bca2f8`

- Evidence is verified automatically for the current run: `MissionSession` hands the source a read-only context, and `bindSession` is gone.
- `inspect` compares the session generation and run id, reads the listed snapshot without rebuilding, and takes no caller-supplied log. Sensor log rows are checked for sensor, pose, time and validity.
- If a listed event's records were replaced by the detector, `inspect` reads the same event id again from the detector, rechecks it and labels it `record_basis="CURRENT"`. That read costs one detector call, and its stall on a click was not measured.
- The default refresh is 20 ticks, configurable with `RefreshTicks`. Records carry `events_as_of_tick`, `events_as_of_t_s`, `current_tick` and `stale_ticks`.
- A second session bound to the same source raises `mgv2:BridgeAlreadyBound`.
- `942aa08` edits two Shabaz-owned UI files on this branch only, and is isolated for cherry-pick or replacement. `V2_007_BRIDGE_SEAM_PROPOSAL.md` is superseded.

### Unresolved

- A script holding an old engine after reset and stepping it could still deliver through its old subscription. This is not reachable through the public UI.
- The UI status panel shows event age but not `record_basis` or inspection age.
- `UI_INTEGRATION_CONTRACT.md` does not describe `bindEvidence` yet. The UI owner has to update it.
- No person has clicked an event through the plain launch and judged the result. Tests drive this through the app.
- Screen frame rate was not measured. UI refreshes are not screen frames.
- Two other MATLAB sessions were open throughout: an idle desktop session and the idle MCP session (about 3 GB) that ran the tests.

Simulation only. G07 VALIDATION 0/4 stands. No TRAIN selection, VALIDATION or TEST rerun. V2-007 stays IN_PROGRESS and V2-008 stays blocked.

## Earlier record: `2bca2f8`

The sections below are kept as recorded. The contract gap section is superseded by the current record above.

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
