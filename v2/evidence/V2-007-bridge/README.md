# V2-007 bridge: Windows evidence for Shabaz's review (issue #68)

Owner: Rahil (official V2-007 owner). Shabaz owns the UI contribution.
Status: engineering subtask only. **Not a V2-007 status transition, and not complete UI acceptance.**
Tester: Rahil, using Claude Code (Opus 5.5) through the official MathWorks MATLAB MCP Server
Environment: Windows 11 Pro (build 26300), MATLAB R2026b Update 1 (26.2.0.3433840, PCWIN64), desktop session with a display
Date: 2026-11-01 to 2026-11-02 (IST)
Source tested: `f7df56d498f9303f59a83fd0f6170fc5bed0605f`, in a clean clone made from the local branch

SIMULATION ONLY. Events are SUSPECTED on synthetic scenes. Scores and uncertainty are uncalibrated, and georegistration relies on noise-free reference geometry. **V2-006 VALIDATION remains negative** (G07: 0 of 4 targets found, 45 fused false alarms; G08: 32 fused false alarms with no targets). Thresholds are frozen and unchanged. No PASS below implies detection success. This work ran no TRAIN, VAL or TEST study stage.

## Inputs and scope

| Item | Value |
|---|---|
| V2-006 snapshot | PR #66 at `684665c` |
| V2-007 UI snapshot | PR #67 at `4da9701` |
| Local combination | `907399a`, a clean merge in this worktree only; neither source branch was changed |
| Branch and worktree | `feature/V2-007-bridge-rahil`, `MineGuard-V2-007-bridge-ra`; **not pushed** |
| New source | `+mgv2/+bridge/V2006AnomalySource.m`, `toUiEvents.m`, `toMapLayers.m`, `checkEvidence.m`; `mgv2BridgeBenchmark.m`; `tests/testV2007Bridge.m` |
| Not changed | `+mgv2/+ui/*`, the detector, status files, manifests, portal, V1 files, `v2/data/V2-006/` |

## Regression (`regression-clean-clone-f7df56d.txt`)

Command: `addpath('v2/matlab'); runtests(...)` per suite, in the clean clone, with output captured by `evalc`.

| Suite | Tests | Pass | Fail | Incomplete | Skipped |
|---|---:|---:|---:|---:|---:|
| V2-002 mission engine | 22 | 22 | 0 | 0 | 0 |
| V2-003 scene | 22 | 22 | 0 | 0 | 0 |
| V2-005 sensors | 28 | 28 | 0 | 0 | 0 |
| V2-006 detection | 27 | 27 | 0 | 0 | 0 |
| V2-007 UI (Shabaz's suite, first run on Windows here) | 25 | 25 | 0 | 0 | 0 |
| V2-007 bridge (new) | 19 | 19 | 0 | 0 | 0 |
| **Total** | **143** | **143** | **0** | **0** | **0** |

Each suite's header records a clean clone before and after it ran. `checkcode` on the 6 bridge-owned files: **0 messages** (`checkcode-f7df56d.txt`). The V2-006 suite and bridge test b18 run the labelled DEMO FIXTURE. The V2-006 suite also makes partial TRAIN-group fixture runs, and no study stage ran.

**Correction during development:** b19 first failed through a test mistake. `MapPanel` layers have hidden handles, so `findobj` could not see them, and the matching "layer is gone" check would have passed regardless. Both now use `findall`, and the test requires events to exist.

## What the bridge tests check

| Requirement | Test |
|---|---|
| Event field mapping; detector schema unchanged | b01 |
| UI validators and `assertPublic`; frozen fingerprint | b02 |
| Cache and freshness; fresh when paused or ended | b03, b04 |
| Coverage mask, `UNOBSERVED` transparent, no "cleared" wording | b05 |
| No duplicate subscriptions | b06 |
| Deterministic replay and reset | b07 |
| Late binding: wrong session, double bind and late bind refused; held tick-0 samples replayed | b08 |
| Unbound source reports not connected and invents nothing | b09 |
| Wrong-run samples and events refused | b10 |
| Invalid sensor frames | b11 |
| Truth firewall, including a code scan of `+bridge` | b12 |
| Missing evidence; checksum mismatch | b13, b14 |
| Verified evidence on a real event | b15 |
| Bridge does not change samples, poses or events | b16 |
| No second route state | b17 |
| DEMO FIXTURE through mapping and evidence, integration only | b18 |
| Real window: layers, table, reset, then a second run | b19 |

## Measurements (Windows; not Mac; not display frame rates)

All are full missions of 2,799 ticks, 139.95 simulated seconds, unless stated. Default scene.

### Headless session: step, plus `view()` every 4 ticks, with no drawing

| Run | File | Sim/wall | Wall | `view()` median / p95 / max (ms) | Rebuilds |
|---|---|---:|---:|---|---:|
| No detector | `bench_NULL.txt` | **1.19** | 117.7 s | 0.8 / 1.3 / 4.6 | none |
| Bridge, rebuild every 100 ticks | `bench_CACHED_R100.txt` | **0.74** | 189.1 s | 8.7 / 19.1 / 1,226 | 29 |
| Bridge, rebuild every 20 ticks (default) | `bench_CACHED_R20.txt` | **0.52** | 266.7 s | 10.0 / 1,096 / 1,424 | 141 |
| Bridge, no cache, **1,400 ticks only** | `bench_UNCACHED.txt` | **0.36** | 197.1 s | 381 / 619 / 769 | 350 |

### Where the time goes (100-tick run)

| Item | Measured |
|---|---|
| `onSample` (detector ingest and map update) | mean 15.0 ms, max 139 ms, 3,080 calls: about 46 s per mission |
| Detector, median per sample | RGB 20.6 ms, thermal 27.2 ms, LiDAR 3.7 ms, navigation 0.08 ms |
| Full rebuild | Grows with events and tracks: 249 ms at tick 404 (14 events) to 1,242 ms at tick 2,798 (84 events) |
| Of that, event mapping and evidence checks | 76 ms to 513 ms |
| Of that, map snapshot and layers | 21 ms to 46 ms |
| Cached `view()` overhead | About 8 ms above baseline, mostly `validateEvents` scanning the cached events on every view |

### Memory and objects (headless)

| Tick | Detector | Map |
|---:|---:|---:|
| 700 | 23.5 MB | 1.7 MB |
| 1,400 | 44.0 MB | 2.3 MB |
| 2,100 | 67.5 MB | 3.0 MB |

These are serialized sizes from `getByteStreamFromArray`, not process memory. Both keep growing through the mission. End of run: 3,080 detector log rows, 2,800 route points, 1,680 footprints, 1 pose subscription, 0 samples refused. Release of the old objects after a reset was not measured.

### Real app window, `RealTime` 0, `RenderEvery` 4, rebuild every 100 ticks

| Position in the MATLAB call | Run | Sim/wall | `present` median (ms) | `drawnow` median (ms) | Frame median / p95 / max (ms) | Frames > 100 ms |
|---|---|---:|---:|---:|---|---:|
| First | No detector, `run1` | **0.73** | 11.4 | 89.8 | 102 / 158 / 3,568 | 376 of 702 |
| First | Bridge, `run2` | **0.54** | 22.8 | 88.5 | 113 / 194 / 2,438 | 478 of 702 |
| Second | No detector, `run2` | 0.44 | 24.4 | 228 | 254 / 398 / 4,425 | 551 of 702 |
| Second | Bridge, `run1` | 0.23 | 77.5 | 280 | 363 / 591 / 4,248 | 702 of 702 |

- **Compare within a row group only.** Whichever app ran second in a call was about twice as slow, in both orders, even in panels the bridge does not touch (`scene_ms` about 2.3 vs about 5). The cause was not diagnosed; it could be an app-teardown leak, graphics state or the host. Only one run of each was made, so these are not statistics.
- **First-position comparison:** the bridge takes the app from 0.73× to 0.54×.
- The event panel's median cost rises from 0.08 ms to 3.3 ms with the bridge.
- `drawnow` already dominates without the bridge, as Shabaz's Stage 2 is addressing. Stage 2 was not available for this test.

### Reading these numbers

1. **The bridge does not reach 1× on this Windows host in any tested configuration.** The headless baseline has only about 22 s of margin per mission (117.7 s wall for 139.95 s simulated), and `onSample` alone costs about 46 s. No cache setting can remove that.
2. **The default `RefreshTicks` of 20 is not a good setting:** near the end of a mission, each rebuild (about 1.3 s) takes longer than the 1 simulated second between rebuilds. I left it unchanged rather than edit tested source; 100 is better, at the cost of up to 5 simulated seconds of age, which `sourceInfo` reports.
3. **Caching helps a lot but does not remove stalls.** Each rebuild is still a single blocking pause of up to about 1.2 s, and MATLAB runs it in the same thread as the mission loop.
4. **The Mac was not measured.** V2-005 sensors ran about 2–3× faster on Shabaz's Mac, but this says nothing certain about the bridge there.

## Screenshot

`bridge-app-tick1000.png`: real `exportapp` capture of the app at tick 1,000, paused, with bridge coverage, 37 markers and the event table. **Synthetic default scene with no scenario targets, so it is not VALIDATION evidence and these events are not detections of anything.** Rebuild interval 100 ticks.

## Not implemented

- Event selection and evidence crops in the UI. `src.inspect(id)` is ready and tested, but no panel calls it.
- A `mgv2MissionControl` entry point that binds the source; callers must call `src.bindSession(app.Session)`.
- Scenario features in a UI session. `MissionSession` has no such input, so live UI runs use the default scene only.
- Rebuild cost reduction beyond the tick-based cache.
- Testing against Shabaz's Stage 2 UI, or on the Mac.

Proposed seam changes: `v2/docs/V2_007_BRIDGE_SEAM_PROPOSAL.md`.
