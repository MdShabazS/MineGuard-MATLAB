# V2-004 — Virtual Multi-Sensor Contracts and Engineering Model Freeze

**Owner:** Shabaz + ChatGPT | **Date:** 2026-11-01 | **Contract:** mg-v2-sensors/1.0  
**State:** Research-backed normative specification; implementation and MATLAB execution are NOT claimed.  
**Consumes:** V2-001 requirements and architecture; V2-002 public pose snapshots; V2-003 shared terrain geometry.  
**Enables:** V2-005 sensor generation; V2-006 observable-only anomaly mapping; V2-007 UI; V2-008 independent verification.  
**Academic boundary:** SIMULATION ONLY — sensor outputs are synthetic; suspected features are not verified buried mines or land release.

## 1. Technical choices and scope

The V2 demonstration MUST have **three visibly distinct synchronized feeds** originating from the same deterministic virtual scene: a downward RGB camera, a radiometric-style thermal camera and terrain-measuring LiDAR. Virtual GNSS/INS reports are an auxiliary navigation channel. Screens are actual generated samples from the simulation at the declared pose, never unrelated images, a palette imposed on RGB, or fake point clouds.

| Channel | Primary measurable role | Model level and source | Forbidden interpretation |
|---|---|---|---|
| RGB (nadir) | Visible surface, vegetation, rocks, clutter; image-to-map geometry | Perspective-projected scene radiance/reflectance proxy, texture/material and lighting; deterministic optics/noise | Seeing an object implies confirmed explosive identity |
| LWIR thermal (nadir) | **Apparent** surface-temperature patterns with environmental/measurement nuisance factors | Kelvin-valued surface-temperature and radiometric forward model; false color is display-only; approximate band model flagged | A warm pixel is a buried mine; exact physical temperature without calibrated emissivity |
| LiDAR | Surface ranges, point cloud, local ground elevation / above-ground clearance | Ray–scene intersections, statistical range noise, range limits and dropout; native UAV Toolbox where tested | Surface LiDAR detects buried targets or determines safe ground |
| Virtual GNSS/INS | Noisy pose/heading/velocity measurement and quality | Simulated platform state plus specified bias/noise/dropout | Real GPS coordinates, a functioning onboard receiver, or navigation safety certification |
| Optional V1 EM | Synthetic dimensionless response proxy in separate, explicitly named legacy channel | V1 frozen model only, not default detector source | Physical metal detector, measured magnetic field, subsurface sensor evidence |

Do NOT add magnetometer, GPR, multispectral, or actual remote telemetry to V2-005 without a separately reviewed model/contract and test plan. The original Phase-1 objectives remain intact; this virtual system does **not** meet their real-world buried-mine detection/clearance implications.

## 2. Cross-module contract — immutable public data and strict units

**Contract version**: mg-v2-sensors/1.0. Schema changes require increment, migration and regression. Do not mutate original V1 mg-contract/1.0.

### 2.1 Reference frames and timestamps

- World coordinates: **local ENU [E,N,U] metres**, double, with surveyed virtual datum (0,0,0). NED conversions only in the V2-002/003 UAV Toolbox adapter, never repeated inside the sensors; x_N=y_N, y_E=x_E, z_D=-z_U.
- UAV body frame: axis semantics and quaternion must be **explicitly handed off by V2-002/003**. Freeze serialized quaternion order **[w,x,y,z] (scalar-first)** with unit norm, right-handed rotation convention, and T_world_body transforming body-frame column vectors into ENU world. Do not blindly pass a MATLAB quaternion array to other modules without a tested convention adaptor.
- Sensor mount T_body_sensor = {translation_body_m [3], rotation_sensor_to_body [3x3]}; use rigid transforms: p_world = R_world_body (R_body_sensor p_sensor + translation_body) + position_world. R_body_sensor is an **active** rotation mapping sensor-frame vectors into body-frame vectors. Mounts are data, never infer from UI camera angle.
- RGB/thermal optical sensor coordinates: +z forward along the optical axis, +x pixel-right, +y pixel-down; camera optical +z is approximately world -U in nadir mode. LiDAR local axes and ray directions must be declared separately. **Never reuse pixel transform for LiDAR unless explicitly transformed and tested.**
- Simulation clock: tick_id is nonnegative integer; t_s = tick_id * dt_s (0.05 s nominal), finite. Every sample references an **existing immutable PoseSample** by pose_id and tick_id, with **exact same t_s** within numeric roundoff. No sensor may mint a new pose_id or wall-clock timestamp.
- Sampling uses modulo tick schedule: every N = round(1/(dt_s*rate_hz)) ticks, with a hard check that N >= 1 and abs(N*dt_s-1/rate_hz) <= 1e-9 s; reject incompatible rates rather than quietly drifting. Nominal initial RGB 5 Hz (N=4), thermal 5 Hz (N=4), LiDAR 2 Hz (N=10), virtual navigation 10 Hz (N=2), fixed simulation 20 Hz (dt=0.05). Actual runtime frame rates to be measured and revised only after approval.
- The scheduler must **compute sensing from a single pose/scene snapshot at each due tick**. A previous frame displayed during render lag retains its old t_s and gets a visibly stale indicator. Paused tick = no new pose or sensor data. Frame rendering may run slower than simulation without changing scientific sample timestamps.
- Each physical/stochastic channel gets a named independent deterministic random stream derived from recorded master seed + scenario ID + sensor ID; do not change RGB RNG stream when thermal/LiDAR are enabled. Store full RNG derivation algorithm/version, not just a claim of reproducibility. Sampling order must not affect results in same model version.

### 2.2 Required common sample envelope

Each observation is a MATLAB struct or typed table row with exact following fields:

| Field | Type, units, rule |
|---|---|
| schema_version | string scalar "mg-v2-sensors/1.0" |
| run_id, scenario_id | nonempty string scalar identifiers of actual run and scenario |
| sensor_id | controlled string: RGB_NADIR / THERMAL_LWIR / LIDAR_TERRAIN / VIRTUAL_GNSS_INS |
| sample_seq | uint64 monotonically increasing within sensor stream; never silently reused |
| pose_id | uint64/unique integer, valid reference to immutable V2-002 state |
| tick_id | uint64, exact engine tick that produced this sample |
| t_s | finite double seconds; equals referenced pose time |
| simulated | logical true; NEVER false on virtual channels |
| valid | logical scalar; missing cannot be masqueraded as real zero |
| invalid_reason | string scalar, empty iff valid; controlled reason codes below |
| sensor_model_version | nonempty string, method and parameter-set hash retained in manifest |
| frame_id | unique sample-frame identifier; enables event evidence selection |
| coordinate_frame | "sensor" / "ENU"; for numeric output fields make frame unambiguous |
| footprint_enu_m | Nx2 double polygon projected into world ENU, or typed 0x2 empty on invalid/unavailable |
| data_ref | relative URI/path into run package when persisted, or explicit absent value; cannot point outside run root |
| calibration_kind | "SYNTHETIC_ASSUMED" / "NUMERIC_TEST_FIXTURE" / "RECORDED_RESEARCH" (recorded research cannot silently become simulated live scene) |
| quality | struct with finite model-estimate values and explicit unavailable flags, no fabricated calibrated probability |
| units | modality-specific machine-readable units metadata |

Required invalid_reason enumeration: NONE (valid), NOT_SCHEDULED (no sample record should usually be emitted), SENSOR_DROPOUT, OUT_OF_RANGE, NO_INTERSECTION, OCCLUDED, CAMERA_OUT_OF_VIEW, INVALID_POSE, INVALID_GEOMETRY, NUMERIC_ERROR, STALE_DATA, UNSUPPORTED_MODEL, UNAVAILABLE_TOOLBOX. For invalid sample, **numeric fields use NaN with separate validity masks**, image pixels may use typed empty or per-pixel masks and must not display as true zero-valued observations.

### 2.3 Canonical configuration

- SensorConfig common: schema_version, sensor_id, enabled, rate_hz, mount pose, model_version, rng_stream_id, parameter_hash, dropout_model, valid_range_m, units, config_origin (ASSUMED | CHARACTERIZED | MEASURED). Default must be ASSUMED.
- SceneRadiometryConfig (private to forward generator): materials, illumination, sun/ambient, soil water proxy, emissivity proxy, temperature field, surface shading, nuisance/target hidden parameters. This type MUST NOT be passed to detector, UI or navigator.
- VisibilityScene (public): mesh, appearance, geometry, non-secret surface features and terrain materials required to render what an observer genuinely could see. No target label, burial depth or classification.
- Typed sample arrays must retain correct shape for zero rows. All required fields checked at producer-to-consumer boundaries. Unknown fields must be rejected at privacy boundary; this avoids entire private scenario structs being passed into detector.

### 2.4 RGB contract (RGB_NADIR)

Default **target**, not measured device performance: 320x240 RGB uint8 [240,320,3]; 5 Hz sampled; 70-degree horizontal FOV; compute vertical FOV from aspect ratio and fx/fy, not a second arbitrary guess. Principal point at [(W+1)/2,(H+1)/2] and fx = (W/2)/tan(FOVh/2), fy=fx for square pixels. Distortion initially zero with explicit field, not silently ignored.

RGBFrame includes:
- image_rgb_uint8, valid_pixel_mask logical [H,W], image_height, image_width;
- intrinsic K (3x3 double, pixel convention and index origin documented), focal lengths_px, principal_point_px, fov_h_deg;
- T_body_sensor, T_world_sensor, exposure_proxy, lighting_mode, noise_parameters, source_model_version;
- an exact per-frame footprint polygon and/or four corner ray hit points with valid flags.
- persistent sample provenance per envelope.

Scene generation must project visible color/material textures onto camera rays intersecting shared V2-003 terrain geometry; objects behind geometry are occluded. Camera frames MUST move/rotate as the UAV moves and agree with landmarks on mission map. If the scene renderer has no usable image camera, use a documented **procedural ray/height-field sampler** referencing same geometry. Do not feed unrelated internet images, stock/video footage or hidden target positions to runtime inference. No claim that procedurally shaded textures are optically calibrated imagery.

### 2.5 LWIR thermal contract (THERMAL_LWIR)

Default target: 160x120 double **temperature_K** [120,160], 5 Hz, 45-degree nominal horizontal FOV with its own calibration and T_body_sensor (thermal and RGB need not pixel-align). Every pixel has a valid mask and synthetic uncertainty/noise parameters. Kelvin array is the scientific sample; any Ironbow/White Hot/Turbo palette is GUI transform only (switching palette must not change numeric K array, hash or event score).

**Reference forward model, approximate and explicitly noncalibrated**:
1. Scene contains *surface* temperature in Kelvin based on material, ambient temperature, insolation/shadow and deterministic nuisance (moisture, albedo, time-of-day); thermal effect of hidden objects is an optional **explicitly declared hypothetical perturbation** to the *surface temperature forward model*, never a valid physical buried-mine sensitivity claim.
2. Compute approximate broadband apparent radiance using emissivity eps in (0,1], atmospheric transmittance tau in (0,1], reflected environment T_refl,K, atmosphere T_atm,K:
   Lproxy = tau * [eps * sigma * T_surface,K^4 + (1-eps)*sigma*T_refl,K^4] + (1-tau)*sigma*T_atm,K^4.
   This is a **Stefan–Boltzmann broadband radiative proxy**, not correct band-integrated LWIR spectral response and NOT a calibrated IR camera. If using direct Kelvin proxy instead, name it and do not claim it is radiometrically corrected.
3. Invert the stated synthetic response model only if mathematically valid; otherwise return **apparent_temperature_K**, not surface ground-truth temperature. Document eps/tau assumptions, additive NETD-like temperature noise, blur/PSF, FOV/downsampling, saturation and missing pixels.
4. Spectral 8–14 µm bandpass / real detector counts / field calibration are out of scope until separately modeled and validated against external data. Report assumptions rather than assigning arbitrary military-grade sensitivity.

ThermalFrame required: temperature_K [H,W] finite for valid pixels, NaN for invalid; apparent_temperature_K versus surface_temperature_K labels must be distinguished, simulated_temperature_uncertainty_K (assumption), emissivity_assumed, atmosphere_transmittance_assumed, reflected_temperature_K, ambient_temperature_K, display_min_K, display_max_K (visual-only), palette_id, valid_pixel_mask, intrinsics, T_world_sensor, footprint_enu_m. A raw Kelvin tensor never changes when GUI palette changes. No mandatory "hotspot detector" event if conditions produce no distinguishable contrast.

### 2.6 LiDAR contract (LIDAR_TERRAIN)

Preferred **native** UAV Toolbox uavLidarPointCloudGenerator + uavSensor on compatible static mesh; fallback: *tested* geometrical ray–mesh/heightfield intersection + specified range noise/dropouts if native toolkit's geometry or rate constraints prevent the required scene. Record native/fallback implementation name in each sample; both return same canonical output schema.

Default **target** 2 Hz; max range 100 m; ray layout/resolution must be explicitly provided, not claim physical 16-beam sensor hardware. Simulated range measurement model r_meas = r_true + b_range + n(0,sigma_r^2) for hit and valid range, with deterministic stream and optional dropout; report b_range and sigma_r as assumptions, never measured actual UAV LiDAR spec. Never synthesize underground points.

LidarFrame fields: points_sensor_m Nx3 double; points_enu_m Nx3 double; ranges_m Nx1 double (NaN for no returns); ray_unit_vectors_sensor Nx3; valid_ray_mask Nx1 logical; return_count; range_bias_m; range_sigma_m; max_range_m; scan_azimuth/elevation in degrees; T_world_sensor; terrain_height_m / altitude_agl_m *when derived from valid observed returns*; no-hit and occluded points marked invalid with reason. Ordered point clouds may use HxWx3 with shape recorded; adapters must handle both representations.

Projections use the same V2-003 world geometry as RGB/thermal. Validate flat-plane range at AGL 5 m with centered nadir ray (expect ~5 m, allowing calibrated mount offset), sloped terrain and rotated aircraft; sign of NED down must never invert scan direction. LiDAR terrain observations **cannot measure a buried object beneath a visually intact surface**.

### 2.7 Virtual GNSS/INS contract (VIRTUAL_GNSS_INS)

Default target 10 Hz, measured-like reported ENU pose, velocity, yaw/roll/pitch or scalar-first quaternion, bias/noise/drift/dropout and quality flags. Model **reported** versus **actual simulated truth pose** separately; nav measurement may use forward model private pose without leaking target truth, but GUI must clearly say virtual. If MathWorks insSensor/gpsSensor available use them; else a deterministic documented perturbation model. Any lat/lon must be **virtual geodetic origin** with a tested ENU conversion; never actual satellite coordinates.

### 2.8 Validity and missing-data rules

- Invalid sensor data is **not** a numerical zero and is not proof of a clear field. For thermal, invalid array pixels are NaN and mask=false; for LiDAR, invalid rays NaN and mask=false; for RGB, use valid mask and explicit placeholder on unavailable frames.
- A sensor with invalid pose, pointing above horizon without ground intersection, out-of-range ground or fully blocked optical path returns a valid=false sample or explicit invalid mask, *not* copied frames with a fresh timestamp.
- If two modalities absent, detector emits no fused event; a single valid modality may emit an explicitly **single-modality SUSPECTED** observation only under a trained/validation-defined policy; absent channels must not be imputed from hidden labels.
- Exports preserve invalidity, sample provenance and sensor model versions; UI displays SIMULATED and STALE/INVALID indicators. "Covered" means **sensor footprint observed validly**, not SAFE.

## 3. Truth firewall and public/private flows

~~~
Private Scenario Builder (includes TargetTruth)
      |                    +----------------------+
      +--> forward model --| scene radiance /    |
      |     ONLY           | material / thermal  |
      |                    +----------+-----------+
      |                               |
      |                         SENSOR OBSERVABLES
      |                               |
      |                         sanitize + validate
      |                               |
      |                   Public SensorSample, PixelData
      |                               |
      |               +---------------+----------------+
      |               |               |                |
      |           Detector         Mapping          Recorder/UI
      |
      +----------------------> Separate evaluator ONLY
                      (hidden truth + frozen predictions)
~~~

**Prohibited in every public record** (including nested structs, JSON, MAT export, filenames, map overlays, logs and UI hover text): TargetTruth, hidden_truth, target_count, target_id when it encodes label, target class, burial_depth_m, true mine x/y, contamination label, experimental split truth, positive/negative ground-truth flag. Surface *appearance* features actually observable in RGB may remain, but no hidden class metadata. Producer must construct an allowlisted public struct rather than serialize-and-delete arbitrary private objects. Detector and planners receive **only** allowlisted observations plus safe configurations.

Separate truth-only evaluation receives predictions and private evaluation truth in a distinct process/call. Operator map markers come from x_est_m/y_est_m derived through observation-processing and not from truth coordinates. Every marker carries status="SUSPECTED", uncalibrated model_score, modality provenance, estimated uncertainty or unavailable reason; no CONFIRMED or SAFE/CLEARED state.

## 4. Precision, environmental scenes and controls

Required named synthetic scenario families for V2-005 / V2-006 testing:
- S0_VISUAL_DEMO: attractive visible surface object *fixture* and clutter; explicitly not evaluation accuracy.
- N0_TARGET_FREE: zero private hazards; rocks/soil/shadows can yield false anomaly scores; absence of reported event does not certify land.
- N1_CLUTTER: sunlit rocks, dry vegetation, metallic-looking objects, shadows and uneven soil (appearance false positives).
- N2_LOW_THERMAL_CONTRAST: surface temperature feature similar to background; make missed anomalies possible, not force bright hotspot.
- N3_DROP_OUT: thermal entirely missing during a chosen interval; RGB or LiDAR still usable but no fake thermal.
- N4_NO_HIT: LiDAR rays miss or exceed max range; must display NaNs/reasons.
- N5_GEOMETRY: sloped/rough terrain with fixed reference landmarks for RGB/thermal projection and LiDAR range.
- N6_MOTION: drone bank/pitch/yaw + translation to reveal incorrect extrinsics and footprint errors.

Named scenario parameters, seeds, expected observation properties and synthetic truth maintained in separately access-controlled research fixtures. V2-004 sets scenario *requirements*, not specific classifier performance or field detection thresholds.

## 5. MATLAB API feasibility and dependencies

- MathWorks uavSensor accepts platform-mounted lidar, gpsSensor, insSensor and custom sensor adaptor; **MountingAngles are [z y x] degrees**, so do not pass the canonical quaternion as-is. Sensor UpdateRate intervals must divide scenario time step.
- uavLidarPointCloudGenerator generates statistical LiDAR returns from meshes in sensor frame with HasNoise, MaxRange, RangeAccuracy and ray angular parameters. Validate runtime sample calls and any terrain geometry constraints against actual R2026b environment.
- uav.SensorAdaptor is available in R2026b for custom UAV sensor models; for RGB/thermal choose custom adaptor or external time-synchronized MATLAB procedure according to measured compatibility, but maintain common envelopes.
- cameraIntrinsics is part of Computer Vision Toolbox: **do not require it** unless available on user's Mac. Explicit K and ray projection math in base MATLAB is the supported fallback.
- Target hardware: user's Apple Silicon Mac MATLAB R2026b Update 1 with UAV Toolbox 26.2 observed; availability of extra toolboxes unverified. Unreal-based UAV integration is not macOS path. All three core virtual streams must have base-MATLAB/UAV-Toolbox feasible fallback or a documented blocker and acceptance change (never simulated fake feature).

## 6. Contract release / V2-005 handoff

V2-005 must first implement a pure scene/pose test fixture returning (a) geometrically stable RGB frame, (b) real numeric synthetic thermal-K frame, and (c) LiDAR sample from same pose, all with documented units/times. An integrated UI is V2-007, but V2-005 must export actual machine-readable sample arrays and enough screenshots for review. V2-006 consumes public samples for mapping; do not bypass V2-004 by injecting private source fields.

Minimum V2-005 coding gates:
1. Exact schema_version, sample IDs, pose reference, timestamp and deterministic seed.
2. Validated body/sensor/world optical transformations and ray-terrain intersection.
3. RGB landmark alignment; thermal Kelvin/palette invariance; LiDAR flat/sloped range test.
4. Missing/out-of-range/no-intersection samples and UI-safe quality flags.
5. Truth leakage and serializability tests (including nested fields and filenames).
6. Paused-clock and disjoint stream reproducibility tests.
7. Real MATLAB execution with OS/toolbox/version, commands, observed numeric outputs and code SHA.

For **evaluation design and frozen metrics** see V2_004_EVALUATION_PROTOCOL.md. For **test matrix and source traceability** see V2_004_VERIFICATION_MATRIX.md.

## 7. Source-backed rationale

1. MathWorks, UAV sensor: https://www.mathworks.com/help/uav/ref/uavsensor.html (supported sensor types, mounting conventions, update alignment).
2. MathWorks, UAV LiDAR: https://www.mathworks.com/help/uav/ref/uavlidarpointcloudgenerator-system-object.html (point clouds from meshes; noise and range).
3. MathWorks, custom sensor adaptor: https://www.mathworks.com/help/uav/ref/uav.sensoradaptor-class.html (R2026b adaptor interface).
4. MathWorks, cameraIntrinsics: https://www.mathworks.com/help/vision/ref/cameraintrinsics.html (optional toolbox; standard intrinsic parameters).
5. FLIR thermal radiometry guidance: https://support.flir.com/docdownload/assets/web/27eh/en-us/ (emissivity, reflection, humidity and path temperature effects).
6. For thermal approximate radiative equation: https://www.mdpi.com/1424-8220/23/18/8011 (broadband radiative relation and measurement nuisance).
7. Forero-Ramírez/Tenorio-Tamayo et al., Data in Brief 2023 thermal imagery, 2700 drone images: https://doi.org/10.1016/j.dib.2023.109443 (appearance study; no transferable MineGuard accuracy).
8. Baur et al., Remote Sensing 2026 seeded field modalities: https://www.mdpi.com/2072-4292/18/13/2182 (aerial RGB/thermal versus buried-object limits).
9. IMAS 07.11 land release, suspected/confirmed/cleared definitions: https://www.mineactionstandards.org/standards/07-11/

**Research interpretation:** published dataset detection rates are unique to that field and protocol; not MineGuard V2 performance. Sensor realism is validated by geometry/time/numeric/negative controls, not cosmetic appearance or scientifically unsupported buried-mine sensitivity.
