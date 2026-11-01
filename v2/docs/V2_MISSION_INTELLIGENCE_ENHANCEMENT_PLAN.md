# MineGuard Advanced V2 — Mission Intelligence enhancements (research and staged implementation plan)

**Document status:** PROPOSED DESIGN / RESEARCH REVIEW, not a completed BUILD task and not a change to V2-001 or V2-004 frozen requirements.  
**Project:** MineGuard-MATLAB; **date:** 2026-11-02; **decision authority:** Shabaz.  
**Implementation rule:** keep existing V2 task DAG and sealed research gates authoritative; issue/PR work on separate branches.  
**Scientific scope:** synthetic UAV mission and surface-feature **SUSPECTED** observations only, **not** certified landmine detection, mine clearance, or verified real-world safety.

## Executive guide recommendation

Build a distinctive **Mission Intelligence / Digital Twin** experience by linking flight pose -> synthetic sensor sample -> estimated anomaly -> checksum-verified evidence -> honest uncertainty/limitations. Upgrade presentation only where it strengthens this traceability. Prioritize in this order:

1. **P1 — Evidence Explorer and layered coverage:** finish V2-006/007 bridge (#68), then event selection with exact timestamp, modality, provenance, RGB/thermal crops, uncalibrated score, and map estimate. A field with no valid sensor frame stays unobserved/invalid, never 'cleared'.
2. **P1 — Optional satellite mission-planning preview:** independent base-MATLAB geographic axes prototype with an **explicitly supplied WGS84 demo anchor**. A satellite backdrop provides real geographic *context* for a synthetic route; it does not turn synthetic detections into observed facts. Existing local ENU map remains the offline, authoritative primary map.
3. **P1 — Focus-mode operations UI:** mission clock, simulation-only warning and critical controls always visible; enlarge map/3-D/RGB/thermal/LiDAR panel on demand, accessible keyboard and dynamic status text; design first, implementation after branch integration.
4. **P2 — Geometrically consistent 3-D realism:** better deterministic quadcopter mesh (camera mount, landing gear, distinct rotor orientation), seeded terrain materials/pathway detail, optional 3-D RGB/thermal footprint and LiDAR rays. Any physical-looking obstacle must exist in the *same scene/sensor geometry*, not just decorative graphics.
5. **P2 — Replay, fault lab and science debrief:** governed V2-008, after V2-006 & V2-007 DONE. Replay only recorded real sim output with stable IDs and run hashes; compare fixed-seed dropout/clutter experiments and show false alarms/negative controls clearly.

**Explicitly reject for this iteration:** Unreal co-simulation on the primary Mac (unsupported), exporting private target truth to the operator, satellite/map tiles embedded as sensor imagery, cloud/internet dependency for the guide's main mission, fake battery telemetry, fake AI probability badges, or premature re-running of frozen VAL/TEST.

## Verified research and available MATLAB capabilities (primary documentation)

| Capability | Verification | Engineering consequence |
|---|---|---|
| Base MATLAB geographic map | [MathWorks geoaxes](https://www.mathworks.com/help/matlab/ref/geoaxes.html) supports geographic axes in figures, UI panels and grid layouts; [geoplot](https://www.mathworks.com/help/matlab/ref/geoplot.html) plots WGS84 lines | Can make an *isolated satellite preview* with MATLAB itself; no new integration with V2-006 detector or Mapping Toolbox needed for native geographic plots |
| Built-in 'satellite' backdrop | [MathWorks geobasemap](https://www.mathworks.com/help/matlab/ref/geobasemap.html) offers Esri-hosted satellite imagery | Live high-zoom tiles are internet-dependent; attribution must stay legible; imagery content, zoom and availability are external |
| Offline basemap caveat | [MathWorks basemap access](https://www.mathworks.com/help/matlab/creating_plots/access-basemaps-in-matlab.html): only 'darkwater' is locally installed by default; [offline guidance](https://www.mathworks.com/help/map/use-basemaps-in-offline-environments.html) covers cache limits/custom saved imagery | Do not promise satellite imagery offline. Keep **existing synthetic ENU map** as the reliable disconnected mission display; 'darkwater' is a base-MATLAB geographic fallback, not satellite |
| Local ENU vs geodetic | [MathWorks enu2geodetic](https://www.mathworks.com/help/map/ref/enu2geodetic.html) uses an ellipsoid and explicit geographic anchor; belongs to Mapping Toolbox | For the small virtual test field, prototype uses self-contained WGS84 ECEF math + numerical tests, without making this toolbox mandatory; cross-check against Mapping Toolbox only if licensed |
| 3-D terrain graphics | [MathWorks surf](https://www.mathworks.com/help/matlab/ref/surf.html) supports texture-mapped surfaces | Visual terrain improvements feasible in current MATLAB renderer, but can cost frame time and create inconsistent sensor geometry if mishandled |
| High-fidelity Unreal environment | [MathWorks UAV Unreal limitations](https://www.mathworks.com/help/uav/ug/unreal-engine-simulation-environment-requirements-and-limitations.html): macOS co-simulation unsupported | Avoid Unreal in Mac-first V2; retain deterministic mesh-based MATLAB scene |
| Graphics themes | [MathWorks theme](https://www.mathworks.com/help/matlab/ref/theme.html) and [graphics theme guidance](https://www.mathworks.com/help/matlab/creating_plots/graphics-and-app-themes.html) | Explicit readable visual contrast is part of cross-platform acceptance; no hardcoded white canvas with auto-light text |
| Plot/frame behavior | [MathWorks drawnow](https://www.mathworks.com/help/matlab/ref/drawnow.html) can skip graphical updates while running callbacks | Measure sensor/engine steps separately from rendered scene updates; never claim 20-Hz engine equals monitor FPS |

## Baseline in this repository (source-inspected)

- `+mgv2/+scene/buildWorld.m` generates seeded terrain, observable materials, bushes/rocks, object geometry and landmarks. `+mgv2/+scene/SceneRenderer.m` already supports isometric/follow/chase/topdown/orbit and draws terrain, UAV, route, lighting and trail. **Enhance it; do not replace the authoritative World or add unrelated stock scenery.**
- `+mgv2/+ui/MissionControlApp.m` Stage 2 in draft PR #67 supports visible synchronized panels. On primary Mac, 107/107 software regressions were reported PASS; at paced 1x it achieved **9.02–9.66 scene refreshes/s** and dropped scene-only frames (not simulation ticks). Displayed screen FPS **not measured**; this is below the reliable >=10 aim *before* integration with V2-006.
- `+mgv2/+ui/MapPanel.m` owns offline ENU map and overlays; no geographic anchor is configured for a physical field. The default `MissionConfig.virtual_wgs84_origin = [0 0 0]` is a **virtual placeholder**, not authorization to display a real-world scene at that location.
- PR #66's negative V2-006 VALIDATION is **zero of four targets detected** (G07), with high false-positive counts. The synthetic **demo fixture** 1 TP / 77 FP is *not* an accuracy claim. Never cosmetically hide this.

## P1 satellite prototype architecture and restrictions

**UI workflow:** 'Synthetic Local Map' (default, always operable offline) -> optional 'Satellite Preview (online geographic context)' with visible WGS84 demo-anchor input and label -> always return to synthetic local map without changing run state. Geo preview is *not* live flight control, evidence raster, detector inference, or route editing.

1. Take an **explicit**, syntactically valid origin `[lat_deg lon_deg ellipsoid_height_m]`, with a clearly chosen place and a clear 'SIMULATION' banner. Do not silently use the default `[0 0 0]`, approximate the user's current location, fetch device GPS, or imply the drone actually flew above that satellite scene.
2. Convert only virtual local ENU mission waypoints/survey polygon/home to WGS84 using a deterministic ellipsoid rotation (or `enu2geodetic` if licensed). Validate coordinate handedness: east increases longitude, north increases latitude; zero ENU is the anchor. For this proposal restrict to small survey extents and latitudes below geographic-axes pole limitations.
3. Plot route/boundary/home with `geoaxes`/`geoplot`, preserve attribution. Use network-hosted 'satellite' basemap only when available. On tile failure or disconnected operation, switch back to **existing local synthetic map**, never show stale satellite imagery as an observation.
4. No private scenario truth, surface target coordinates, or real-world anomaly labels flow into satellite preview. In particular, do not georeference synthetic suspect events to somebody's property in the optional preview without separately approved safe UX and explicit synthetic labeling.
5. Keep a **standalone preview entrypoint** and independent pure coordinate conversion tests on a separate branch initially. Integrate into the dashboard only after the current bridge's contracts and performance budget are accepted; no changes to PR #66/#67 or task statuses.
6. Do not add automatic imagery downloading, tile scraping, unlicensed offline satellite assets, hidden third-party API keys, or network-dependent CI tests. Never suppress map-provider attribution.

**Required feasibility gates (currently NOT RUN):** local-to-geo origin and E/N signs; analytic WGS84 small-baseline check; invalid/placeholder origin rejected before any map is opened; deterministic coordinates; path/polygon correspondence; desktop MATLAB MapLayout and 1x rendering; dark/light text and provider attribution; online map visible; offline failure/fallback behavior; Windows smoke test. If tile retrieval fails but route plots correctly, mark **basemap network NOT VERIFIED**, not PASS.

## P1 interface innovation — implementation acceptance (not started)

- Add a clear **mission stage ribbon** (PREPARE / TAKEOFF / SURVEY / RETURN / LAND / COMPLETE) strictly bound to engine state, never separate animation.
- High-priority telemetric cards with *simulated* AGL/speed/clock, sensor freshness, valid-vs-invalid evidence coverage; no invented battery level. Keep existing 'NOT MODELLED' display until a real software battery model exists.
- Map + 3-D twin are primary panels, three sensors on a second strip, inspector as a focus-capable evidence panel. Choose UI modes via **Focus Mode** for projector-sized and compact laptop layouts; ensure accessible contrast under macOS dark/light desktop theme.
- Visual design: dark navy / slate, restrained teal for navigation, amber for SUSPECTED, red for fault, neutral grey for not-observed; do not use red marker to imply detected explosives. Avoid constantly changing labels: Mac profiling estimated ~8 ms per changed `uilabel`, and camera move ~19 ms; rerun profile after any new widgets.
- Each event click must show only public detector `event_id`, score_kind='uncalibrated heuristic', sensor modalities, estimated position and uncertainty, corresponding retained crop/checksum and explicitly missing evidence; no synthetic truth overlays.
- Propose optional **replay timeline** only as a V2-008 deliverable with recorded sample IDs and timestamps (never fresh regenerations represented as historical).

## P2 3-D fidelity gates (after the integration branch is stable)

| Enhancement | Geometric requirement | Cost guard / fallback |
|---|---|---|
| Clearer quadrotor model & camera gimbal | Same body transform and sensor mounting extrinsics as V2-005 | LOD geometry, static parts merged in one transform, no per-tick mesh rebuild |
| Land material variation and paths | Material colors/texture sampling derived from the same public scene source used by RGB/thermal | Texture not updated each tick; reference landmark checks unchanged |
| Sensor footprint/frustum | Corners computed from actual V2-005 public `footprint_enu_m`, synchronized with `pose_id` | At most one overlay update per new sample; invisible on invalid frames |
| LiDAR beam/point overlay | Actual public LiDAR returns, bounded point count, NaN/invalid rays not shown as ground hits | Toggle OFF by default in regular flight, deterministic subsampling |
| Sun/shadow/light optimization | Display-only lighting clearly labelled; does not change the synthetic radiometric model | Static light; compare actual Mac p95 frame time before/after |

**Go/no-go performance:** three seeded full missions per variant on Mac at paced 1x *after detector integration*; report actual update definitions, engine/sensors/detector/view/drawnow breakdown, clock lag, p50/p95 and worst gaps, scene drops, UI responsiveness, screenshots, and exact code SHA. Preserve nominal 20-Hz physics ticks; return to lower-detail quality setting if graphics degrade the integrated operating console.

## Dependencies, ownership, and acceptance

| Workstream | Can happen now? | Owner / branching |
|---|---|---|
| This enhancement research/design document | YES: documentation independently of active builds | ChatGPT; separate docs PR, merge only on Shabaz approval |
| Standalone satellite map preview & coordinate tests | YES: optional isolated prototype, no task status changes | ChatGPT code contribution; Mac Claude performs actual MATLAB run and capture |
| PR #66 display fix and independent Mac retest | Already locally coded/tested as reported; needs publication/integration | Shabaz/Mac Claude; do not rewrite Rahil's work while issue #68 runs |
| Rahil adapter (#68) + UI Stage 2 (#67) | Active, must not be overwritten by enhancement branches | Rahil/Claude and Shabaz/Mac Claude |
| Focus Mode, 3-D fidelity changes | Design now; implementation AFTER coordinated integrated baseline | Separate enhancement PR with regression and three-run perf evidence |
| V2-008 replay/export, V2-009 audit, V2-010 guide handover | NO: official DAG dependencies are not DONE | Existing V2 owners and frozen stage gates |

Final success: the guide can start a real simulated mission, trace one suspected event across map/pose/actual RGB/thermal evidence, see uncertainty and known negative controls, and inspect an honest report. An attractive satellite backdrop or 3-D mesh alone **does not satisfy that bar**.
