# MineGuard Advanced V2 — System Requirements Baseline and Scope Freeze

**Document:** V2-001 / product and demonstration requirements, revision 1.0  
**Owner:** Shabaz (ChatGPT-assisted specification)  
**Date:** 2026-11-01 (IST)  
**Status:** Proposed engineering baseline for guide and owner review. It is NOT implemented code.  
**Authoritative V2 task governance:** ../tasks/manifest.json and ../tasks/status.json  
**Original academic title, problem and four unchanged objectives:** ../../docs/PHASE1_BASELINE.md

## 1. Decision and intended outcome

The product is **MineGuard Advanced V2 — a high-fidelity, interactive, time-synchronized MATLAB UAV research simulation** on the user's macOS MATLAB R2026b Update 1 with UAV Toolbox 26.2. The demonstration must visibly carry out an autonomous mission from preflight and takeoff through survey, synthetic RGB / thermal / LiDAR acquisition, suspected-anomaly evidence mapping, return and landing. One integrated mission-control application presents a 3-D aircraft, a map, sensor feeds, telemetry, and an evidence log that all agree at the same simulation timestamp.

Do not substitute a polished animated movie, precomputed V1 playback or static unrelated thermal pictures for live simulation-state-driven outputs. A **real-time simulation** means simulated data update as the local mission clock advances; it does **not** mean data arrive from a real aircraft or operational landmine detector. No drone, QGroundControl, Raspberry Pi, network or physical payload is required for Stage 1. The existing QGC-capable physical aircraft belongs to a separate, future, safety-reviewed hardware integration stage.

The guide-portal website is **only a read-only progress tracker**. Do not confuse it with the MATLAB operator console. V1 remains its own evidence-based archive, 22/22 tasks DONE, without reclassifying any existing finding as a V2 success.

**Non-negotiable scientific warning:** synthetic suspected anomalies are NOT verified mines; a virtually scanned cell is NOT physically safe. The original Phase-1 buried-mine objective remains aspirational/unachieved without validated sensors and appropriate field evidence. V1 locked synthetic TEST is consumed; primary weighted-fusion TP 0, FP 26, TN 470, FN 4. Its synthetic detector and PPO negative findings must remain in the engineering report and never be overridden by an attractive fixture screenshot.

## 2. Previously observed facts versus assumptions

| Fact / assumption | Evidence / status | Engineering consequence |
|---|---|---|
| User's desktop MATLAB R2026b Update 1 / macOS 27.0.1 | Command Window output provided in conversation | Primary development and performance host is Mac; version explicitly captured |
| UAV Toolbox R2026b available | User ran ver('uav'), which('uavScenario'), which('uavPlatform'), which('multirotorFlightTrajectory') and saw valid paths | Use UAV Toolbox native cuboid/mesh scenario API |
| Local prototype created a visible blue quadcopter and completed waypoint-based 3-D animation | User screenshots and "MineGuard V2 virtual flight completed." | **Feasibility only**. NOT yet controlled flight dynamics, target frame rate, or versioned reproducible code |
| Mapping, Image Processing, Computer Vision, Navigation, Simulink, Lidar Toolbox installed | **NOT VERIFIED** on this Mac | All advanced dependencies must be probed, never assumed |
| Unreal Engine 3-D UAV environment available on macOS | **No**, official integration requires supported Windows/Linux with Simulink 3D Animation | Do not promise native Unreal photorealism on Mac |
| Real aircraft with QGC grid/waypoint planning | User-reported existing capability | Not a dependency for current simulation |
| Raspberry Pi, thermal camera and LiDAR payload physically integrated | **Not available / not verified** | No live telemetry or physically captured sensor claims |

## 3. Scope boundary

### Stage 1: required simulated research deliverables

1. Single application with mission planning, explicit **START SIMULATION**, pause, resume, stop, seek/replay after mission, saved output, and predictable scenario reset.
2. One configurable synthetic terrain and survey boundary; authentic-looking but accurately labeled rendered quadcopter, 3-D ground, camera poses and no invisible or impossible flight trajectories.
3. Virtual takeoff → climb → transit → autonomous grid survey → return → descend → land. The mission state, time, position, speed, altitude above ground, heading and battery *model* are visible; battery values always labeled simulated.
4. Interactive **map as a first-class screen**: survey boundary, planned/actual route, virtual home, UAV position/heading, sensor footprints, already *observed* cells, unobserved/invalid areas, suspected-event markers. Map and 3-D view refer to the same local coordinate frame and timestamp.
5. Live **downward RGB camera** frame series, generated from the same terrain and pose used by the 3-D scene, with geometric footprint and timestamps; not generic unrelated stock images.
6. Live **thermal frame**: numerical synthetic temperature field in K, plotted as a temperature image with scale, palette and °C display option; not recolored RGB presented as a thermogram. Show noise, sensor validity and effects of stated environmental assumptions. No realistic buried-mine sensitivity claim.
7. Live **LiDAR**: terrain-relative range/point-cloud/elevation output with pose/geometry provenance. LiDAR supports surface topology and height assessment; not reliable direct buried-mine detection.
8. GPS-like/INS-like virtual telemetry with explicit reference-frame transformations and virtual origin. Optional weather, wind and telemetry degradation are synthetic.
9. Observable-only suspected-anomaly rules; each event includes estimated position, time, evidence reference(s), modality validity and uncalibrated score/uncertainty. Clicking an event shows co-timed RGB/thermal and map evidence. The separate evaluator can access hidden synthetic truth; the detector and operator console cannot.
10. Complete offline mission package: manifest/seed/version, poses, mission phases, frames/measurement references, suspected events, coverage/invalid-area summary, run log, report screenshot and safe export. No secret truth or target-material data in operator export.

### Explicit exclusions

- No motors, real QGC commands, drone communications, actual autonomous physical takeoff, armed-field operations, explosive devices or mine-clearance workflow.
- No claim to geolocate real buried mines or reduce human risk in an operational trial.
- No fake radar or ground-penetrating sensing presented as a working instrument. V1 synthetic EM remains optional *research proxy*, not a real metal-detector reading.
- No need to install or purchase Windows Unreal software to pass the Mac-based academic demonstration.
- No reuse of the consumed V1 TEST as a new V2 optimization or acceptance dataset. V2-004 must specify new experiments before improved-model results are claimed.
- No online map dependency for the live demonstration; satellite basemap is enhancement only and must respect imagery licenses/privacy.

## 4. Required visual product — guide-facing acceptance storyboard

Primary app should maximize available display space with legible captions and selectable fullscreen sensor panels. A tactical, restrained dark theme is acceptable, but no decorative "military" information that implies real sensors. Labels **SIMULATION / SYNTHETIC / SUSPECTED** remain visible in all key screens and screenshots.

~~~
+---------------------------------------------------------------+
| MINEGUARD / SIMULATED RESEARCH MISSION  Clock | State | Warning|
+-----------------------------+---------------------------------+
| LIVE 3-D UAV SCENE          | GEOGRAPHIC / LOCAL MISSION MAP  |
| aircraft, attitude, terrain | home, plan, actual route,       |
| configurable viewpoint      | coverage, footprints, suspects |
+-----------------------------+------------------+--------------+
| RGB CAMERA [SIMULATED]      | THERMAL [K / C]  | LiDAR / AGL  |
| nadir imagery + timestamp   | palette + legend | pointcloud  |
+-----------------------------+------------------+--------------+
| POSITION / SPEED / HEADING / ALTITUDE / BATTERY MODEL           |
| EVENT  timestamp / location / modality / validity / score       |
| START SIM | PAUSE | RESET | REPLAY | EXPORT | EVIDENCE INSPECT  |
+----------------------------------------------------------------+
~~~

### Explicit user journeys and acceptance IDs

| ID | Guide-visible interaction and expected outcome | Owner / implementation task |
|---|---|---|
| UI-01 | Start a scenario in a single MATLAB application; status changes from PREFLIGHT to TAKEOFF with clock advancing from zero | Rahil / V2-002 + V2-007 |
| UI-02 | Virtual drone visibly ascends, flies an automatic survey, turns with credible continuity, returns and lands; no unexplained teleportation | Rahil / V2-002 + V2-003 |
| UI-03 | Zoom/orbit/follow the moving UAV and switch camera viewpoints, with scene and mission time consistent | Rahil / V2-003 + V2-007 |
| UI-04 | Map always shows current virtual UAV/heading, home, route, boundary, sensor footprint and time-correct surveyed area | Rahil / V2-006 + V2-007 |
| UI-05 | Enable/disable coverage, synthetic temperature, LiDAR terrain, suspected events and basemap layers; unobserved ground is not colored as cleared | Rahil / V2-006 + V2-007 |
| UI-06 | RGB view changes consistently with drone motion over identifiable terrain features; stopped simulation freezes frame timestamps | Rahil / V2-005 + V2-007 |
| UI-07 | Thermal panel shows genuine numeric synthetic temperature raster with consistent palette legend and timestamp; environmental variation changes measurements | Rahil / V2-005 |
| UI-08 | LiDAR displays point cloud or ground-range/elevation plot; invalid returns have visible reasons, not invented zeros | Rahil / V2-005 |
| UI-09 | Selecting a suspected anomaly shows timestamp, modality evidence, synchronized RGB/thermal crop, map position, uncertainty/quality and detector version | Rahil / V2-006 + V2-007 |
| UI-10 | Sensor dropout/wind/noise/obstacle or bad-quality scenario visibly affects indicators and coverage; flight failures are not silently hidden | Rahil / V2-008 |
| UI-11 | Pause/resume/reset/record/replay never move hidden truth into inference or silently regenerate different seed data | Rahil / V2-008 |
| UI-12 | Postflight report and export show actual simulation run ID, parameters, event counts, missed coverage, scientific limitations and real wall-clock performance | Rahil + Shabaz / V2-008 to V2-010 |
| UI-13 | The interface clearly labels the operation simulated and all hazards suspected; **no SAFE/CLEARED/CONFIRMED MINE** labels | All; Shabaz signs off |
| UI-14 | Intro and conclusion distinguish the original four intended objectives from demonstrated virtual functions and real-world unachieved detection | Shabaz / V2-009 + V2-010 |

## 5. Map requirements (first-class, not a mini-plot)

**MAP-01 / coordinate truth.** Internal operational geometry remains local ENU (east, north, up; metres), matching MG003 v1.0 interface convention. UAV Toolbox uses an adapter to/from NED. Any geographic coordinate is **virtual WGS84 reference** with explicit origin and conversion; do not imply measured GNSS. z-up height above datum is not equivalent to LiDAR height above local terrain.

**MAP-02 / basemaps.** Default is self-contained 2-D local survey map and synthetic textured/orthophoto-like field; it works without internet. Optional satellite-style geographic basemap may use MATLAB geoaxes online imagery or a properly licensed local image with geographic registration. If a satellite tile is unavailable, visibly fall back to the offline map, never render a blank mission screen. Live drone position, footprints, events and coverage must survive the switch.

**MAP-03 / coverage.** Count only scanned cells actually intersected by valid sensor footprint during simulated mission time. Distinguish PLANNED, OBSERVED, NOT OBSERVED and SENSOR INVALID. No green "safe land" layer. Keep separate navigation coverage and usable sensor coverage percentages.

**MAP-04 / suspect placement.** Marker positions come from observation-derived estimates, not hidden simulator truth. Uncertainty shown as error radius/area if produced, with model-estimate label; no verified mine sign. Selection synchronizes with sensor evidence panel.

**MAP-05 / export.** Preserve local ENU, virtual geodetic origin, coordinate-unit metadata, map layers and temporal provenance for each observation in the run package. GeoJSON/KML are optional implementations subject to feasible library availability; CSV/JSON/MAT are required.

## 6. Realism must be measurable, not decorative

- Flight: separate command trajectory, actual integrated virtual pose, rate-limited thrust/turn or simplified dynamic-control approximation, and visibly differing desired versus achieved path under specified wind. Waypoint interpolation alone cannot pass the final realistic-flight milestone.
- Scene: synthetic terrain elevation, surface classes/texture, rocks/vegetation/clutter, lighting modes, UAV mesh scaling/attitude, clear camera view and persistent orientation cues. Static scenery must not move independently of aircraft without a defined transform.
- Optical: frames follow common camera intrinsics/extrinsics; feature location projects consistently onto the mapped ground; unknown/occluded regions may remain invalid.
- Thermal: actual numeric temperature raster and scene-dependent temperature/material/ambient/noise assumptions; palette is a *display* transform. Sensor model assumptions and limits are presented honestly.
- LiDAR: ray/point-cloud or defensible range model tied to scene geometry; noise/dropouts and limited visibility are represented, not invented height readings.
- Statistical integrity: all displayed random effects derive from recorded deterministic seeds; no ground truth reaches operational inference and no synthetic showcase scores are called held-out detection accuracy.

## 7. Stage gates and completion definition

A **V2 task being marked DONE is insufficient** if the acceptance storyboard fails on the target machine. The technical architecture and detailed test matrix are in V2_TECHNICAL_ARCHITECTURE.md and V2_DEMO_ACCEPTANCE_MATRIX.md.

Final V2-010 cannot be accepted until:
- full live mission (not only playback) runs from START to COMPLETE on Mac;
- simultaneous 3-D, map, RGB, thermal and LiDAR views are real synchronized simulation outputs, or a missing optional capability is visibly marked unavailable with documented reason and agreed acceptance revision;
- map-to-3-D and camera-to-map alignment tests pass on synthetic reference landmarks;
- guide can review events and exports with no hidden truth leakage;
- recorded acceptance report contains actual timings, device/toolbox version, test logs, screenshots and negative controls;
- Shabaz reviews the actual interface and signs off on scientific accuracy and expected visual quality.

## 8. Traceability to Phase-1 originals

| Official objective (exact text remains in PHASE1_BASELINE) | V2 testable academic contribution | Not claimed |
|---|---|---|
| O1 autonomous pre-programmed UAV survey | Virtual mission from takeoff to landing, path, local control and coverage in a simulated 3-D environment | Real autopilot / flight field test |
| O2 subsurface landmine detection with metal detector coil + thermal fusion | Synthetic thermal and optional EM proxy / anomaly-model experiments; rigorous validity, negative-control and independent evaluation | Successful buried-landmine detection or actual metal-detector hardware |
| O3 geo-tag threat map and real-time GCS | Virtual geotags, map coverage, co-timed simulated sensor feeds and mission control | Actual GPS, real detector, remote field GCS |
| O4 eliminate human exposure | Concept of stand-off aerial surveying explained virtually | Proved safety improvement or land release |

## 9. References and constraints

- MathWorks, UAV Toolbox R2026b: https://www.mathworks.com/help/uav/
- MathWorks, uavScenario / show3D: https://www.mathworks.com/help/uav/ref/uavscenario.show3d.html
- MathWorks, multirotorFlightTrajectory (NED waypoints, polynomial smoothing): https://www.mathworks.com/help/uav/ref/multirotorflighttrajectory.html
- MathWorks, UAV LiDAR point cloud generator: https://www.mathworks.com/help/uav/ref/uavlidarpointcloudgenerator-system-object.html
- MathWorks, MATLAB geoaxes / satellite basemap and network limits: https://www.mathworks.com/help/matlab/ref/geoaxes.html
- MathWorks, Unreal engine system requirements (not macOS): https://www.mathworks.com/help/uav/ug/unreal-engine-simulation-environment-requirements-and-limitations.html
- Baur et al., 2026, seeded minefield comparative study (surface RGB / thermal strengths; subsurface limitations), Remote Sensing 18(13) 2182: https://doi.org/10.3390/rs18132182
- Forero-Ramírez et al., 2023, thermographic drone-image dataset: https://doi.org/10.1016/j.dib.2023.109443
- MineInsight multi-sensor dataset, IEEE RA-L, 2026; *ground robot*, not UAV benchmark: https://doi.org/10.1109/LRA.2025.3643265
- International Mine Action Standards (clearance versus suspected-hazard concepts): https://www.mineactionstandards.org/standards/07-11/

**Interpretation of literature:** a 2026 comparative test observed high surface-target visibility for RGB (94.8%) and thermal (83.7%) within its specific seeded-field study. These are not detection performance numbers for MineGuard or operational buried mines. LiDAR primarily supports geometry/terrain. A camera image or temperature pattern cannot by itself establish buried explosives.
