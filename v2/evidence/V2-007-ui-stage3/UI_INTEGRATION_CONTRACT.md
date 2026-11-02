# V2-007 UI integration contract for the bridge adapter

SIMULATION ONLY. Rahil owns the adapter. This file states what the UI at PR #67's latest tested SHA (see `final-verification/README.md`) offers and expects. All new methods are optional, and bridge `7e89e70` works unchanged (19/19 in a local merge).

## Provided by the UI

| Call | When | Purpose |
|---|---|---|
| `bindRun(world, missionCfg)` | Once per engine, before its first pose and sample, also after reset and scenario change | Session's own public world and mission. Replaces `bindSession`, held samples and manual binding |
| `onPose(pose)` | Every executed pose exactly once, starting at tick 0, before that tick's samples | Feed `MissionMap.addPose`. Replaces the adapter's own engine subscription |
| `reset()` | Before the new `bindRun` | Clear run state. `MissionConfig` may have a new run id and seed |

## Required from the adapter

1. `suspectedEvents()` is called once per `RenderEvery` ticks, on status frames only. Keep rebuild decisions inside the adapter, and do not skip ingesting any sample or pose.
2. `sourceInfo()` should add `events_as_of_tick` and `events_as_of_t_s`. **The tick must change whenever events or layers change.** While it is unchanged, the UI skips validation and table redraws, and shows the age, flagged above 5.5 simulated seconds.
3. Events pass `mgv2.ui.validateEvents(ev, runId)`: unique public `event_id`, this run's `run_id`, SUSPECTED, finite estimate. On failure the UI shows no overlays, displays the error and continues the run.
4. Layers pass `mgv2.ui.validateMapLayers`. A raster needs `cdata` of numel(y)-by-numel(x)-by-3 and `alpha` in [0, 1], with **alpha 0 for UNOBSERVED**. Raster layers follow the Coverage toggle, and all others follow Suspected. Provide event markers as a `points` layer so they can be clicked.
5. `inspect(eventId)` returns a struct that passes `mgv2.ui.validateInspection`, or throws. `mgv2.detect.inspectEvent` with a sensor log already matches. **Every record needs `verified_against_sensor_log = true`. Never return a substitute frame.**
6. Pass no private truth: `mgv2.sensors.assertPublic` runs on events, layers and inspections.

## Evidence context

The agreed interface with #91, replacing the earlier `bindSensorLog` proposal, which is removed.

- `AnomalySource.bindEvidence(provider)` is an optional no-op, called once per session in the `MissionSession` constructor, before the first `bindRun`.
- `provider()` calls `MissionSession.evidenceContext()`, defined once, and returns a copy of `run_id`, `generation`, `state`, `tick` and `sensor_log`. `generation` changes on every `build` and is already updated when `bindRun` is called.
- `MissionSession.inspect(id)` validates the source's record. `inspectCurrentRun(id)` also checks each record's frame, tick and checksum against the current log, and the dashboard calls this one.
- If reading or validating source output fails for any reason, the session shows no overlays and displays the error, and the run continues.

## Remaining adapter work

- #91 binds through `bindRun`, `onPose` and `bindEvidence`.
- Decide the refresh interval. It is a scientific-display choice for Shabaz and Rahil, and the UI shows the age whichever is chosen.
- Reduce rebuild stalls under #76 with a parity review. This remains the largest integrated cost, and the UI cannot fix it.
- Run target-free, missing-sensor and tamper cases on the real detector, then the 3-run Mac and Windows benchmarks.
