# V2-002 / V2-003 engineering decision record — live mission engine and 3-D scene

**Owner:** Rahil (implementation, Claude Code) · **Date:** 2026-11-01 (IST) · **Reviewer:** Shabaz
**Binding inputs:** `V2_SYSTEM_REQUIREMENTS.md`, `V2_TECHNICAL_ARCHITECTURE.md` (ADR-01..ADR-10), `V2_DEMO_ACCEPTANCE_MATRIX.md`.
**Status:** decisions taken *before* implementation and checked against measurements on the development host. The required macOS target host has **NOT** been tested (see §6).

## 1. Verified environment (development host)

- Windows 11 Pro (build 26300), MATLAB **R2026b Update 1** (26.2).
- Installed products: MATLAB, Simulink, Aerospace, Deep Learning, Mapping, Navigation, Reinforcement Learning, Stateflow, **UAV Toolbox 26.2**, MATLAB MCP Server Toolbox 0.5.0.
- **Not installed:** Image Processing, Computer Vision, Lidar and Statistics toolboxes. The design must not depend on them. A `range()` call from the Statistics Toolbox was caught and removed during testing.
- **Target host (user's MacBook, MATLAB R2026b Update 1 + UAV Toolbox 26.2): NOT TESTED by this work.** Commands to run there are in the V2-002/V2-003 evidence.

## 2. Official API facts verified (R2026b documentation, fetched 2026-11-01, plus local `help`)

| API | Verified fact | Consequence |
|---|---|---|
| `multirotorFlightTrajectory` | "piecewise 9th degree polynomial to interpolate linear positions and the cubicpolytraj function to interpolate yaw"; waypoints in **NED** | It is an interpolated reference, **not** a dynamics simulation. Rejected as the motion model (requirement §6: interpolation cannot pass realistic flight). |
| `uavPlatform.move` | motion is a 16-element vector `[x y z vx vy vz ax ay az qw qx qy qz wx wy wz]`; platforms default to `ReferenceFrame "NED"` | Adapter `mgv2.frames.poseEnuToNed` produces exactly this form for any toolbox use. |
| `uavScenario.advance` | advances by one step of `1/UpdateRate`; it only moves platforms that have an assigned trajectory | The scenario's clock is not suitable as the authoritative clock for a closed-loop engine; ADR-03 clock stays in our engine. |
| `uavScenario.show3D` | `show3D(scene, Parent=ax, FastUpdate=true)` does "a lightweight update to the previous map" | Measured below; too slow for the 10–20 FPS target. |
| `uavScenario.addMesh` | types `"cylinder" "surface" "terrain" "polygon" "buildings" "unreal scene" "custom"`; ENU geometry by default | The world model can be exported as `"custom"` meshes for UAV Toolbox sensors (V2-005). |
| `uavScenario.terrainHeight` | **errors** with "UAV scenario does not contain any terrain data" for a `"surface"` mesh (local test) | The world model must own its height query; we cannot rely on the toolbox for AGL. |
| `uavLidarPointCloudGenerator` | senses static scenario meshes; detections are in the sensor frame | Local test: returned 68,840 finite points from a surface mesh → V2-005 LiDAR on the same geometry is feasible. |
| Unreal Engine co-simulation | supported only on Windows 64-bit and Linux; "Mac platforms do not support co-simulation between Simulink and the Unreal Engine"; requires Simulink 3D Animation | Rejected (ADR-01 confirmed). |

## 3. Measured feasibility spike (same 121×121 height field, 200 frames, visible figure, development host)

| Option | Median per frame | p95 | Notes |
|---|---:|---:|---|
| (a) `uavScenario` + `uavPlatform.move` + `show3D(FastUpdate=true)` | **67.4 ms** | 89.9 ms | ≈15 FPS ceiling before any other work |
| (b) base-MATLAB `surf` terrain + aircraft under one `hgtransform` (update `Matrix` only) | **3.9 ms** | 7.3 ms | ≈17× faster |
| (c) `uavLidarPointCloudGenerator` on an `addMesh("surface")` terrain | works | — | 68,840 finite points, one scan |

The spike is a scratch script (not committed); its numbers come from that single run and must be re-measured on the Mac (V2-008 / AC-025).

## 4. Decisions

### D1 — Authoritative clock and engine (V2-002)
- **Chosen:** a pure-MATLAB `mgv2.engine.MissionEngine` handle object with a fixed-step integer tick:
  - `t_s = tick_id·dt`, nominal `dt = 0.05 s`;
  - the engine has no timer and never reads the wall clock;
  - the caller steps it (headless test, demo loop, or later the V2-007 app timer).
- **Engine-level controls:** `start`, `step`, `pause`, `resume`, `abort`, `reset`; `snapshot()` returns an immutable PoseSample; `subscribe(fcn)` gives V2-003/V2-005 the same per-tick snapshot.
- **Rejected:**
  - `uavScenario` as the clock: it only advances trajectory-driven platforms and would couple physics to a toolbox scene.
  - A MATLAB `timer` inside the engine: it ties determinism to the wall clock and makes headless tests flaky.

### D2 — Vehicle model (V2-002)
- **Chosen:** a translational point-mass model with a cascaded position/velocity controller producing a bounded commanded acceleration (horizontal limit, tilt limit, vertical limit). Additional elements:
  - a first-order lag (τ = 0.15 s) from commanded to achieved acceleration, standing in for attitude/thrust response;
  - linear drag on airspeed `−k_d (v − w)` with seeded wind;
  - attitude from **differential flatness**: body z along the specific thrust, and `x_b = y_c × z_b` so the logged yaw equals the rate-limited heading (Mellinger & Kumar 2011; Mahony, Kumar & Corke 2012).
- **Why:** it gives coherent position/velocity/acceleration, physically meaningful tilt in turns and under drag (cruise pitch is predicted analytically and tested), and visibly different commanded vs actual paths under wind. It also stays deterministic and fast, at 70–110× real time headless on the development host.
- **Rejected:**
  - Linear waypoint interpolation with a constant upright quaternion (explicitly non-compliant).
  - `multirotorFlightTrajectory` as motion: interpolation only, see §2.
  - A full 6-DOF rigid-body model with motor dynamics: unverifiable parameters for an unspecified airframe, and it adds stiffness without improving any acceptance test at this stage.
- The model is **not** a certified flight controller and must never be described as Pixhawk/PX4 behaviour.

### D3 — Guidance and coverage planning (V2-002)
- **Coverage:** boustrophedon (back-and-forth) decomposition of a **convex** survey polygon. Lines are centred and inset half a spacing, run at any compass heading, and alternate direction (Galceran & Carreras 2013; Cabreira, Brisolara & Ferreira 2019). Non-convex fields are rejected rather than silently mishandled.
- **Path following:** an L1-style look-ahead "carrot" on one continuous TRANSIT → SURVEY → RETURN_HOME polyline (Park, Deyst & How 2004), with monotone progress along the path. The speed profile slows for corners (bounded lateral acceleration on a look-ahead-radius turn) and brakes into the final point.
- **Altitude:** terrain-following at the AGL setpoint, using the highest ground among the current point, the carrot point and the position 2 s ahead.
- **Phases:** vertical TAKEOFF / CLIMB / LANDING over the home pad. COMPLETE happens only on touchdown (AGL ≤ 0.05 m, low sink rate, within the arrival tolerance of home).
- **Faults are terminal and explicit:**
  - `PREFLIGHT_TERRAIN`
  - `PREFLIGHT_UNREACHABLE` (only for a provable lower bound on mission time, or a geofence ceiling below the required height)
  - `CLEARANCE` (AGL below the minimum in cruise phases)
  - `TERRAIN_COLLISION`
  - `GEOFENCE` (outside the bounds, or outside the survey area plus documented home corridors)
  - `TIMEOUT`
  - `ABORTED_BY_OPERATOR`
- Automatic failsafes such as return-to-launch on a fault are **not** modelled; the state freezes and is reported.

### D4 — Frames (both tasks)
- ENU metres internally (MG003-compatible, ADR-04).
- Body frame FLU.
- Quaternion `[w x y z]` mapping body to world.
- NED/FRD only in `mgv2.frames.poseEnuToNed/poseNedToEnu`, the single conversion layer. `mgv2.frames.conventions()` is the single written definition.
- AGL is always `z_up − terrainHeight(x, y)`, never a NED z value.

### D5 — Scene and renderer (V2-003)
- **Chosen:** one triangulated world model is the only geometry source. It provides:
  - a seeded procedural height field;
  - surface albedo;
  - rocks, vegetation, survey markers and the home pad, all stored as world objects;
  - `heightAt` by barycentric interpolation on the same triangles that are drawn.
- **Rendering:** base MATLAB graphics, with one `patch` for the terrain and the aircraft under a single `hgtransform` (only `Matrix` changes per frame), plus lights, materials and five camera modes.
- **Export:** an adapter turns the same triangles into `uavScenario` `"custom"` meshes so UAV Toolbox sensors (LiDAR) see identical geometry.
- **Why:** measured at ≈17× faster than `show3D`, independent of the toolbox for display, and exact agreement between rendered ground and height queries.
- **Rejected:**
  - `show3D` as the primary renderer (measured too slow).
  - Unreal (unsupported on macOS).
  - Decorative objects not in the world model (forbidden by the requirements).

### D6 — Camera/sensor geometry for V2-005 (V2-003)
- Pinhole intrinsics and explicit body→sensor extrinsics for a nadir RGB camera, a nadir thermal camera and a LiDAR. Provided functions: world→pixel projection, pixel→terrain ray intersection, footprint polygons, and a scene-sampled nadir raster for feasibility.
- **Mounting poses, resolutions and fields of view are PROVISIONAL** until Shabaz's V2-004 sensor contract freezes them.
- Native MATLAB axes snapshots (`getframe`) were not chosen as the camera model: they are display-dependent, slow, and their projection is hard to verify. Ray-sampled rasters are deterministic and testable against known landmarks.

## 5. Test plan (implemented as executable MATLAB tests)

- **V2-002:** `v2/matlab/tests/testV2002MissionEngine.m`
  - phase order; take-off; AGL tracking on flat and sloped/wavy terrain; per-line coverage
  - continuity (tick, step size, velocity); velocity/acceleration/tilt bounds; heading-rate limit
  - cruise pitch vs drag model; return and landing; "time alone never completes"
  - bit-identical determinism; pause/resume identical to an uninterrupted run; reset
  - 13 invalid configurations and invalid terrain providers
  - terrain collision, clearance, ceiling, geofence, timeout and abort faults
  - ENU/NED and pose round trips with a cross-check against MathWorks `eul2quat`
  - wind disturbance and recovery; clock = tick·dt with no wall-clock reads
  - subscribers; 4 field sizes/headings; the PoseSample contract; static truth-firewall scan
- **V2-003:** `v2/matlab/tests/testV2003Scene.m`, listed in the V2-003 evidence.

## 6. Risks and unresolved limitations

1. **macOS performance and rendering are not measured.** The Apple-silicon graphics path, `exportapp`/`getframe` behaviour and FPS must be measured on the user's Mac (AC-024/AC-025, V2-008).
2. The flight model is a validated *approximation*. Its parameters (drag 0.25 1/s, τ 0.15 s, limits) are documented assumptions, not identified from a real airframe.
3. The terrain-following look-ahead is 2 s. A cliff steeper than the climb rate can still collide, and the engine then fails explicitly (tested).
4. Only convex survey polygons are supported.
5. There is no battery model yet. It is a V2-007 display requirement and will be added as a clearly labelled simulated estimate.
6. Sensor intrinsics/extrinsics are provisional until V2-004.

## 7. References (each verified on 2026-11-01; DOIs resolved via the Crossref API)

- MathWorks R2026b documentation:
  - https://www.mathworks.com/help/uav/ref/uavscenario.show3d.html
  - https://www.mathworks.com/help/uav/ref/uavplatform.move.html
  - https://www.mathworks.com/help/uav/ref/uavscenario.advance.html
  - https://www.mathworks.com/help/uav/ref/multirotorflighttrajectory.html
  - https://www.mathworks.com/help/uav/ref/uavscenario.addmesh.html
  - https://www.mathworks.com/help/uav/ref/uavlidarpointcloudgenerator-system-object.html
  - https://www.mathworks.com/help/uav/ug/unreal-engine-simulation-environment-requirements-and-limitations.html
- D. Mellinger, V. Kumar, "Minimum snap trajectory generation and control for quadrotors", *2011 IEEE ICRA*, pp. 2520–2525. https://doi.org/10.1109/ICRA.2011.5980409 — flatness map from acceleration and yaw to attitude (D2).
- R. Mahony, V. Kumar, P. Corke, "Multirotor Aerial Vehicles: Modeling, Estimation, and Control of Quadrotor", *IEEE Robotics & Automation Magazine* 19(3):20–32, 2012. https://doi.org/10.1109/MRA.2012.2206474 — thrust-vector attitude and drag modelling (D2).
- S. Park, J. Deyst, J. P. How, "A New Nonlinear Guidance Logic for Trajectory Tracking", *AIAA Guidance, Navigation, and Control Conference*, 2004. https://doi.org/10.2514/6.2004-4900 — look-ahead path following (D3).
- E. Galceran, M. Carreras, "A survey on coverage path planning for robotics", *Robotics and Autonomous Systems* 61(12):1258–1276, 2013. https://doi.org/10.1016/j.robot.2013.09.004 — boustrophedon decomposition (D3).
- T. M. Cabreira, L. B. Brisolara, P. R. Ferreira Jr., "Survey on Coverage Path Planning with Unmanned Aerial Vehicles", *Drones* 3(1):4, 2019. https://doi.org/10.3390/drones3010004 — back-and-forth patterns for convex UAV survey areas (D3).
