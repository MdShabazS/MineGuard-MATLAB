# V2.1 research notes (V21-001)

**Date:** 2026-11-04 · **Author:** Claude Code for Shabaz · **Baseline:** `main` `98e0c9e`
**Method:** read the V2 source on `main`, and checked the MathWorks R2026b documentation pages below. No MATLAB was run on the Mac.

## 1. What V2 already provides (read from source)

| V2 function | Fact that constrains V2.1 |
|---|---|
| `mgv2.mission.defaultConfig` / `validateConfig` | Exact field allowlist; anything else (targets, truth) is rejected. Polygon must be N×2, finite, **counter-clockwise, convex**, inside `bounds_enu_m`. Requires `alt_agl_setpoint_m > min_clearance_m` (4 m) and `speed_mps ≤ max_speed_mps` (8). `timeout_s` = 900. |
| `mgv2.mission.planSurvey` | Boustrophedon over a **convex** polygon only; throws `mgv2:UnreachableMission` if no line fits. Returns `survey_length_m`, which V2.1 uses for a flight-time check. |
| `mgv2.scene.defaultSceneConfig` / `buildWorld` | Scene config has an exact allowlist: `seed`, `extent_enu_m`, `grid_spacing_m`, `relief_m` (0–50), `slope`, home, polygon, `n_rocks`, `n_bushes`, `landmarks`. The terrain (Fourier relief, one mound, one gully), objects and albedo all come from the seed. **The colour palette is fixed in code**, so V2.1 presets differ in terrain shape, relief, slope, object density and lighting, not in soil colours. |
| `mgv2.sensors.SensorSystem(..., SurfaceFeatures=F)` | The private forward-model hook. Flat features only change RGB and thermal; LiDAR geometry is unchanged. |
| `mgv2.sensors.validateSurfaceFeatures` | Exact fields, no identity or class field. An empty list is bit-identical to V2-005. |
| `mgv2.sensors.defaultEnvironment` | Modes `DAY_CLEAR`, `LOW_CONTRAST`, `OVERCAST`. |
| `mgv2.sensors.assertPublic` | Firewall: rejects forbidden field names (`target_id`, `truth`, `burial_depth_m`, `label`, ...) at any depth, and rejects objects. |
| `mgv2.eval.buildScenario` | Reference for overlapping clutter/target distributions (SOIL / WET / SCRAP vs disturbed soil), and the rule that no-signature targets use their own stream after all observable features. Fixed 40×28 m polygon, so it is **not reusable** for user-chosen geometry. V2.1 reuses its distribution constants. |
| `mgv2.eval.evaluateEvents(xy, TargetTruth, rMatch)` | Greedy one-to-one match within `rMatch`. TN = NaN; precision and recall are NaN when undefined. With an explicit `rMatch`, it does not touch the split manifest or any TEST group. **Reused as-is** by V2.1. |
| `mgv2.eval.runScenario` | Refuses TEST groups (`mgv2:TestSealed`). V2.1 never calls it. |
| `mgv2.ui.MissionSession` | Builds `SensorSystem(world, MissionConfig, SensorConfig, Environment)` **without** `SurfaceFeatures` today. V21-005/006 (Rahil) must add the private slot. |
| `mgv2.engine.MissionEngine` | Terminal phases `COMPLETE`, `ABORTED`, `FAILED`. |

## 2. MathWorks documentation checked

| Topic | Page | Finding used |
|---|---|---|
| `polyshape` | https://www.mathworks.com/help/matlab/ref/polyshape.html | With the default `Simplify=true`, the constructor **silently repairs** self-intersecting input (with a warning). The bow-tie example becomes 2 regions. V2.1 therefore validates simplicity and convexity itself, and never relies on `polyshape` to accept user input. |
| `isinterior` | https://www.mathworks.com/help/matlab/ref/polyshape.isinterior.html | Boundary points count as interior; `[in,on]` separates them. V2.1 uses core `inpolygon` (same boundary rule) plus an explicit edge-distance margin. |
| `RandStream` | https://www.mathworks.com/help/matlab/ref/randstream.html | `RandStream("mrg32k3a", Seed=s)` with seed 0 to 2^32−1. `mrg32k3a` supports substreams. V2.1 uses a dedicated stream per purpose: targets (substream 1), signatures (2), visible features (3), clutter (4). The global `rng` is never touched. |
| `uifigure` / `uiaxes` interaction | https://www.mathworks.com/help/matlab/ref/uiaxes.html and https://www.mathworks.com/help/matlab/creating_plots/control-axes-interactions.html | Not verified in this session, and these are V21-005 (Rahil) concerns. Use `ButtonDownFcn` on the map axes in SETUP only, and disable map click placement after LOCK. |
| UAV Toolbox `uavScenario` | https://www.mathworks.com/help/uav/ref/uavscenario.html | Not used by V2.1 foundation code. V2 already exports through `mgv2.scene.toUavScenario`. |

## 3. Design conclusions

1. **Convex only.** The V2 planner supports convex polygons only. V2.1 accepts rectangles and convex polygons. It **rejects** non-convex and self-intersecting boundaries with a reason, and does not silently take the convex hull, because that would fly over ground the user excluded.
2. **Orientation:** clockwise input is reversed to counter-clockwise and reported (`report.polygon_reordered`). No geometry is lost.
3. **Flight-time check:**
   - Estimated time = preflight + climb + transit + survey + return + descent.
   - It must be ≤ 80 % of `timeout_s`.
   - Otherwise the route is rejected rather than shown as a plan that would time out.
   - This is an engineering estimate. The engine's real timeout remains the authority.
4. **Terrain clearance:**
   - The engine flies terrain-following at `alt_agl_m`.
   - V2.1 requires `alt_agl_m − 1.5 m` (tallest object) ≥ `min_clearance_m`.
   - With a world, it also requires max terrain under the polygon + altitude + 5 m ≤ the geofence ceiling, and min terrain ≥ the geofence floor.
5. **Placement keep-out:**
   - Targets must stay at least `min_spacing_m` apart.
   - Targets must stay at least `edge_margin_m` inside the boundary.
   - Targets must stay outside exclusion zones.
   - Targets must stay at least 0.5 m clear of rocks and bushes, beyond their radius.
   - Targets must stay at least 1.5 m clear of landmarks, beyond their radius.
6. **Signature realism:**
   - A visible target gets a disturbed-soil feature drawn from **the same overlapping distributions as V2** clutter, and clutter patches are always added, so colour or temperature alone does not identify a target.
   - A `NONE` target adds nothing.
   - Clutter keep-out ignores `NONE` targets, so the forward features are identical with or without them (tested).
7. **Evaluation:** this is a thin wrapper over `mgv2.eval.evaluateEvents`, keeping its metric definitions (TN undefined, NaN ratios). It adds the DEMO label, a terminal-phase guard and match-distance summaries.
