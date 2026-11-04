# V2.1 architecture

V2.1 is a separate layer, `v2_1/matlab/+mgv21`, that **calls** V2 (`v2/matlab/+mgv2`) and never edits it.

```
 SETUP (guide)                         LOCK                         RUN                                 AFTER RUN
 ─────────────                         ────                         ───                                 ─────────
 preset id ─► environmentPreset                                     MissionEngine(pub.mission, terrain)
 SurveySpec ─► validateSurvey ─► buildPublicMission ─► pub ───────► SensorSystem(world, pub.mission,      events (frozen)
                                         │                 │         Environment, SurfaceFeatures=priv.   │
                                         ▼                 │         surface_features)                    ▼
                                    buildWorld ─► world ───┤        detector / live map / export:     evaluateRun(events,
 PlacementSpec ─► setupMarkers (SETUP only)                │        PUBLIC samples + pub ONLY           priv.truth, phase)
   add/move/delete, exclusion zones, checkLocation         ▼                                              │
                                              lockScenario(spec,pub,world) ─► priv (PRIVATE slot) ─────────┘
                                              = placeTargets ─► truth  +  forwardFeatures ─► surface_features
```

## Visibility

| Layer | Sees `pub` | Sees `spec` | Sees `priv.surface_features` | Sees `priv.truth` |
|---|---|---|---|---|
| Navigation / engine | yes | no | no | no |
| Sensor forward models (RGB, thermal) | yes | no | **yes** | no |
| LiDAR | yes | no | no effect (flat features) | no |
| Detector, live map, operator export | yes | no | no | no |
| Guide SETUP panel | yes | yes (until LOCK) | no | no |
| Evaluator (after a terminal phase) | yes | no | no | **yes** |

## Ownership

| Task | Owner | Files |
|---|---|---|
| V21-001 | Shabaz | `v2_1/README.md`, `v2_1/docs/*`, `v2_1/tasks/*`, `+mgv21/contract.m` |
| V21-002 | Shabaz | `+mgv21/+scenario/*`, `v2_1/tests/testV21Scenario.m` |
| V21-003 | Shabaz | `+mgv21/+placement/*`, `v2_1/tests/testV21Placement.m` |
| V21-004 | Shabaz | `+mgv21/+evaluation/*`, `v2_1/tests/testV21Evaluation.m` |
| V21-005 to V21-008 | Rahil | UI, `MissionSession` private slot, export/replay, Windows tests (V2 files touched by Rahil only) |

V2.1 does not use `polyshape` for user input, because its constructor repairs bad input silently. It uses core MATLAB (`inpolygon`, explicit edge tests) and `RandStream("mrg32k3a")`. It needs no new toolbox.
