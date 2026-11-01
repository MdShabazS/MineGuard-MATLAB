# MineGuard Advanced V2 — Technical Architecture Freeze (V2-001)

**Owner:** Shabaz · **Date:** 2026-11-01 IST · **State:** proposed reviewed architecture / not deployed  
**Companion docs:** V2_SYSTEM_REQUIREMENTS.md and V2_DEMO_ACCEPTANCE_MATRIX.md  
**Purpose:** one buildable architecture to hand to Rahil/Claude Code without changing V1 science or pretending hardware integration exists.

## 1. Architecture decision record

| Decision ID | Frozen V2 direction | Reason and verified boundary |
|---|---|---|
| ADR-01 | **MATLAB R2026b + UAV Toolbox native scenario** on primary Mac | User tested toolbox functions and visible animated UAV; Mac Unreal integration unsupported |
| ADR-02 | **Separate live simulation engine and view renderer** | V1 precomputed replay is not real-time execution; display must not own physics or science |
| ADR-03 | **One authoritative simulation clock in seconds** | Map, aircraft, sensors, detection, event log and UI must stay synchronized |
| ADR-04 | **ENU metres internally; NED only UAV adapter** | Backward compatible with original MG003, avoids altitude and axis confusion |
| ADR-05 | **Offline-first local mission map** with optional satellite basemap | No live internet should be required during guide demo; satellite tiles are contextual background only |
| ADR-06 | **Scene-based synthetic RGB and thermal frames**; optional recorded research imagery explicitly separate | No fake camera feeds disconnected from terrain; no thermal by purple tinting an RGB photo |
| ADR-07 | **LiDAR primarily terrain, height and geometry**; EM V1 channel as optional proxy | Not a physically justified buried-mine detector at normal UAV height |
| ADR-08 | **Observable-only inference with truth firewall** | Detection claims may not leak hidden synthetic truth; original once-consumed TEST remains untouched |
| ADR-09 | **Reviewable source-based MATLAB uifigure app**, not a video or opaque generated binary | GitHub diff/testability; fits existing project conventions |
| ADR-10 | **V2 separate package namespace and run outputs** | Protect V1 contract, frozen results and release evidence |

### External API basis

- https://www.mathworks.com/help/uav/ref/uavscenario.show3d.html — 3-D scene visualization and FastUpdate via existing axes.
- https://www.mathworks.com/help/uav/ref/multirotorflighttrajectory.html — interpolated multirotor trajectory and NED waypoints. *Trajectory generation alone is not aerodynamic closed-loop control*.
- https://www.mathworks.com/help/uav/ref/uavlidarpointcloudgenerator-system-object.html — scenario-based point clouds from static meshes, with statistical noise.
- https://www.mathworks.com/help/matlab/ref/geoaxes.html — geographic plot with WGS84 and optional hosted satellite basemap.
- https://www.mathworks.com/help/map/ref/addcustombasemap.html — custom/MBTiles support **requires Mapping Toolbox**, not verified on Mac.
- https://www.mathworks.com/help/uav/ug/unreal-engine-simulation-environment-requirements-and-limitations.html — Unreal requires supported Windows/Linux, not Mac.

## 2. Detailed component diagram

~~~
        User chooses local virtual survey field, seed, constraints
                               |
                     V2 MissionConfig (safe)
                               |
      +------------------------v-----------------------+
      | MissionRunner / SimulationClock (AUTHORITATIVE)|
      | fixed-step t_s; RNG streams; deterministic log |
      +-----+---------------+---------------+----------+
            |               |               |
            v               v               v
    MissionStateMachine  Guidance/Flight   Terrain Scene + private
    PREPARE -> TAKEOFF  control + geometry physical truth models
    -> SURVEY -> RTL    pose, vel, attitude        |
    -> LAND -> DONE     ENU <-adapter-> NED        |
            |               |                     |
            +---------------v---------------------+
                            |
                 Simulated sensor scheduler
                    +-------+--------+
                    |       |        |
                 RGB       THERMAL   LIDAR / GPS-INS
                frame      K raster  cloud / range
                    +-------+--------+
                            |
         Narrow, public SensorObservations (NO TRUTH)
                            |
                  Detector / mapper / quality
                            |
                     SUSPECTED events
                            |
             +--------------+-------------------+
             |              |                   |
         Mission App      Recorder        Truth-only evaluator
      3D/map/RGB/IR/LDR  immutable log    (separate invocation)
         read-only        & safe export    summary metrics only
~~~

**Critical separation:** hidden scenario target truth may enter a synthetic *forward* response model and an independent evaluator, but never the navigation planner, classifier input, app or public export. Thus a visually obvious surface target does not grant automatic event detection. The app must not call the evaluator during live mission display to expose hidden truth.

## 3. Data frames, time and geometry

### Reference frames

- Canonical: **ENU**: (x_east_m, y_north_m, z_up_m) in metres; origin is a declared virtual survey datum. Time t_s (double, seconds from mission start). Orientation attitude stored as unit quaternion with **documented component order and ENU body convention**, converted at a single adapter.
- UAV Toolbox native platform: **NED** coordinate conversion only inside UAV adapter: x_N = y_North; y_E = x_East; z_D = -z_Up. Implement round-trip tests on asymmetric triples; do not make two independent sign flips around the app.
- Geographic: virtual WGS84 origin lat/lon; convert East/North offsets via tested local tangent-plane conversion and document validity domain. A synthetic lat/lon is not measured GPS. If Mapping Toolbox unavailable, maintain local ENU map and optionally use a validated small-field geodetic approximation for display only.
- Altitudes: z_up_m (above virtual datum) versus altitude_agl_m = z_up_m - terrainHeight(x,y). Land only when AGL <= touch-down tolerance with nonnegative ground contact. Do not confuse NED negative down coordinate with AGL.
- Camera: sensor extrinsic transform T_body_sensor (metres, orientation); image intrinsics width/height, focal length, FOV. Define pixel-to-terrain projective mapping, footprint corners and validity/occlusion.
- Thermal and RGB data share the world model but may have different resolutions and fields of view; no requirement to show identical pixels.

### Time base and ordering

- Clock source = SimulationClock.t_s, never MATLAB wall-clock for sensor timestamps. nominal engine tick target = **0.05 s / 20 Hz**, adjustable based on profiling; all state changes occur at integer tick indices.
- Each channel has explicit nominal rate and due-time scheduler, e.g. RGB 5 Hz, thermal 5 Hz, LiDAR 2 Hz, map overlay 5 Hz, telemetry 10 Hz, scene 10–20 visual FPS. These are **initial engineering targets**; actual sustainable rates on Mac must be measured.
- Sensor sampling reads a single immutable pose/terrain snapshot at that tick and writes a new observation with (run_id, t_s, pose_id, sample_seq, sensor_id). No observation may silently borrow a pose from a later tick.
- If late, preserve measurement's t_s and mark dropped/late frames; UI must not fabricate a newest measurement by copying old pixels with a new time.
- Controls: pause freezes clock and all sensor/pose outputs, resume continues same seed and sequence, restart resets the deterministic seed, playback loads saved observations without rerunning random draws.
- Wall-clock is used only for performance logs and export timestamp, with separate monotonic measurement.

## 4. Versioned V2 data envelope

The following fields are a **minimal cross-team envelope**; detailed modality schema, camera calibration, detector math and exact column order belong to V2-004. Do not alter the V1 frozen contract mg-contract/1.0. Proposed namespace: **mg-v2-contract/1.0** (final subtype schema approved in V2-004).

| Record | Required public fields / meaning | Forbidden or special content |
|---|---|---|
| MissionConfig | schema_version, run_id, scenario_id, seed, dt_s, bounds_enu_m, survey_polygon_enu_m, home_enu_m, virtual_wgs84_origin, alt_agl_setpoint_m, speed_mps, constraints, feature_flags | No target truth sent to navigation/detection |
| PoseSample | run_id, pose_id, tick_id, t_s, position_enu_m[1x3], velocity_enu_mps[1x3], orientation_quat, altitude_agl_m, phase, validity | No real GPS status claim |
| SensorSample common | run_id, sensor_id, seq, pose_id, t_s, valid, invalid_reason, units, data_ref, sensor_model_version, simulated=true, footprint_enu_m | No hidden truth, class label, buried-target depth |
| RGBFrame | SensorSample + uint8 RGB image array [H,W,3] or immutable frame reference, intrinsics, extrinsics, exposure/noise metadata | Scene-driven, NOT unrelated footage |
| ThermalFrame | SensorSample + double temperature_K raster [H,W], display palette and min/max legend, environmental inputs | No use of RGB palette as temperature sensor; K separate from C UI |
| LidarFrame | SensorSample + points in sensor/world frame or ranges + ray directions; range units m; point quality | No inference of underground objects from surface range alone |
| VirtualTelemetry | PoseSample + reported GPS-like position, sim battery estimate, nav-state and validity | simulation label required |
| SuspectedEvent | event_id, run_id, t_s, x_est_m, y_est_m, model_score, confidence_kind, modality_flags, evidence_refs, uncertainty_m, status=SUSPECTED, detector_version | No real mine confirmation; uncertainty may be unavailable, not forced 0 |
| ExportManifest | schema_version, code_hash, parameters_hash, seed, frames_and_units, environment inventory, sample counts, checksum, warning list, research-simulation label | Never export unredacted truth in operator bundle |

**No data_ref supplied means absent/invalid rather than a fabricated data object.** Frame references are within the run package and resolve to actual generated output. Scores must have the explicit term *uncalibrated model score* until true calibration is demonstrated; do not claim probability of a mine.

Detailed MATLAB representation may use typed struct/table rows or immutable immutable-object wrappers; use serializable values in external exports. Every field has a schema version. V2 consumer adapters validate unknown/invalid fields instead of silently accepting them.

## 5. Component boundaries and test obligations

### V2-002 / real-time flight engine / Rahil

- Input: MissionConfig, safe navigation constraints; outputs pose stream + FSM events.
- State set: CONFIGURED, PREFLIGHT, TAKEOFF, CLIMB, TRANSIT, SURVEY, RETURN_HOME, LANDING, COMPLETE; faults ABORTED and FAILED.
- Fixed-grid default; experimental PPO strictly optional and not default. Smooth commanded trajectory + bounded velocity/acceleration/attitude and simulated disturbances. Distinguish kinematic/dynamic model from real Pixhawk control; do not call waypoint interpolation "physics".
- Invalid survey bounds, empty path, unsafe terrain intersection or impossible constraint => informative error / safe stop, not fake mission success.
- Provide deterministic nominal and disturbance scenario. Terrain clearance and geofence handling measured.

### V2-003 / scene & render / Rahil

- Input: terrain mesh, scene config, pose. Outputs canonical geometry, camera transforms and 3-D view. No truth required for geometry surface objects other than renderer's deliberately observable scene materials.
- Prototype fast 2.5-D terrain/cuboid mesh and UAV model using UAV Toolbox. Configure camera follow, isometric, chase and top-down and UI resizing.
- Native mesh / render quality is constrained. Avoid claim of Unreal-level rendering; investigate procedural imagery pipeline as a V2-003 feasibility spike before locking camera frame rates. If no credible RGB scene raster can be rendered, record limitation, implement tested scene-based sampling and bring decision to Shabaz.
- No shared mutable globals and no 3-D renderer code inside detection functions.

### V2-004 / sensor physics & evaluation contract / Shabaz

- Freeze sensor-specific intrinsics, extrinsics, update rates, Kelvin units, ambient/soil/illumination model, noise/dropout, ray geometry and detector-observable allowlist.
- Create evidence source list and new train/validation/fresh sealed-test design for any *new* detector performance claim; prohibit recycled V1 TEST.
- Define at least one positive-looking anomaly, at least two visually ambiguous clutter conditions and negative controls. A fixture where anomaly response is visible is NOT held-out performance evidence.
- Define separate numerical thermal and LiDAR validation checks. A real buried target is not detectable purely by LiDAR height or bright thermal pixel.

### V2-005 / synchronized sensing / Rahil

- Input: canonical pose snapshot plus a restricted forward-model view of terrain/scene truth. Output: actual RGB, thermal and LiDAR sensor samples at scheduled times with precise mounting transforms.
- Thermal data: generate numeric Kelvin raster first, then selectable false-color/White Hot palette; calibrations synthetic only.
- RGB: distinct camera imagery tied to visible scene features and pose, not an unrelated MP4/video. View geometry and footprint match map.
- LiDAR: use UAV Toolbox uavLidarPointCloudGenerator where runtime and available dependencies permit, else a documented geometrical ray/range fallback with equally rigorous validity flags.
- Optional environmental mode: daytime, low thermal contrast, noise and occlusion; avoid promising physical fidelity beyond model assumptions.

### V2-006 / anomaly mapping / Rahil

- Input public SensorSample only, never hidden truth. Output event list and map overlays.
- Methods may include surface-clutter baseline, thermal anomaly threshold and explicit visibility mask. Model scores with uncertainty reason.
- Map displays bounds/home/route/current location/footprint/observed and invalid cells, suspects and evidence selectors. Virtual satellite basemap optional, offline required.
- Truth-only evaluator is called only in research-analysis stage for aggregate metrics. No mine-confirmed icons.

### V2-007 / mission-control application / Rahil

- One source-controlled MATLAB uifigure/uigridlayout entry point. Panels: 3-D, map, RGB, thermal, LiDAR, telemetry, event inspector and controls. Support adaptable compact-screen layout with fullscreen panel.
- UI subscribes to engine snapshots (pull or events), not vice versa; render refresh decimated. No callback blocks engine for seconds. Display latest valid sensor timestamp / stale indicator.
- Reuse V1 run-bundle through an explicit separate adapter for comparison, not as fake "LIVE" feed. Clearly mark REPLAY / SYNTHETIC.

### V2-008 / evidence and performance / Rahil

- Truthful runnable tests executed on the user's Mac: deterministic output and seed, pause/resume, GUI controls, frame-sync, ENU-NED conversions, geo/map alignment, thermal numeric consistency, LiDAR terrain intersections, scenario faults, export/import/hash equality, performance/wall time and headless-friendly unit suite where possible.
- No Node/portal CI or prior Windows MATLAB tests substitute for V2 execution. Record toolboxes, exact git SHA, tester, MATLAB commands, outputs and screenshots.

## 6. Failure containment and dependencies

1. **Native camera rendering feasibility**: Mac UAV Toolbox show3D is mesh/cuboid-based, not photorealistic camera engine. Mitigation: V2-003 early proof-of-geometry + textured view; V2-005 frame generator contingent on validated shared scene. If not viable, disclose limitation and seek explicit revised acceptance, NOT invent imagery.
2. **FPS/GUI performance**: do not render 3-D + 3 high-resolution feeds on every 20 Hz simulation step. Use capped render refresh, reduced frame size and profiling. No fabricated benchmark.
3. **Mapping license**: geoaxes exists in base MATLAB, high-resolution satellite background may require internet; custom basemaps offline require Mapping Toolbox. Core map uses local uiaxes + terrain raster regardless of license.
4. **Scientific validity**: thermal cannot guarantee buried-target contrast; soil and weather affect response. Explicit invalid/out-of-domain conditions and out-of-sample evaluation avoid false certainty.
5. **Timeline/review**: review V2-001 before Rahil begins implementation tasks. V2-004 owner Shabaz should parallelize sensor model research with Rahil V2-002/003 after V2-001 DONE on main.
6. **Security/repo integrity**: No drone flight links, remote control writes, credentials, real trial coordinates or classified data in public repo. Never re-run consumed V1 held-out experiment.

## 7. Handoff and task dependency sequencing

~~~
V2-001 Shabaz (this requirements/architecture baseline)
    |---------- V2-002 Rahil mission engine ---------+
    |---------- V2-003 Rahil terrain/cameras ---------+--> V2-005 Rahil sensors
    |---------- V2-004 Shabaz sensor contract --------+           |
                                                       +--> V2-006 Rahil mapping
                                                       +--> V2-007 Rahil dashboard
                                                              |
                                              V2-008 Rahil validation/export
                                                              |
                                              V2-009 Shabaz audit
                                                              |
                                              V2-010 Shabaz guide handover
~~~

**Freeze policy:** any requested change to the mandatory demo, baseline coordinate/time semantics, or truth firewall requires recorded change proposal and task/acceptance update; not silent interpretation by implementation agents.

**Release policy:** passing all V2 task statuses does not substitute for visually inspecting the actual Mac MATLAB demo, all sensor views and mission map. Only completed evidence and reviewer acceptance can mark final simulation ready; hardware readiness remains separate.
