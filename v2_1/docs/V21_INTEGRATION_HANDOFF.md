# V2.1 integration handoff: Shabaz → Rahil

**Contract:** `mg-v21-contract/1.1` (`V21_CONTRACT.md`). Integrate against the function names in §3 of that file. They are frozen.

## Delivered by Shabaz (Mac, no MATLAB execution)

| PR | Content | MATLAB tests |
|---|---|---|
| Contract PR (V21-001) | docs, tasks, `mgv21.contract` | none |
| Scene/grid PR (V21-002) | `mgv21.scenario.*`, `testV21Scenario.m` | written, **NOT RUN** |
| Placement/evaluation PR (V21-003/004) | `mgv21.placement.*`, `mgv21.evaluation.*`, two test files | written, **NOT RUN** |

## Rahil's first actions (Windows)

```matlab
addpath('v2/matlab'); addpath('v2_1/matlab');
f = dir('v2_1/matlab/+mgv21/**/*.m'); checkcode(fullfile({f.folder}, {f.name}))   % expect no errors
results = runtests('v2_1/tests'); table(results)          % 48 test methods (50 points); record counts and SHA in v2_1/evidence/
```

If a test fails because of a defect in Shabaz's foundation code:
- Fix it on the matching branch, or open an issue with the failing test name.
- Do not weaken a test to make it pass.

## Integration points (V21-005 to V21-008)

1. **`MissionSession`:** add a private property, for example `PrivateScenario`, with `Access = private`. Pass `SurfaceFeatures=priv.surface_features` into `SensorSystem` inside `build`. Nothing in `view`, `evidenceContext`, `packageInputs` or export may read it.
2. **Setup UI:**
   - Preset dropdown: `presetIds()`.
   - Boundary editor: `rectangleBoundary`, or vertex table to `SurveySpec`.
   - Grid fields, then `buildPublicMission`. On error, show `err.message` and no plan.
3. **Placement UI:**
   - Mode selector.
   - Map clicks go through `checkLocation`, then `addTarget`, `moveTarget` or `deleteTarget`.
   - Draw only `setupMarkers(spec, phase)`.
   - Lock button: `lockScenario`, then redraw. Markers are gone.
4. **Results panel:** after the engine reaches `COMPLETE`, `ABORTED` or `FAILED`, freeze the events, then show `formatReport(evaluateRun(events, priv.truth, phase))`.
   - **Matched/missed colouring (1.1):**
     - Matched targets are `R.matched_target_index`.
     - Missed targets are `setdiff(1:R.n_targets, R.matched_target_index)`.
     - True-positive events are `R.matched_event_index`; every other event is a false positive.
     - Draw a line for pair k between event `matched_event_index(k)` and target `matched_target_index(k)`.
     - Do not re-match by nearest distance in the UI; it can disagree with the one-to-one assignment.
5. **Export:** `pub` only. Truth files, if any, go in a separate private file (V21-007 decision and test).

## Known limitations

- **Colours:** presets cannot change soil colours. The V2 `buildWorld` palette is fixed in code, and V2 code is not edited.
- **Boundary shape:** non-convex boundaries are rejected because the V2 planner is convex-only.
- **Flight time:** the timeout check is an estimate. The engine's own timeout remains authoritative.
- **Sensor coverage:** the sensor swath versus line spacing is not checked.
- **Status tracking:** there is no CI gate for `v2_1/tasks` yet, so status changes are reviewed by hand.
