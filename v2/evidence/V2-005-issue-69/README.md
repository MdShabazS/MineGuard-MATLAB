# Issue #69: exact nested `quality` schema for mg-v2-sensors/1.0

Correction record. V2-005 stays DONE and its status is unchanged. SIMULATION ONLY. No study ran, and no detector, threshold or frozen file changed.

**Tested SHA: `644bf2a59e989abd64797c8ba6ee05b1c7db0a72`** (clean tree, based on `main` `0b33357`). Host: macOS 27.0.1, arm64, MATLAB 26.2.0.3433840 (R2026b Update 1), through the MATLAB MCP Server. Later commits add evidence only.

## Defect

`validateSample` checked top-level fields exactly, but only checked `quality` against a list of forbidden names. Reproduced on `main`: `sample.quality.mine_location = [1 2]` was accepted by `validateSample`, `AnomalyDetector.ingest` (`ACCEPTED`) and `MissionMap.addSample`. This was an input-contract gap. **No leak in real output was observed**, because the producers never emit such a field.

## Fix

`contract.m` lists the exact fields per sensor, and `validateSample.m` enforces them. No producer changed.

| Sensor | Always | With stats | Rules |
|---|---|---|---|
| RGB_NADIR | `valid_pixel_fraction`, `object_pixel_fraction`, `stats_available` | `saturated_fraction`, `mean_dn` | Fractions in [0, 1]; `mean_dn` in [0, 255] DN; valid fraction matches the mask; a valid sample has stats |
| THERMAL_LWIR | same three | `min_K`, `max_K`, `mean_K` | Same fractions; 0 < min <= mean <= max [K] |
| LIDAR_TERRAIN | `valid_ray_fraction`, `dropout_rays`, `out_of_range_rays`, `no_intersection_rays`, `agl_from_returns_available`, `stats_available` | none | Counts and fraction match `ray_invalid_code` and `valid_ray_mask`; AGL flag matches `altitude_agl_m` |
| VIRTUAL_GNSS_INS | `horizontal_sigma_m`, `vertical_sigma_m`, `sigma_kind`, `stats_available` | none | Finite non-negative metres; `sigma_kind` exactly `"MODEL_ASSUMPTION"`; stats flag matches `valid` |

Numbers must be real doubles, flags logical scalars. The denylist and recursive object check still run first, so `TargetTruth` still raises `mgv2:TruthLeak`. An unknown field raises `mgv2:InvalidSample` whatever its name.

**Detector and map:** both call `validateSample`, so they refuse it without any change to them. **Bridge:** in a disposable merge with #91 head `0f32e71`, `V2006AnomalySource.onSample` refuses the injected sample with `mgv2:InvalidSample`, and the bridge files never read `quality`. **UI:** reads only `quality.horizontal_sigma_m` from samples that `SensorSystem` already validated.

## Results at the tested SHA

| Suite | Passed | Failed | Incomplete |
|---|---|---|---|
| New `testV2005QualityContract` | 35 | 0 | 0 |
| V2-002 | 22 | 0 | 0 |
| V2-003 | 22 | 0 | 0 |
| V2-005 | 28 | 0 | 0 |
| V2-006 | 28 | 0 | 0 |
| **Total** | **135** | **0** | **0** |

The prior 100 are the existing suites; none was edited. `checkcode`: 0 messages on the 3 changed files. Disposable merge with #91: bridge 37/37. Nothing else was run in that merge.

The new suite covers: every sensor's produced fields; `quality.mine_location` at validator, detector and map; unknown names, including near-misses; forbidden names; nested structs, cells and object handles, also inside a listed field; wrong types, shapes, ranges, NaN, Inf and complex; forged values disagreeing with the sample; dropout and zero-pixel samples; MAT round trip; normal detector and map ingestion; repeat determinism.

## Compatibility

**Preserved: no schema or version change.** `mg-v2-sensors/1.0` stays. The same full mission on `main` and at the tested SHA gives 2799 ticks, 3080 samples and the same log digest, `37f7fae4104d849c3b3a7d4eac17c03f185fb1bf7643a74be912a9ad94001d21`. That digest covers measurement checksums; `quality` is outside it, and is unchanged because producers are unchanged and its repeat is tested. The only new behaviour is refusal of samples no producer emits.

The contract document is not edited. A sample built by hand outside the producers now has to match the schema. JSON-decoded quality does not stand in for samples: `sigma_kind` decodes to char and is refused, and decoded samples already failed the existing uint64 checks.

## Findings not fixed here

1. **The same hole exists in other nested metadata.** `sample.units.mine_location`, `sample.noise_parameters.mine_location` and a struct in `sample.distortion` are all still accepted on this SHA. No producer emits them, and no leak was observed. This is outside #69's `quality` scope and needs its own change.
2. **A spec mismatch, preserved deliberately.** A camera frame with no valid pixels reports `stats_available = true` with NaN or empty stats, while V2-004 §2.2 describes finite values with unavailable flags. Changing it means changing a producer, so the validator accepts exactly that case and refuses any number claimed from no pixels.

## Not run

Windows. Full UI suite with this change. No study, TRAIN, VAL or TEST.
