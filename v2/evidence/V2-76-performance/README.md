# Issue #76: Windows performance investigation

Owner: Rahil. Status: **investigation evidence only**, not a V2-007 acceptance, not a status change, and not approval to change the detector.
Tester: Rahil, using Claude Code (Opus 5.5). MATLAB R2026b Update 1 on Windows 11 Pro (i5-13450HX, 6P+4E cores, 32 GB, on AC, Balanced plan). Runs used the official MATLAB MCP Server unless marked as a separate `matlab` process.
Date: 2026-11-02 (IST)

SIMULATION ONLY. VALIDATION remains negative (G07: 0 of 4 targets found). Faster code does not improve detection. Scores and uncertainty are uncalibrated, and georegistration relies on noise-free reference geometry. No VAL or TEST study ran. No threshold changed.

**The Mac is the primary gate, and it has NOT been measured here. Nothing below shows that gate is met.**

## Source commits

| SHA | What it is |
|---|---|
| `7e89e70` | Published bridge (issue #68) |
| `57363dc` | Shabaz's Stage 2 UI, merged locally for measurement only |
| `759f4f2` | Bridge + Stage 2 + measurement tools: **baseline** |
| `11ec53d` | Baseline + bridge validation memo: **bridge fix**, no detector change |
| `053c6ac` | Bridge fix + detector read-path proposal: **proposal**, on separate branch `perf/76-detector-proposal` |

These branches predate the Mac display fix, so their V2-006 suite has 27 tests rather than 28.

## Finding 1: the earlier Windows numbers were distorted by Windows throttling

The "second-run slowdown" and the 0.73× and 0.54× figures quoted in issue #76 were **not** only program cost. Windows was intermittently slowing the MATLAB process.

| Evidence | Result |
|---|---|
| Same process, project-free workloads, flipping during a sequence (`seq_process.jsonl`) | Fast: loop 20 ms, `Map` 90 ms. Slow: loop 54–60 ms, `Map` 750 ms, BLAS about 4× slower. UI no-detector ran 0.99×, 0.40×, 1.13× in sequence |
| Same moment, two processes (`watch_*.csv`) | `Map` workload about 55 ms in one, about 7 ms in the other, so this is not machine-wide |
| Forcing high QoS on the running process (`SetProcessInformation`, execution-speed throttling off) | BLAS 39.8→8.7 ms, loop 61.2→20.2 ms, struct 119.4→18.4 ms, `Map` 731.6→92.4 ms, with no restart |
| Returning it to system-managed | Slow again immediately: `Map` 746 ms |
| Starting from throttled, then opening the app window (`runs_windows_managed.jsonl`) | Calibration went 33.5→9.3 ms, and the app held 1.00× and 0.95× under Windows' own control |

**Conclusion:** the slowdown is process-level Windows power throttling, reversible on demand. It appears to follow window activity: a visible app seems to run at full speed, and slowdown appears when MATLAB's windows are not in use.

**What is not proven:** the exact Windows trigger. No experiment changed window focus deliberately. `findall` showed no leftover figures, and `clear classes` did not help, so an app leak was not the cause. **Earlier in this work I wrongly blamed session age, then the whole machine; both were disproved by these measurements.**

**For a Windows demo:** keep the app window in front. `powercfg /powerthrottling disable /path <MATLAB.exe>` is the documented per-application setting, but it was **not tested or applied here**, because it is a system setting for the operator to choose.

## Controlled matrix: high QoS held, 3 full missions per condition, alternating order

139.95 simulated seconds, 2,799 ticks, default scene, unpaced (`RealTime` 0). Values are the three runs. Pause figures are the medians of the three.

| Condition | Baseline `759f4f2` | Bridge fix `11ec53d` | Proposal `053c6ac` |
|---|---|---|---|
| Headless, no detector | 2.21, 2.44, 2.38 | not rerun | not rerun |
| Headless, rebuild every 100 ticks | 1.55, 1.62, 1.60 | 1.71, 1.72, 1.72 | 1.75, 1.76, 1.76 |
| Headless, rebuild every 20 ticks | 1.03, 1.09, 1.07 | 1.28, 1.31, 1.28 | 1.43, 1.50, 1.47 |
| App, no detector | 1.08, 1.10, 1.09 | not rerun | not rerun |
| App, rebuild every 100 ticks | 0.87, 0.85, 0.86 | 0.90, 0.88, 0.90 | 0.90, 0.89, 0.91 |
| App, rebuild every 20 ticks | **0.67, 0.67, 0.68** | **0.76, 0.76, 0.76** | **0.81, 0.82, 0.82** |

| App, unpaced | Worst pause | Gap p50 / p95 | Gaps > 250 ms | Gaps > 1 s |
|---|---:|---|---:|---:|
| No detector, baseline | 495 ms | 78 / 174 ms | 3–4 | 0 |
| 100 ticks: baseline | 909 ms | 114 / 213 ms | 30–35 | 0 |
| 100 ticks: bridge fix | 699 ms | 113 / 211 ms | 29–32 | 0 |
| 100 ticks: proposal | 499 ms | 119 / 213 ms | 29–32 | 0 |
| 20 ticks: baseline | 915 ms | 112 / 557 ms | 132–137 | 0 |
| 20 ticks: bridge fix | 650 ms | 118 / 418 ms | 123–128 | 0 |
| 20 ticks: proposal | 489 ms | 120 / 311 ms | 122–126 | 0 |

| Single rebuild, median / p95 / max (ms) | 20 ticks | 100 ticks |
|---|---|---|
| Baseline | 360 / 683 / 708 | 355 / 686 / 697 |
| Bridge fix | 229 / 419 / 432 | 246 / 456 / 465 |
| Proposal | 110 / 218 / 251 | 134 / 251 / 275 |

**Freshness:** actual reported event age is median 0.4 s, worst 0.9 s at 20 ticks, and median 2.4 s, worst 4.9 s at 100 ticks. It depends only on the rebuild interval, so optimization does not change it. **A shorter interval is the fresher choice, and the proposal is what makes 20 ticks affordable.** Age is shown in `sourceInfo`, and the status text shows the as-of time. Nothing is hidden.

## Paced at 1× (the demo setting), single runs

| Configuration | Sim/wall | Worst gap | Gaps > 250 ms | Gaps > 1 s |
|---|---:|---:|---:|---:|
| No detector, on `053c6ac` | 1.000 | 574 ms | 5 | 0 |
| Bridge fix, 100 ticks | 0.943 | 688 ms | 43 | 0 |
| Bridge fix, 20 ticks | 0.792 | 704 ms | 145 | 0 |
| Proposal, 100 ticks | 0.968 | 612 ms | 42 | 0 |
| Proposal, 20 ticks | 0.851 | 569 ms | 156 | 0 |
| Proposal, 100 ticks, Windows-managed | 0.951 | 614 ms | 49 | 0 |

**Against the provisional 0.8× gate, on Windows only:** bridge fix passes at 100 ticks and narrowly misses at 20 ticks (0.792). The proposal passes at both. These are whole-mission ratios from single runs. The "60 simulated seconds within 75 wall seconds" form of the gate was not separately measured. Paced runs fall behind and catch up; `late_ticks` is high in all of them (1,537–2,797). The number of optional scene frames the app skipped was **not recorded** by this tool. **No configuration reached a sustained 1× with the detector on.**

## Integrity

Across all baseline, bridge-fix, proposal, paced and Windows-managed runs above: one sample digest (`016961199e09…`), one pose digest (`e649b54c9d02…`), one event digest (`1e14af2e0e3b…`, full precision), one fingerprint (`fnv1a64:d6d364f988f04bb4`). Always 3,080 samples, COMPLETE, 84 events at mission end. **No sensor or physics tick was skipped.** The digest covers the fields in `mgv2PerfRun`; the fuller output check is in the equivalence evidence below.

## Finding 2: where the rebuild time goes

Unthrottled, end of mission (`profile_growth.txt`, `11ec53d`, read path timed directly, conversion without the memo):

| Tick | 700 | 1,400 | 2,100 | 2,799 |
|---|---:|---:|---:|---:|
| Live tracks | 434 | 820 | 1,264 | 1,393 |
| Observations | 2,288 | 5,096 | 8,213 | 9,996 |
| Camera looks | 352 | 702 | 1,052 | 1,400 |
| `trackTable` (ms) | 98 | 159 | 253 | 273 |
| of which LiDAR context | 51 | 84 | 117 | 127 |
| of which footprint loop | 10 | 21 | 33 | 43 |
| of which per-track scan | 5 | 14 | 23 | 25 |
| `events` beyond `trackTable` | 13 | 26 | 49 | 59 |
| `toUiEvents`, no memo | 100 | 159 | 282 | 308 |
| `MissionMap.snapshot` | 9 | 16 | 23 | 30 |
| Cached `view()` | 7 | 7 | 3 | 9 |

- **Issue #76's hypothesis was partly right.** Footprint traversal grows with history, but it is about 16% of `trackTable`. **LiDAR context is the largest part (47%), computed for about 1,400 tracks when about 84 become events.**
- **Repeat validation in the bridge was as costly as `events` itself.** Under the profiler (`profile_top.txt`; use only for relative shares), `validateEvent` was 39% of read time, nearly all from `assertNoBannedWords`. This was bridge-side, and it is now fixed without touching the detector.
- **Rendering is the largest cost in the integrated app.** Median `drawnow` is about 49 ms in every condition. App no-detector takes about 129 s against about 59 s headless. That belongs to Shabaz's UI work and was not changed.
- **Ingest is about 16 s per mission** (`onSample`). The profiler shows `processCamera`, table appends and a repeat of a checksum the sensor system already computed. **The proposal does not change ingest.**

## Memory (serialized sizes, not process memory)

| Tick | 700 | 1,400 | 2,100 | 2,799 |
|---|---:|---:|---:|---:|
| Detector total (MB) | 24 | 44 | 67 | 75 |
| of which evidence records | 19 | 39 | 62 | 69 |
| Observations | under 1 | 1 | 2 | 2 |
| LiDAR grid | 3 | 3 | 3 | 3 |
| `MissionMap` | 2 | 2 | 3 | 4 |

**92% of detector memory is retained evidence crops**, for all tracks including those that never become events (4,522 records at the end). Retention is capped at 4 per modality per track, so growth follows track count. It was not reduced, because that would change what evidence is available for later events. Releasing old objects after a reset was not measured.

## Bridge fix (`11ec53d`), no detector change

`toUiEvents` skips only the contract scan for an event identical to one already validated in this run. Run and evidence checks still run on every rebuild, and truth scans still run on any changed event. Test b20 covers it.

**My first version never ran:** `isempty` is true for an empty `containers.Map`, so the memo stayed empty. b20 caught this. Those runs are kept as `runs_memo_NOT_ACTIVE_bug.jsonl` and are not used.

## Regression

| Suite | `11ec53d` | `053c6ac` |
|---|---:|---:|
| V2-002 | 22/22 | 22/22 |
| V2-003 | 22/22 | 22/22 |
| V2-005 | 28/28 | 28/28 |
| V2-006 | 27/27 | 27/27 |
| V2-007 UI, Stage 2 (first Windows run) | 35/35 | 35/35 |
| V2-007 bridge | 20/20 | 20/20 |
| **Total** | **154/154** | **154/154** |

0 failed, 0 incomplete, 0 skipped. Clean clones before and after each suite. Logs: `regression-11ec53d.txt`, `regression-053c6ac.txt`.

## Tools

`v2/matlab/mgv2PerfRun.m`, `mgv2PerfProfile.m` and `mgv2DetectorEquivalence.m` can run on the Mac. `mgv2PerfRun` needs no Windows-only call apart from its optional memory reading.

**Not measured:** Mac, for every condition above; event-loop responsiveness separately from frame gaps; display frame rate; a person's view of the running app. High QoS was forced for the controlled matrix, which an ordinary demo would not do.
