# V2-006 to V2-007 integration boundary

SIMULATION ONLY. Events are SUSPECTED, and scores and uncertainty are uncalibrated. A live event says nothing about whether it matches a target: VALIDATION found zero targets (`v2/evidence/V2-006.md` §4).

**Scope.** This documents how the V2-006 public interfaces can reach the UI on `feature/V2-007-ui-shabaz`, read at commit `4da9701`. Nothing on that branch was changed. The adapter is not committed here, because `mgv2.ui.AnomalySource` does not exist on the V2-006 branch. It belongs to governed V2-007 integration.

## 1. The seam

The UI's only entry point is the abstract class `mgv2.ui.AnomalySource`: `onSample`, `suspectedEvents`, `mapLayers`, `sourceInfo`, `reset`. V2-006 exposes different names and fields, so **an adapter subclass is required**. Do not rename detector methods or change the `mg-v2-detector/1.0` contract to suit the UI.

| UI calls | Adapter uses |
|---|---|
| `onSample(s)` | `det.ingest(s)` and `map.addSample(s)` |
| `suspectedEvents()` | `det.events()`, mapped per §2 (**the detector has no `suspectedEvents()`**) |
| `mapLayers()` | `map.snapshot()`, converted per §3 |
| `sourceInfo()` | `connected = true`, `detector_version` from `det.Config` |
| `reset()` | New `AnomalyDetector` and `MissionMap`; neither has a reset method |

## 2. Event mapping (`mgv2.ui.validateEvents`)

| UI field | Source in the V2-006 event | Note |
|---|---|---|
| `event_id`, `run_id`, `x_est_m`, `y_est_m`, `model_score`, `uncertainty_m`, `status`, `detector_version`, `evidence_refs` | Same name | Copy unchanged |
| `t_s` | `last_t_s` | **Adapter decision: not in the V2-006 event.** It means latest sighting; `first_t_s` is also available |
| `confidence_kind` | `score_kind` | Keeps "UNCALIBRATED_HEURISTIC_SCORE (not a probability)" |
| `modality_flags` | `detection_basis` | `FUSED_RGB_THERMAL`, `SINGLE_CHANNEL_RGB` or `SINGLE_CHANNEL_THERMAL` |

## 3. Map layers (`mgv2.ui.validateMapLayers`)

- Coverage maps to one `raster` layer: `x_enu_m = cell_x_m`, `y_enu_m = cell_y_m`, with `cdata` and `alpha` from `cell_state` and `mgv2.map.MapView.StateRGBA`. `UNOBSERVED` cells have alpha 0, so they stay absent as the validator requires.
- Set `revision` to change when data changes, because the panel redraws only then.
- Keep `snapshot().coverage.meaning` with any coverage display: coverage is evidence acquisition, not accuracy and not a land-release statement.

## 4. Evidence references

- `event.evidence_refs` holds `ref_id`, `frame_id`, `sensor_id`, `tick_id`, `pose_id`, `t_s` and `sample_checksum`.
- `det.evidence(ref_id)` returns the retained record, including the crop. At most 4 records per modality are retained per track. A pruned or missing record raises `mgv2:EvidenceMissing`.
- `mgv2.detect.inspectEvent(e, det, sensorLog)` verifies the references and raises `mgv2:EvidenceMismatch` on any difference. Show that error; do not substitute another frame.
- The UI needs a new adapter method for this, because the seam passes no detector and its inspector panel lists events only. `inspectEvent` needs the original V2-006 event struct, so keep it available by `event_id`.

## 5. Truth boundary

- The adapter takes public samples, plus the same public world and mission as the session. Never pass `mgv2.eval.buildScenario` outputs, an evaluator result or a known fixture id into it or into live UI logic.
- `MissionSession` does not supply surface features, so a UI session flies the default scene with no scenario features or targets.
- The EventId option in `mgv2DetectionDemo` is for offline demonstration only.

## 6. Issues integration must handle

| Issue | Status |
|---|---|
| **Same world and mission.** `MissionSession` builds its own world, and the adapter needs the same one or ingested `run_id`s are rejected as `RUN_MISMATCH` | Constructor argument in the check below |
| **No poses through the seam.** `onSample` gives samples only, so `MissionMap.Route` and `Traversed` stay empty and no `TRAVERSED` cell appears. The UI draws its own route | Needs a decision in V2-007: pass poses or accept this |
| **`view()` cost.** One `view()` took 445 ms at tick 400 (`suspectedEvents` 262 ms, `mapLayers` 33 ms), and cost grows with tracks. **Calling it every UI refresh will stall the display** | Cache or throttle in the adapter; not yet implemented or benchmarked |
| **Event ids and positions can change.** Merged tracks drop their event id, and positions update as sightings accumulate | The UI should not assume a permanent row |
| **Single-channel events** appear in FUSED mode | Show `modality_flags` |
| **Inspector.** Click-through and evidence frames are not implemented on the UI branch | V2-007 |

## 7. What was checked

Read-only check on Windows R2026b, using an export of `+mgv2/+ui` from `4da9701` in a scratch folder and an uncommitted prototype adapter implementing §1–3 on the V2-006 source:

```text
adapter: 400 ticks, UI view() validated 14 events and 1 layer(s), one view() 445 ms, state ACTIVE, connected 1
suspectedEvents alone 262 ms; mapLayers alone 33 ms
after reset: 0 events, tick 0
```

This shows that the mapped events and layer pass Shabaz's validators, and that reset clears run state, for one partial run. **It does not test** the full app, panel rendering, a full mission, performance under a live UI, or the Mac. No V2-007 test was run.
