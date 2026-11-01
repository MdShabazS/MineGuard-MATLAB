# V2-004 — Sensor Acceptance/Traceability Matrix and Research Audit

**Owner:** Shabaz | **Date:** 2026-11-01 | **State:** planned acceptance criteria; no MATLAB V2 sensor implementation tested.  
**Normative dependencies:** V2_004_SENSOR_CONTRACTS.md + V2_004_EVALUATION_PROTOCOL.md + V2-001 architecture.  
**Future verification:** Rahil executes in MATLAB R2026b/UAV Toolbox; Shabaz independently reviews raw evidence before any V2-005/006/008 DONE state.

## A. Source validation and technical design choices

| Issue | Source and confirmed property | Decision and caveat |
|---|---|---|
| UAV sensor mounting | MathWorks uavSensor: https://www.mathworks.com/help/uav/ref/uavsensor.html | MountingLocation body metres, MountingAngles z-y-x **degrees**, sensor update interval must be multiple of scenario interval. Do not use ENU Euler radians as mounting angles |
| Virtual LiDAR native model | MathWorks uavLidarPointCloudGenerator: https://www.mathworks.com/help/uav/ref/uavlidarpointcloudgenerator-system-object.html | Mesh-derived noisy point clouds in sensor frame; supports MaxRange/RangeAccuracy angular limits/HasNoise/HasOrganizedOutput. Actual MATLAB invocation must be tested |
| Virtual nav | MathWorks insSensor: https://www.mathworks.com/help/uav/ref/inssensor-system-object.html | Noise/accuracy is model parameter, not calibrated physical GPS precision |
| Custom RGB/thermal sensors | MathWorks uav.SensorAdaptor R2026b: https://www.mathworks.com/help/uav/ref/uav.sensoradaptor-class.html | Custom adaptor possible; pure MATLAB synchronized scene sampler fallback if adaptor not practical |
| Camera K | MathWorks cameraIntrinsics: https://www.mathworks.com/help/vision/ref/cameraintrinsics.html | Useful reference; Computer Vision Toolbox presence on Mac unknown, so base MATLAB 3x3 K fallback needed |
| Thermal physics | FLIR measurement manual: https://support.flir.com/docdownload/assets/web/27eh/en-us/ | Emissivity, reflected apparent temperature, atmospheric transmission, ambient temp, distance matter; our simulated K should not be called field-calibrated |
| Radiometric proxy formula | Sensors 2023: https://www.mdpi.com/1424-8220/23/18/8011 | Broadband Stefan–Boltzmann model is an approximation, NOT a band-integrated calibrated 8–14 µm camera |
| Aerial seeded-field performance | Baur et al. Remote Sensing 2026: https://www.mdpi.com/2072-4292/18/13/2182 | RGB predominantly visible surface; thermal nonunique and condition-dependent; LiDAR terrain role; no buried identification claim |
| Real thermal dataset | Data in Brief 2023: https://doi.org/10.1016/j.dib.2023.109443 | 2700 drone thermal images; a reference for appearances/scenarios, not a simulated sensor calibration |
| Mine-action terminology | IMAS 07.11: https://www.mineactionstandards.org/standards/07-11/ | Simulated coverage cannot label land cleared/safe or confirmed contaminated |

**License and reuse:** importing open datasets is optional and requires checked usage terms and explicit DATASET_RECORDED provenance; do not put copyrighted/proprietary imagery into repository without rights. Do not feed downloaded thermal frames as if generated from the current scene.

## B. Requirements traceability (specific, testable)

| V2-004 ID | Requirement / acceptance method | Example pass test, not executed | Implementation ownership |
|---|---|---|---|
| SC-01 | All sample structs use exact shared envelope, schema version, pose_id, tick_id and unit fields | Missing/unknown/mismatched version rejected with explicit error | V2-005 |
| SC-02 | Fixed-step deterministic scheduler with independent channels | dt=0.05; RGB/thermal due ticks 0,4,8; LiDAR 0,10,20; nav 0,2,4 | V2-005 |
| SC-03 | Pose timestamp invariant | Every sample pose_id references correct immutable pose; abs(t_sample-t_pose) ≤1e-9s for representable t | V2-005 |
| SC-04 | Frozen pausing | Pause after tick 100; no sensor samples at later tick until resume | V2-005/008 |
| SC-05 | Sensor RNG independence | RGB samples bitwise/numerically identical with thermal enabled vs disabled for same RGB seed | V2-005 |
| SC-06 | Nadir camera optical transform | World -U ray intersects ground at correct point; rotated yaw/bank changes footprint as expected | V2-003/005 |
| SC-07 | RGB geometry | Landmark projected to expected pixel and map ENU within **0.5 m** in nominal synthetic fixture; no unrelated image | V2-005 |
| SC-08 | RGB validity mask | Missing ground intersection -> per-pixel false + no claimed observation | V2-005 |
| SC-09 | Thermal numeric invariant | Valid pixel Kelvin>0 and finite; invalid NaN; palette change cannot change K raster or its hash | V2-005 |
| SC-10 | Thermal environment response | Synthetic sunlight, emissivity, ambient and nuisance changes produce model-specified measurable effects, not universally positive anomaly | V2-005 |
| SC-11 | Thermal adverse case | N2 low contrast may produce no correct detection; model must not force a bright signature | V2-005/006 |
| SC-12 | LiDAR flat plane | Center down ray from 5 m AGL reports near 5 m corrected for mounting offset, within 3σ + ray-geometry numerical tolerance | V2-005 |
| SC-13 | LiDAR sloped terrain | Geometric range and 3-D ENU points agree with shared terrain; no underground points | V2-005 |
| SC-14 | LiDAR out-of-range | Short MaxRange / sky pointing -> invalid ray NaN and OUT_OF_RANGE/NO_INTERSECTION; no fake zero | V2-005 |
| SC-15 | Nav reporting | Raw virtual pose and noisy reported nav are distinct and correctly labeled with virtual reference origin | V2-005 |
| SC-16 | Sensor-frame/body/world equivalence | Round-trip rigid transform test with nonzero translation and asymmetric yaw/pitch/roll within 1e-8 m | V2-003/005 |
| SC-17 | Truth firewall structural | Inject TargetTruth/target_count/burial_depth_m nested or object handle -> public adapter rejects / strips before delivery with negative test | V2-005/006 |
| SC-18 | Truth firewall behavioral | Given same observable samples and different hidden target truth, detector outputs identical | V2-006 |
| SC-19 | Sensor dropouts | Sensor sample invalid and fresh UI shows missing/stale, not copied observations with new timestamp | V2-005/007 |
| SC-20 | Public map footprints | RGB/thermal footprints and LiDAR returns on same local ENU map; observed versus planned/invalid cells separate | V2-006/007 |
| SC-21 | Event audit | SUSPECTED event has observation evidence_refs, actual estimated map coordinate, modality validity, uncalibrated score | V2-006 |
| SC-22 | Label audit | All visible panels/exports say SIMULATION/SYNTHETIC, never SAFE/CLEARED/CONFIRMED MINE | V2-007/008 |
| SC-23 | Repeatability | Two runs of same source+seed+config yield identical normalized numeric observations under specified floating tolerance | V2-005/008 |
| SC-24 | Fresh split guard | No shared parent scene/session/seed between TRAIN/VAL/TEST; pass withheld labels only to independent evaluator | V2-006/008 |
| SC-25 | Honest held-out metrics | Raw TP/FP/TN/FN, unit, denominator, precision/recall/FPR, per-family variance + confidence intervals; missing denominators NA | V2-008/009 |
| SC-26 | V1 preservation | No change to V1 locked TEST/run lock, no revised sensitivity claim, no fabricated S0 metrics | V2-009 |
| SC-27 | End-to-end live feed | Scene-driven RGB and numeric K thermal and LiDAR samples all match single live run at a common tick without UI blocking simulation | V2-005/007 |
| SC-28 | Mac capability check | Actual MATLAB and toolbox listing, exact sample commands + output; unsupported optional toolboxes get safe base-MATLAB fallback | V2-005 |
| SC-29 | Simulated sensor performance | Actual measured sample generation/wall time, 1× mission availability, frame skip/drop counts; never infer speed from generated code alone | V2-005/008 |
| SC-30 | Provenance export | Every event/sensor array links to run ID, code version, source scene, seed and hashes; invalid paths rejected | V2-008 |

**Important ownership split:** SC-xx rows are not automatically added as 30 new GitHub tasks. They are subcriteria nested within the existing V2-005, V2-006, V2-007, V2-008 tasks.

## C. Explicit numeric reference fixtures

Fixtures below are **analytical expected values**, not outputs from an executed MATLAB test.

1. **Time scheduling:** dt_s=0.05, RGB/thermal 5 Hz → 4 ticks between samples, LiDAR 2 Hz →10 ticks, nav 10 Hz →2 ticks. At tick 20 all four nominal channels are due; if sim paused at tick 20, no new emission occurs until clock resumes.
2. **Flat terrain:** world U=0, sensor mounted with optical axis world [0,0,-1], camera origin [10,20,5] ENU; central ray intersects [10,20,0], slant range exactly 5 m before noise/offset.
3. **Thermal units:** 300.00 K -> 26.85 °C display; palette change does not alter 300 K raw value.
4. **LiDAR with max range 4 m:** nadir ray from 5 m to plane 0 -> OUT_OF_RANGE, no 4 m clipped "hit".
5. **Nadir camera square-pixel focal length:** W=320 px, FOVh=70°, fx=(160)/tan(35°)≈228.50px, principal point cx=160.5 with chosen 1-based indexing; projection and matrix convention must use the same origin.
6. **Missing thermal:** valid=false, invalid_reason=SENSOR_DROPOUT, raw numeric pixels NaN, display shows SENSOR OFFLINE (SIMULATED); detector cannot use a stale 300 K frame at new tick.
7. **Counterfactual:** hold RGB, thermal, LiDAR numeric observations and metadata constant; change only private target label and coordinates; expected public detector output unchanged.
8. **Target-free scene:** all private labels negative; any detector suspected event is FP in post-run evaluation; real-time UI cannot know whether it is FP.

## D. Contract QA checklist — Shabaz DOC signoff

- [x] RGB camera intrinsics/extrinsics, image shape, optical geometry, mounting and sample timing specified.
- [x] Thermal numeric Kelvin frame, apparent/surface distinction, environment model, physics limitations and display palette invariance specified.
- [x] LiDAR point/ray representation, noise/dropout, geometry, range validity and terrain-only role specified.
- [x] Virtual GPS/INS, rates, seed, frame transform and unit conventions specified.
- [x] Typed public envelope and invalidity/missing/quality/privacy rules specified.
- [x] Strict truth-only evaluator and prohibited data field policy specified.
- [x] New grouped train/validation/TEST design and unit-level/event-level metrics specified; consumed V1 TEST preserved.
- [x] Named positive/negative/scenario stress families, controlled false-alarm tests and leakage tests specified.
- [x] Traceability to 30 later acceptance checks and 25 existing V2-001 final demo cases.
- [x] Actual MATLAB implementation, sensor frames, accuracy numbers and performance tests are **not claimed as executed**.
- [ ] GitHub Task Gate and human review acceptance of this documentation PR (must be verified).
- [ ] Separate V2-004 DONE status PR once documents and evidence are on main (must be verified).

## E. Exact handoff to Rahil (V2-005)

Rahil must take a **clean main checkout** after V2-004 is DONE, read all three V2-004 docs and V2-001 documents, check installed toolboxes and actual V2-002/003 scene/pose APIs. Implement native/scene-based sensor adapters with the specified contracts, generate real MATLAB proof frames, and independently validate the SC-xx cases. If a concrete API conflicts with documented MountingAngles, quaternion convention or geometry, produce a redlined correction for Shabaz review **before** silently diverging from frozen contract.

Output to reviewer must include separate RGB and thermal frame captures (thermal with numerical K legend), LiDAR point cloud and a combined same-tick demo of the same patch of terrain; exact source SHA, run seed, sensor rate, timing, invalid sample handling and numerical geometry. No implementation feature is DONE until user-visible proof and task-specific evidence pass.

**Source snapshot:** reviewed public sources linked in section A as of 2026-11-01. Future MATLAB API/test behavior must be verified on actual installed release, not inferred from docs.
