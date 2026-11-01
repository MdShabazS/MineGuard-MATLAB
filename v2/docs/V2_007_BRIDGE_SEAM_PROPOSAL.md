# V2-007 UI seam change proposal (for Shabaz's decision)

**Status: proposal only. Nothing in `+mgv2/+ui` was changed.** The bridge works today through `src.bindSession(ses)` on the published UI at `4da9701`. These changes would remove workarounds and make acceptance possible. Measurements: `v2/evidence/V2-007-bridge/README.md`.

SIMULATION ONLY. VALIDATION remains negative, so none of this improves detection.

## 1. Late source binding

**Today.** `MissionSession` receives the source before it builds its world, mission and engine. The bridge therefore holds tick-0 samples, and callers must remember to call `bindSession`. A forgotten bind shows `DETECTOR BRIDGE NOT BOUND`.

**Proposed.** An optional method on `AnomalySource`, default no-op, called by `MissionSession.build()` before `Sensors.attach`:

```matlab
bindRun(obj, world, missionCfg)
```

This removes the held samples and the manual bind, and it also handles reset.

## 2. Pose updates

**Today.** The seam has no pose callback, so the bridge subscribes directly to `ses.Engine` and re-attaches on the first sample after a reset. It works and is tested (b06, b07), but it depends on the order of statements in `MissionSession.build()`.

**Proposed.** `onPose(obj, pose)`, default no-op, subscribed once per engine in `build()`. `MapPanel` keeps sole ownership of the displayed route; poses only feed the coverage `TRAVERSED` state.

## 3. Event-click evidence

**Today.** `EventInspectorPanel` lists events only.

**Proposed.**
- Optional source method `ins = inspect(obj, eventId)`. The bridge already has it (b13–b15).
- A table selection callback that shows crops from `ins.items`, the frame, tick and checksum, and the text "uncalibrated".
- On `mgv2:EvidenceMissing`, `mgv2:EvidenceMismatch` or `mgv2:EventNotFound`, show the error. Never show a substitute frame.
- Event rows can disappear when tracks merge, so a selection must tolerate that.
- A call to `inspect` itself triggers a rebuild if data is new (up to about 1.2 s on Windows), so it should run only on a click.

## 4. Refresh and cache budget

**Measured on Windows (not Mac).** No bridge configuration reached 1×. Headless: 1.19× with no detector, 0.74× with a 100-tick rebuild interval, 0.52× with 20. Real window, first position: 0.73× without the bridge and 0.54× with it. `onSample` alone costs about 46 s per mission. Rebuilds grow to about 1.2 s.

**Decisions needed**

| # | Decision | Recommendation |
|---|---|---|
| a | Rebuild interval | 100 ticks (5 simulated seconds) for now, shown with its age. Re-measure on the Mac before fixing a value |
| b | Validation on every `view()` | Let `MissionSession` skip `validateEvents` and `validateMapLayers` when `sourceInfo` reports the same `events_as_of_tick`. Saves about 8 ms per view. The bridge already validates on each rebuild |
| c | Show staleness | Display `stale_ticks` or `events_as_of_t_s`. The status text has the as-of time today |
| d | Rebuild stall | The rebuild blocks the mission loop. Options are to rebuild between runs and on pause only, to accept longer staleness, or to make the track table incremental. That last one is a V2-006 code change needing its own review, even with thresholds untouched, and must keep identical outputs |
| e | Pacing target | Should the acceptance target be 1×, or the provisional 0.8× presentation requirement from V2-005? Neither is met on this Windows host with the bridge |

## 5. Open question for Shabaz

Whichever app window ran second in one MATLAB call was about twice as slow, including with no bridge, and in panels the bridge does not touch (`scene_ms` about 2.3 vs about 5 ms). Cause not diagnosed; only one run of each order was made. It may be worth checking on the Mac with Stage 2, for example whether `delete(app)` releases everything.

## Integration order

1. Shabaz finishes Stage 2 without interruption.
2. Review this proposal and agree items 1–4.
3. Rebase the bridge on Stage 2, then rerun all suites and benchmarks on Windows and the Mac.
4. Only then consider a governed V2-007 PR. PR #66 still needs independent Mac acceptance and its DONE PR first.
