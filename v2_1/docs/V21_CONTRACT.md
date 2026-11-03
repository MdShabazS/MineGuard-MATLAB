# V2.1 frozen cross-team contract

**Contract:** `mg-v21-contract/1.0` · **Frozen:** 2026-11-04 · **Owner:** Shabaz (V21-001) · **Consumers:** Rahil (V21-005 to V21-008)
**Code mirror:** `v2_1/matlab/+mgv21/contract.m` returns the constants below. If this file and the code disagree, that is a bug; report it on the contract PR.

SIMULATION ONLY. Targets are private synthetic hypotheses. Every detector output stays a SUSPECTED anomaly. The V2.1 evaluation is an **INTERACTIVE SYNTHETIC DEMO evaluation**, not held-out scientific accuracy.

Changes after the freeze follow these rules:
- A change needs a new contract version (`1.1`) in a PR that names the change.
- Adding an optional output field is compatible.
- Renaming or removing a field or function is not compatible.

## 1. Path and packages

```matlab
addpath('v2/matlab'); addpath('v2_1/matlab');   % V2.1 builds on V2; V2 code is not modified
```

| Package | Owner | Visibility |
|---|---|---|
| `mgv21.scenario` | Shabaz (V21-002) | PUBLIC: presets, survey geometry, PublicMissionConfig |
| `mgv21.placement` | Shabaz (V21-003) | PRIVATE: placement spec, PrivateTargetTruth, private SurfaceFeatures |
| `mgv21.evaluation` | Shabaz (V21-004) | EVALUATOR: post-run only |
| `mgv21.contract` | Shabaz (V21-001) | constants |

## 2. Data objects

| Object | Schema | Visibility | Who may hold it |
|---|---|---|---|
| `SurveySpec` | `mg-v21-survey/1.0` | public | UI setup panel, planner |
| `PublicMissionConfig` (`pub`) | `mg-v21-public/1.0` | public | engine, sensors, detector, live map, export |
| `PlacementSpec` (`spec`) | `mg-v21-placement/1.0` | **private** | guide's SETUP panel and the placement functions only |
| `PrivateScenario` (`priv`) | `mg-v21-private/1.0` | **private** | the session's private slot; `SensorSystem(SurfaceFeatures=)`; the evaluator |
| `PrivateTargetTruth` (`priv.truth`) | `mg-v21-truth/1.0` | **evaluator only** | `mgv21.evaluation.evaluateRun` |
| `DemoEvaluation` (`R`) | `mg-v21-eval/1.0` | shown after the run | results panel |

### SurveySpec

These are the fields of `s`.

| Field | Type and unit |
|---|---|
| `schema_version` | `"mg-v21-survey/1.0"` |
| `boundary_kind` | `"RECTANGLE"` or `"POLYGON"` |
| `polygon_enu_m` | N×2 ENU metres (x east, y north), 3 ≤ N ≤ 32 |
| `home_enu_m` | 1×2 ENU metres |
| `line_spacing_m` | metres |
| `heading_deg` | compass degrees, normalised to [0, 360) |
| `alt_agl_m` | metres above ground |
| `speed_mps` | m/s |

### PublicMissionConfig

These are the fields of `pub`.

| Field | Content |
|---|---|
| `schema_version` | `"mg-v21-public/1.0"` |
| `preset_id` | the environment preset |
| `scene_config` | V2 scene config, accepted by `mgv2.scene.buildWorld` |
| `mission` | V2 MissionConfig, already passed through `mgv2.mission.validateConfig` |
| `environment_mode` | `"DAY_CLEAR"`, `"LOW_CONTRAST"` or `"OVERCAST"` |
| `survey` | the normalised SurveySpec |

`pub` never contains placement or truth data. It passes `mgv21.scenario.assertPublic`.

### PlacementSpec

These are the fields of `spec`.

| Field | Content |
|---|---|
| `schema_version` | `"mg-v21-placement/1.0"` |
| `mode` | `"NONE"`, `"MANUAL"` or `"RANDOM"` |
| `seed` | RANDOM target seed, integer in [0, 2^32) |
| `clutter_seed` | integer in [0, 2^32) |
| `count` | RANDOM target count, 0 to 50 |
| `visible_fraction` | in [0, 1] |
| `min_spacing_m` | default 3 |
| `edge_margin_m` | default 1 |
| `exclusion_zones` | struct array with fields `kind` (`"CIRCLE"` or `"POLYGON"`), `center_enu_m`, `radius_m`, `polygon_enu_m` |
| `manual` | table with columns `x_east_m`, `y_north_m`, `surface_signature`, `burial_depth_m` |

### PrivateScenario

These are the fields of `priv`.

| Field | Content |
|---|---|
| `schema_version` | `"mg-v21-private/1.0"` |
| `truth` | PrivateTargetTruth |
| `surface_features` | validated by `mgv2.sensors.validateSurfaceFeatures` |
| `n_clutter` | number of clutter features |

### PrivateTargetTruth

These are the fields of `priv.truth`.

| Field | Content |
|---|---|
| `schema_version` | `"mg-v21-truth/1.0"` |
| `mode` | placement mode |
| `seed` | placement seed |
| `generator` | `"mrg32k3a"` |
| `targets` | table with columns `target_id`, `x_east_m`, `y_north_m`, `surface_signature`, `burial_depth_m` |
| `preset_id` | the environment preset |
| `polygon_enu_m` | survey polygon |

`surface_signature` is `"VISIBLE_DISTURBANCE"` or `"NONE"`.

### DemoEvaluation

These are the fields of `R`.

| Field | Content |
|---|---|
| `schema_version` | `"mg-v21-eval/1.0"` |
| `label` | `"INTERACTIVE SYNTHETIC DEMO evaluation - not held-out scientific accuracy"` |
| `run_state` | terminal phase of the run |
| `r_match_m` | match radius |
| `n_events`, `n_targets` | counts |
| `TP`, `FP`, `FN` | counts |
| `TN` | always `NaN` |
| `precision`, `recall` | `NaN` when undefined |
| `FN_visible`, `FN_no_signature`, `TP_no_signature` | counts |
| `match_error_m` | per match |
| `mean_match_error_m`, `max_match_error_m` | `NaN` if there are no matches |
| `matched_event_index` | per match |
| `placement_mode`, `placement_seed` | from the truth |

## 3. Function signatures (frozen)

```matlab
c     = mgv21.contract()

% --- mgv21.scenario (PUBLIC) -----------------------------------------------------------
ids   = mgv21.scenario.presetIds()                       % ["TRAINING_FIELD_A","ROCKY_UPLAND","DRY_FLATS"]
p     = mgv21.scenario.environmentPreset(id)             % preset_id,title,description,scene_config,environment_mode,bounds_enu_m,default_survey
s     = mgv21.scenario.defaultSurvey(id)                 % SurveySpec of preset id
P     = mgv21.scenario.rectangleBoundary(xmin, xmax, ymin, ymax)   % 4x2, counter-clockwise
[s, report] = mgv21.scenario.validateSurvey(s, id)       % geometry + planner check, no terrain
[s, report] = mgv21.scenario.validateSurvey(s, id, world)% + terrain clearance / geofence ceiling
[pub, plan] = mgv21.scenario.buildPublicMission(id, s)   % plan = mgv2.mission.planSurvey(pub.mission)
[pub, plan] = mgv21.scenario.buildPublicMission(id, s, RunId=..., MissionSeed=..., World=world)
world = mgv21.scenario.buildWorld(pub)                   % = mgv2.scene.buildWorld(pub.scene_config)
mgv21.scenario.assertPublic(x, where)                    % mgv2 firewall + V2.1 private names

% --- mgv21.placement (PRIVATE) -----------------------------------------------------------
spec  = mgv21.placement.defaultPlacement(mode)           % mode "NONE" (default) | "MANUAL" | "RANDOM"
spec  = mgv21.placement.addTarget(spec, xy, signature, burialDepth)   % MANUAL; signature default "VISIBLE_DISTURBANCE"
spec  = mgv21.placement.moveTarget(spec, k, xy)          % k = row of spec.manual
spec  = mgv21.placement.deleteTarget(spec, k)
spec  = mgv21.placement.addExclusionZone(spec, "CIRCLE", centerXY, radius)
spec  = mgv21.placement.addExclusionZone(spec, "POLYGON", P)
[ok, reason] = mgv21.placement.checkLocation(spec, pub, world, xy)    % for live SETUP feedback, no throw
[truth, report] = mgv21.placement.placeTargets(spec, pub, world)
[fwd, info]     = mgv21.placement.forwardFeatures(truth, spec, pub, world)
priv  = mgv21.placement.lockScenario(spec, pub, world)   % = placeTargets + forwardFeatures, firewall-checked
M     = mgv21.placement.setupMarkers(spec, phase)        % table x_east_m,y_north_m,surface_signature;
                                                         % EMPTY unless phase=="SETUP" and mode=="MANUAL"

% --- mgv21.evaluation (EVALUATOR, after the run only) -------------------------------------
R     = mgv21.evaluation.evaluateRun(events, truth, runState)          % runState in COMPLETE|ABORTED|FAILED
R     = mgv21.evaluation.evaluateRun(events, truth, runState, RMatch=1.0)
lines = mgv21.evaluation.formatReport(R)                 % string array for the results panel
```

`events` is either a struct array with `x_est_m` and `y_est_m`, or an N×2 matrix of FROZEN event positions. These are the final detector events of the run.

## 4. Error identifiers

| ID | When |
|---|---|
| `mgv21:UnknownPreset` | preset id not in `presetIds()` |
| `mgv21:InvalidSurvey` | bad polygon, setting, geofence, terrain clearance, or planner refusal; the message names the reason |
| `mgv21:InvalidPlacement` | a MANUAL target is outside the boundary or margin, in an exclusion zone, on an object or landmark, or too close to another target; or a bad spec value |
| `mgv21:PlacementInfeasible` | RANDOM cannot place `count` targets under the constraints; no partial result is returned |
| `mgv2:TruthLeak` | private names in a public record (V2 firewall, reused) |
| `mgv21:EvaluationTooEarly` | `evaluateRun` called before the run reached a terminal phase |
| `mgv21:InvalidEvents` | events are not finite N×2 positions |

## 5. Integration rules for Rahil (V21-005 to V21-008)

1. **SETUP:**
   - The UI edits `s` and `spec`.
   - Draw `mgv21.placement.setupMarkers(spec, "SETUP")` on the map. Use `checkLocation` for click feedback.
   - Show a validation error message instead of a plan when `validateSurvey` or `buildPublicMission` throws.
2. **LOCK:**
   - Run `priv = mgv21.placement.lockScenario(spec, pub, world)`.
   - Call `setupMarkers(spec, "LOCKED")`, which returns empty, and clear every target marker.
   - Keep `priv` out of every public view, log and export.
3. **RUN:**
   - Build the sensors with `mgv2.sensors.SensorSystem(world, pub.mission, SensorConfig=..., Environment=mgv2.sensors.defaultEnvironment(pub.environment_mode), SurfaceFeatures=priv.surface_features)`.
   - Build the engine with `mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(world))`.
   - The detector, live map and navigation never receive `priv` or `spec`.
4. **AFTER THE RUN (terminal phase):**
   - Freeze the event list.
   - Then call `R = mgv21.evaluation.evaluateRun(events, priv.truth, engine.Phase)`.
   - Show `formatReport(R)` with the DEMO label visible.
5. **EXPORT and REPLAY:**
   - The operator export contains `pub` only.
   - If truth is kept for a guide's post-run review, it goes in a **separately named private file**, never in the operator package. Packaging it is V21-007's decision and needs its own test.
6. **Never:**
   - run V1 or V2 sealed TEST groups;
   - call `mgv2.eval.runScenario` on a TEST group;
   - change V2 detector thresholds;
   - claim LiDAR detects buried targets (surface features are flat, so LiDAR cannot see them).
