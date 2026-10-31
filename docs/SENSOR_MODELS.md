# Thermal and Electromagnetic Sensor Modelling Contract — MG-006

**Status:** **specification prepared; implementation/real MATLAB validation PENDING**.
**Authoritative acceptance plan:** [MG006_SENSOR_PHYSICS_AND_TESTS.md](MG006_SENSOR_PHYSICS_AND_TESTS.md) (MG-006 research and executable acceptance criteria S-01…S-14). This short document is the reader-facing interface, not a separate or conflicting contract.

## Purpose and limits

Research-only MATLAB simulation of thermal apparent temperature and electromagnetic induction-like response from **synthetic** target and clutter scenes. The thermal channel does not measure subsurface objects directly; the coil-inspired EM channel cannot magically detect nonmetallic material or respond reliably at arbitrary standoff. **Never claim proven drone detection of buried mines or safe terrain.**

The latest literature/physics evidence and exact citations are in [MG006_SENSOR_PHYSICS_AND_TESTS.md](MG006_SENSOR_PHYSICS_AND_TESTS.md), Section 9, and [PHYSICS_AND_FEASIBILITY.md](PHYSICS_AND_FEASIBILITY.md).

## Frozen interfaces and data records

The two planned functions (Rahil's **MG-007**, not implemented here) are:

```matlab
thermalSamples = mineguard.sensors.simulateThermal(config, scenario, poses);
emSamples      = mineguard.sensors.simulateEM(config, scenario, poses);
```

Use `mg-contract/1.0` from [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md), including its **11-field typed SensorSample table**: `sample_id`, `pose_sample_id`, `t_s`, `sensor_kind`, `temperature_K`, `response_norm`, `noise_sigma`, `standoff_m`, `footprint_radius_m`, `valid`, `invalid_reason`.

- Temperature measurement is **kelvin**; EM measurement is **dimensionless normalized response** until real calibration.
- Read `TargetTruth` only within the forward response simulator; never place `target_id`, true location, material class, source label or burial depth into SensorSample output.
- Coordinates and clearance in ENU metres, angles radians and times seconds. Ground clearance is different from total coil-to-buried-object distance.
- Missing/out-of-model readings use `valid=false`, active-channel `NaN` and explicit `invalid_reason`, never silent zero/truth substitution.
- Deterministic channel-specific local RNG seeds; preserve global RNG.
- Scalar nadir footprint model permitted; an image-processing/thermal PDE or calibrated real coil is **not** implied.
- When material lookup is incomplete, reject/mark unsupported. The synthetic `"synthetic_cased_surrogate"` label alone does not tell us if it contains metal.

## Controlled physical proxies and validation

**Thermal:** configurable background temperature, *signed* and potentially zero soil/target contrast, soil/time/depth assumptions, projected field of view, pixel mixing, independent noise and clutter false positives. If no PDE or moisture solver is executed, label this **phenomenological**.

**EM:** configurable material-response mapping, monotone *assumed* distance attenuation, soil/background interference, explicit model-domain limits and independent seeded noise. Standoff stress points **0.05, 0.2, 0.5, 1, 2 and 5 metres** are experimental input cases, **not guaranteed detection ranges**.

**Required downstream MG-007 evidence:** actual MATLAB R2026b execution of tests S-01…S-14, source files, complete configurations/seeds, zero-input/empty scenes, negative controls, invalid samples, model-domain/standoff sweeps and plots/tables of sensitivity. Reproducibility and sensor *software behavior* must pass; no accuracy claims without held-out evaluation.

**MG-008/MG-009 boundary:** timestamp alignment, fusion rules, thresholds, classifier training and metrics belong in later tasks, *not* these sensor physics models. The two modalities must be individually testable before fusion.

## Proof policy

MG-006 is a **documentation task**: verified published research, assumptions, unit/contract design and reproducible test acceptance, **not** execution of thermal or EM MATLAB sensor code. The mandatory actual test output can only be supplied by Rahil in MG-007. Green Node GitHub Task Gate means workflow validation, not scientific calibration or MATLAB execution.
