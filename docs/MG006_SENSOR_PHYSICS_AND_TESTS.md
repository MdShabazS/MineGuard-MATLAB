# MG-006 — Thermal + Electromagnetic Sensor Physics and Validation Specification

**Owner:** Shabaz · **Specification date:** 2026-10-31 · **Artifact type:** documentation / acceptance criteria
**Scientific status:** literature-checked *modelling assumptions*, **not calibrated physics and not operational buried-mine detection**.
**Downstream implementation:** Rahil, MG-007, after MG-006 has been marked DONE on protected `main`.
**Interfaces:** `mg-contract/1.0` in [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md). This document does **not** revise existing MATLAB public function signatures or schema field names.

## 1. Research conclusion and mandatory limitation

MineGuard is a MATLAB simulation of a **hypothetical research survey** with seeded synthetic surrogate objects and deliberately imperfect sensing. Infrared measurements show apparent **surface temperature / radiance**, not direct subsurface object identity. Electromagnetic induction depends on **electrically conductive / magnetically responsive material, coil and frequency, depth, ground clearance and interference**; conventional coil signals cannot be treated as a reliable high-altitude way to locate arbitrary buried objects. Neither channel identifies explosives or declares terrain safe.

Relevant published comparisons are modality- and acquisition-specific:
- A 2024 thermographic UAV paper [S1] describes results at heights of **1–5 m**, with shallow burial/low-altitude advantages in that particular dataset; its reported accuracy must **not** be transplanted to MineGuard.
- A 2024 soil heat/moisture study [S2] demonstrates why treating buried thermal contrast as a fixed bright blob ignores heat/moisture migration and radiative physics.
- A 2026 multimodal seeded-field comparison [S3] reports that surface UAV RGB/thermal and subsurface handheld EMI have very different strengths. One experimental *pseudo-UAV* EMI configuration was also examined; **do not generalise either universal failure or universal airborne success**. Acquisition geometry and hardware determine the result.
- MathWorks's R2026b sensor/fusion toolbox page [S4] describes broad sensor models. **MG-002 evidence says Sensor Fusion and Tracking Toolbox is not licensed**, so no MG-007 design may depend on that toolbox. Core MATLAB + already verified UAV Toolbox/Navigation infrastructure are sufficient.

**Review wording:** 'Research-inspired deterministic thermal and normalized EM *synthetic responses* with explicit validity limits and negative controls.' Never say 'validated drone metal detector', 'real-world mine-detection accuracy', 'field safe', or 'mine cleared'.

## 2. Source-of-truth interfaces and access firewall

Already frozen by MG-003:

```matlab
thermalSamples = mineguard.sensors.simulateThermal(config, scenario, poses);
emSamples      = mineguard.sensors.simulateEM(config, scenario, poses);
```

- `config`: the experiment's `ExperimentConfig`, optionally extended by a **versioned `sensor_settings` substruct** for simulation inputs. Missing physical parameters are NOT filled with invented defaults and must be explicitly labelled `UNSET` or cause a clear `mineguard:InvalidSensorConfig` error.
- `scenario`: **restricted** scenario wrapper assembled from MG-004 `geometry`, `truth`, `environment`. Ground truth may be read **inside forward physics** to generate a simulated measurement, never included in returned `SensorSample` or accessible to detector, navigation, fusion, policy or the GUI's inference callbacks.
- `poses`: MG-005 typed `PoseSample` table with `pose_sample_id`, monotonic `t_s`, and ENU `x_east_m/y_north_m/z_up_m` in metres. Simulator must not call a hidden-target-aware planner to choose the next observation position.
- Outputs: one typed `SensorSample` table per modality, in stable pose/time order. Retain the **exact** `mg-contract/1.0` fields; columns described below. No `target_id`, `label`, truth coordinate or material field appears in any public sample. No generic `measurement_value` alias.
- The model may expose **deterministic, explicitly named private helpers** for physics and validity. Never alter shared `ExperimentConfig` or a pose/truth argument in place; derive a local `RandStream`.

### Mandatory SensorSample table contract

| Field | Thermal sample | EM sample |
|---|---|---|
| `sample_id` | Unique stable string, e.g. `TH-000001` | Unique stable string, e.g. `EM-000001` |
| `pose_sample_id` | Reference existing pose row | Reference existing pose row |
| `t_s` | Pose time (seconds), finite/monotonic | Pose time (seconds), finite/monotonic |
| `sensor_kind` | String `"thermal"` | String `"em"` |
| `temperature_K` | Double, **kelvin** and >0 if valid | `NaN` |
| `response_norm` | `NaN` | Dimensionless double (can be signed with noise) |
| `noise_sigma` | Nonnegative double in **kelvin** | Nonnegative double in normalized response units |
| `standoff_m` | Sensor height above local ground surface | Coil height above local ground surface; burial depth enters *separately* in response geometry |
| `footprint_radius_m` | Approximate projected camera footprint at ground | Effective coil response support radius (assumed, **not optical FoV**) |
| `valid` | Logical observation validity | Logical observation validity |
| `invalid_reason` | Empty string when valid; explicit machine-readable reason if invalid | Same rule |

For invalid readings, set `valid=false`, the **active channel's value to NaN**, and a nonempty `invalid_reason` such as `POSE_INVALID`, `MODEL_OUT_OF_DOMAIN`, `UNCONFIGURED_SENSOR` or `DROPPED_SAMPLE`. The opposite channel remains NaN regardless. Always retain row linkage and timestamp so a downstream fusion module can identify the dropout; do not replace missing observations by zero, truth labels or interpolated fabricated detections.

**Sensor sample count:** nominally one sample per input pose for each sensor. For a configured dropout, preserve the row with `valid=false` and NaN. Sampling-rate decimation is permitted only with explicit step/phase configuration, stable IDs and a documented mapping, never silent omission.

## 3. Coordinate geometry, clearance and sampling

1. Internal coordinates remain right-handed **ENU metres**, angular fields in radians, `t_s` seconds; no NED conversions within sensor forward models.
2. Define `h_ground_m = terrainHeight(x,y)`; for current MG-004 flat S0, it is 0 m. `standoff_m = sensor_z_up_m - h_ground_m`; reject/mark invalid if negative or pose is outside scenario bounds/exclusion/sensor validity domain. Do not silently take `abs(standoff)`.
3. A synthetic object's `burial_depth_m` is positive **below local ground**, so the sensor-to-object vertical separation is `standoff_m + burial_depth_m`; an illustrative 3D distance is `sqrt(dx^2 + dy^2 + (standoff + burial_depth)^2)`. Never use target depth as sensor altitude.
4. Thermal nadir camera projected radius for the initial flat-ground model: `r_footprint_m = standoff_m * tan(camera_half_fov_rad)`, where `0 < camera_half_fov_rad < pi/2`. The footprint **averages/dilutes** subpixel anomalies; larger footprint must not artificially amplify a fixed small source.
5. EM footprint is **not** the thermal camera footprint. Use a documented effective response-support radius or coil geometric parameter with a labelled modelling assumption; do not claim it equals realistic detector range.
6. Validate `pose_sample_id` existence/uniqueness and consistent sample timestamps; invalid timestamps, impossible clearance, out-of-bounds poses and unsupported geometry receive an explicit error or invalid record. Time alignment across modalities is the later MG-008/MG-009 fusion requirement.

## 4. Thermal response — defensible phenomenological baseline

### Physics reference and what the implementation does not claim

The fuller continuous thermal starting point is the heat equation

```text
rho(x) * c_p(x) * dT/dt = div(k(x) * grad(T)) + q(x,t)
```

with temperature `T` [K], density `rho` [kg/m³], heat capacity `c_p` [J/(kg·K)], conductivity `k` [W/(m·K)] and volumetric heat `q` [W/m³]. Real soil thermograms also depend on moisture transport, radiation, emissivity, viewing angle, time of day, sun/shadow, material and image resolution [S2]. **MG-007 may implement a transparent phenomenological proxy first** instead of claiming it numerically solved this PDE. If no actual PDE solver and boundary conditions are implemented, do not call the proxy 'heat-equation based'.

A permitted initial model (all coefficients assumed/unvalidated) for a nadir single-sample footprint is:

```text
T_thermal_obs_K(t,p) = T_background_K(t,p; soil, daylight)
                     + sum_i [contrast_i_K(t,soil,depth_i,material_i)
                              * spatial_weight_i(p,footprint)]
                     + clutter_temperature_effect_K(t,p)
                     + epsilon_thermal_K
```

- `T_background_K` is explicit and strictly positive. An educational fixture may use **293.15 K (20 °C) as a numerical input**, **not** an observed soil temperature or calibrated operating point.
- `contrast_i_K` must be **signed** and may equal zero, vary with time of day and decrease/become undetectable with burial depth, soil moisture or spatial mixing. Do not hardcode 'buried target is always hotter'. Any chosen exponential/Gaussian shape is an **assumed response family**, not the heat equation solution.
- `spatial_weight_i` must be bounded [0,1], decrease appropriately outside footprint and include footprint dilution for a fixed small anomaly. Avoid a target-relative Gaussian peak that remains identical when flying arbitrarily high.
- Explicit negative controls: target-free soil, dark/same-temperature targets, hot **harmless** rocks, shading and time-dependent ambient change. Thermal clutter can produce larger readings than a synthetic target.
- Add local RNG `epsilon_thermal_K ~ N(0, thermal_noise_sigma_K^2)` for an **assumed Gaussian sensor-noise model**, independent from MG-004 scenario placement seed. Save RNG seed and model version. A Gaussian assumption is not evidence of any named real camera's noise.

**Required documented inputs (MG-007; fields may be nested under `sensor_settings.thermal`):**

| Parameter | Unit and validity | What it controls |
|---|---|---|
| `background_temperature_K` | K, finite >0 | Synthetic soil baseline |
| `time_of_day_s` or explicit scene-time reference | seconds or documented day fraction | Boundary forcing/contrast phase |
| `contrast_amplitude_K` | K, finite and **signed** | Max assumed contrast; zero is a required negative control |
| `thermal_depth_scale_m` | metres, >0 | Illustrative suppression of buried signal |
| `camera_half_fov_rad` | radians, 0–π/2 exclusive | Nadir footprint; no real camera implied |
| `thermal_noise_sigma_K` | K, >=0 | Local seeded noise amplitude |
| `soil_class` and `model_version` | categorical strings | Scenarios and traceability |

Treat weather, moisture and emissivity as explicit *unimplemented/assumed* effects unless actually modelled. Model time dynamics only if the code truly uses time; otherwise declare a static baseline.

## 5. EM/metal-coil channel — strict stand-off limitation

### Physical caveats and permissible normalized proxy

Near-field induction signals depend on **coil transmit/receive geometry, excitation frequency, conductivity and permeability, object orientation, soil and distance**. An ideal dipole field may have inverse-cubic distance behaviour in a restricted regime; a real metal-detector **system response is not a guaranteed `1/r^3` law**. Do not label an arbitrary power law a calibrated metal detector.

MG-007 may use a bounded *illustrative* monotone attenuation function, explicitly named `phenomenological_em_proxy`:

```text
d_i_m = sqrt((x-x_i)^2 + (y-y_i)^2 + (standoff_m + burial_depth_i_m)^2)
signal_i_norm = material_response_i_norm * f(d_i_m; assumed coil scale and shape)
response_norm = background_em_norm + sum_i(signal_i_norm)
              + interference_em_norm + epsilon_em_norm
```

Required properties:
- `f(d)` is bounded [0,1], non-increasing in nonnegative distance and documented with a **sensitivity analysis over assumed shape/scale**. Example *proxy* `f(d)=1/(1+(d/d0)^p)` for `d0>0,p>0`; this is **not a claim about any particular device**.
- Synthetic metallic clutter can produce a positive response; **nonmetallic objects with zero modelled metal content must have `material_response_i_norm = 0`** in the deterministic signal term. Background/interference/noise may remain nonzero.
- The MG-004 `material_type` value `"synthetic_cased_surrogate"` **does not by itself prove metal content**. Define and store a documented model material-response lookup for **every** synthetic material used by the fixture. Unknown types must not default to 'detectable metal'; reject or mark as unsupported. `"synthetic_metal_debris"` is conductive clutter, not a target label.
- `standoff_m` is coil-to-**ground** clearance. Buried-object separation includes depth and horizontal offset. A sensor at 5 m above ground must **not** receive a secretly boosted response compared with 0.2 m under equivalent model conditions.
- If outside the explicitly declared **model domain** (e.g. larger than `em_model_max_standoff_m`), return `valid=false`, `response_norm=NaN`, `invalid_reason="MODEL_OUT_OF_DOMAIN"` — **do not set `response_norm=0` and call it a real measurement**. An in-domain response indistinguishable from model noise is a valid weak observation, not evidence of successful detection.
- Add seeded zero-mean noise (normalized units), background response and conductive clutter. Do not enforce a chosen detection threshold in the *forward model*; thresholds and false-alarm evaluation belong to MG-008/MG-009.
- Pose outside physical/model domain must fail or be marked invalid. No claim that a particular cutoff has empirical justification until instrument characterization exists.

**Required documented inputs (MG-007; `sensor_settings.em`):**

| Parameter | Unit/validation | Role |
|---|---|---|
| `em_model_kind` | string `phenomenological_em_proxy` | Names noncalibrated model |
| `material_response_lookup` | mapping material type→finite normalized gain | Distinguishes metals, plastic/nonmetals, clutter and unknowns |
| `em_distance_scale_m` | metres, positive | Assumed distance roll-off parameter |
| `em_falloff_exponent` | positive, dimensionless | Shape; **not** empirical field law |
| `em_noise_sigma_norm` | normalized, >=0 | Seeded noise assumption |
| `em_background_norm` | finite normalized value | Ground/coil baseline response |
| `em_model_max_standoff_m` | metres, positive; labelled **modelling cutoff** | Explicit supported model domain |
| `em_footprint_radius_m` | metres, nonnegative | Hypothetical effective spatial support; *not* detection depth |
| `coil_geometry_note`, `model_version` | strings | Provenance and realism caveat |

Do **not** fabricate coil sensitivity specifications, actual electromagnetic coupling constants or claims of detection at 5 m. The field geometry cases **0.05, 0.2, 0.5, 1, 2 and 5 m** are stress-test design points, not expected success heights. The optional hypothetical long-range model may be *invalid* beyond its declared domain; report that explicitly.

## 6. Reproducibility and source separation

- Sensor channel noise seeds must use the existing MG-004 `environment.rng.thermal_seed` and `environment.rng.em_seed`; no unseeded `randn`, no global `rng(seed)` that mutates shared state. Under identical run parameters, pose stream, truth and seeds, the valid/invalid mask and numeric stream must reproduce via `isequaln`.
- Do not mix global RNG states across scenario generation, thermal and EM; do not couple noise values so both channels receive identical random innovations by accident.
- No sensor function may write to `ScenarioGeometry`, pose data or hidden `TargetTruth`. The public `SensorSample` columns and export must be inspected against hidden labels/positions.
- Store `scenario_id`, `seed`, channel seed, `model_version`, model parameter table, package function used, MATLAB release and Git SHA in evaluator/run metadata or separate evidence (without leaking hidden truth into detector observations). If source metadata is physically unavailable, explicitly `NOT_RECORDED`, not guessed.
- The selected synthetic material response map, time/soil forcing and sensor assumptions must be versioned. No real minefield coordinates, hazardous-device details, licence secrets or unlicensed datasets.

## 7. Acceptance test matrix for MG-007 (Rahil must execute actual MATLAB)

The following are **required tests**, specified **now** but **not executed** by MG-006. For tolerance, assert exact invariants when deterministic; use documented numeric tolerances for floating calculations and statistical confidence intervals for noisy distributions. Never assume a fixed 'real detection accuracy' threshold.

| ID | Controlled input | Required observation / pass condition |
|---|---|---|
| S-01 / C-06 | Flat fixture: one pose, thermal baseline 293.15 K, zero contrast/noise | Valid thermal reading exactly 293.15 K (within floating tolerance), EM column NaN, units K |
| S-02 | Same fixture, `contrast_amplitude_K=0` / zero noise, target vs empty truth | Same deterministic temperature for target and empty; **no synthetic guaranteed hotspot** |
| S-03 | One small nonzero contrast; near vs far projected footprint, with noise off | Distant/wider footprint does **not increase** fixed-source contrast; document spatial mixing limitation |
| S-04 | Contrast sign positive, zero and negative; morning/noon scenarios if time forcing is implemented | Output can warm, disappear or cool; no hardcoded target > clutter inequality |
| S-05 | Harmless thermally hot rock plus target-free scene | Positive anomaly can arise without a target; observations carry **no true class labels** |
| S-06 / AT-04 | One conductive surrogate, fixed depth/xy, EM separations `0.05,0.2,0.5,1,2,5 m`; no noise | Supported model-domain deterministic signal must not strengthen with increased separation; out-of-domain invalid explicitly; never call it empirically calibrated reach |
| S-07 / AT-05 | Nonmetallic surrogate material gain 0; no metallic clutter; noise disabled | No deterministic **metal-object** contribution. Background may remain; no fabricated metallic identification |
| S-08 | Conductive clutter and conductive target separately | Both may generate EM response; sensor output reveals neither object label nor target ID |
| S-09 / C-08 | Inject thermal-only and EM-only dropout; invalid pose/domain | Keep typed rows/IDs, invalid channel NaN+reason, opposite modality does not inherit missing value; both-invalid event handling deferred to MG-009 |
| S-10 | Repeat same config, seed and poses twice; global RNG snapshot | Bitwise-equal valid and invalid outputs under `isequaln`; global RNG unchanged; channel seeds are recorded and independent |
| S-11 | Geometry and schema validity: monotone timestamps, unique sample IDs, pose refs; bounds/clearance | No invalid field names; impossible geometry/units either rejected or explicitly marked invalid with documented reason |
| S-12 | Synthetic model parameters missing/NaN/Inf, nonpositive FoV scales, unknown material | Explicit `mineguard:InvalidSensorConfig` or documented `UNCONFIGURED_SENSOR` invalid rows; no silent parameter substitute |
| S-13 / AT-09 | Empty field with nonzero noise | Valid background-only sensor data; any future detector false alarms measured separately, not called true positives |
| S-14 | Multiple seeded scenarios/soil assumptions/thermal time conditions and dropout sensitivity | Sensitivity plot/table for output amplitude vs depth, clearance, footprint and noise; each model parameter documented as assumed, not calibrated |

**Minimum MG-007 delivery:** functional `simulateThermal.m` and `simulateEM.m`, typed empty/output schema tests, 14 above controlled cases (where applicable), required negative controls, actual MATLAB R2026b execution log, observed numerical outputs with units and limitations, `tasks/evidence/MG-007.md`. Small numerical sweeps may be executed without any detector/fusion. **Do not conflate MG-007 PASS with mine-detection performance**.

## 8. Ownership boundaries and gates

| Task | Owner | Responsibility / specific gate |
|---|---|---|
| MG-006 | Shabaz | This specification, published source verification, parameter assumptions, test plan and handoff. **No executed MATLAB sensor-model results claimed.** |
| MG-007 | Rahil | Implement *only* sensor forward models/controlled MATLAB tests after MG-006 DONE and MG-004 DONE on main. Use already verified MATLAB R2026b. |
| MG-008 | Shabaz | Fusion thresholds, alignment tolerances, dataset/split protocol and held-out scoring spec; this is not calibration of physical sensing. |
| MG-009 | Rahil | Detector/fusion algorithms and reproducible metrics on genuinely held-out **synthetic** scenarios; no truth leakage or invented accuracy. |

**Integration gate:** after merging MG-006 documentation, Shabaz must separately propose `MG-006 IN_PROGRESS -> DONE` through protected PR and verified GitHub Task Gate. Only a DONE state on `main` unlocks downstream MG-007 and MG-008. Do not bypass GitHub ownership, branch protection or required test evidence.

## 9. Verified primary/publication references

- **[S1]** *Detection of anti-personnel mines of the “leg breakers” type by analyzing thermographic images captured from a drone at different heights*, *Infrared Physics & Technology* **142** (November 2024), 105567, DOI: https://doi.org/10.1016/j.infrared.2024.105567. Publisher abstract: thermograms at 1–5 m, shallower objects and 1–2 m beneficial in that study. **Dataset-specific, not a MineGuard performance promise.**
- **[S2]** Hu et al., *Study on the temperature field and infrared characteristics of unsaturated soils with shallow buried objects at different depths*, *International Journal of Thermal Sciences* **205** (November 2024), 109282, DOI: https://doi.org/10.1016/j.ijthermalsci.2024.109282. Soil heat/moisture/radiation coupling; exact models/coefficients not copied or claimed implemented.
- **[S3]** *A Comparative Evaluation of UAV-Based Remote Sensing and Geophysical Techniques for Landmine Detection on a Seeded Minefield*, *Remote Sensing* **18**(13) (2026), article 2182, https://www.mdpi.com/2072-4292/18/13/2182. Separate surface/subsurface outcomes, real-world limitations and a specific pseudo-UAV EMI evaluation.
- **[S4]** MathWorks, R2026b *Sensor Models*, https://www.mathworks.com/help/fusion/sensor-models.html ; product index is **not** proof that Sensor Fusion and Tracking Toolbox is licensed on Rahil's computer (see `tasks/evidence/MG-002.md`).
- **[S5]** Existing project [PHYSICS_AND_FEASIBILITY.md](PHYSICS_AND_FEASIBILITY.md), [LITERATURE_REVIEW.md](LITERATURE_REVIEW.md), [RESEARCH_PLAN.md](RESEARCH_PLAN.md), and [ACCEPTANCE_MATRIX.md](ACCEPTANCE_MATRIX.md) specify limitations and source traceability.

**Verification boundary:** these reference titles, dates, publication records and publisher abstracts were checked on 2026-10-31. Full independent calibration, field measurements, instrument parameters and numerical sensor-model validation remain **NOT PERFORMED**.
