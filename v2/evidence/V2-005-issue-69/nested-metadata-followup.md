# Follow-up to issue #69: other nested sample metadata

Correction record. V2-005 stays DONE. SIMULATION ONLY. No study ran, and no detector, threshold or frozen file changed.

**Tested SHA: `0b303d50df1bbaa1459e3610059e07dce6609bbe`** (clean tree), stacked on #92 at `0c2f7fd`. Host: macOS 27.0.1, arm64, MATLAB 26.2.0.3433840 (R2026b Update 1). Later commits add evidence only.

## Defect

After #92, `quality` was exact, but `sample.units.mine_location`, `sample.noise_parameters.mine_location` and a struct placed in `sample.distortion` were still accepted. No producer emits these, and no leak was observed.

## Fix

An inventory of every emitted sample found only `quality`, `units` and `noise_parameters` legitimately nested.

| Field | Rule |
|---|---|
| `units` | Exact fields and exact text per sensor |
| `noise_parameters` (RGB) | Exactly `read_noise_dn`, `shot_gain_dn`; finite non-negative doubles |
| Every other field | Real numeric, logical or string only. Struct, cell, table, char, categorical, datetime, function handle and complex values are refused |

The denylist and object check still run first, so forbidden names and handles still raise `mgv2:TruthLeak`.

## Results at the tested SHA

| Suite | Passed | Failed | Incomplete |
|---|---|---|---|
| New `testV2005NestedMetadataContract` | 22 | 0 | 0 |
| `testV2005QualityContract` | 35 | 0 | 0 |
| V2-002 | 22 | 0 | 0 |
| V2-003 | 22 | 0 | 0 |
| V2-005 | 28 | 0 | 0 |
| V2-006 | 28 | 0 | 0 |
| **Total** | **157** | **0** | **0** |

`checkcode`: 0 messages on the 3 changed files.

Disposable merge with #91 `0f32e71` (`c757bb3`, never pushed): bridge 37/37, UI GUI 60/60, and `V2006AnomalySource.onSample` refuses all three injections with `mgv2:InvalidSample`.

## Compatibility

`mg-v2-sensors/1.0` stays, and no producer changed. A full mission gives the same 2799 ticks, 3080 samples and log digest on `main` and here: `37f7fae4104d849c3b3a7d4eac17c03f185fb1bf7643a74be912a9ad94001d21`.

**One behaviour to review:** `validateSensorConfig` does not restrict `units` text, but `validateSample` now does. A custom `SensorConfig` with different units text now fails when it samples. Nothing in the repository does this, and all suites above pass. Unit text describes the contract's fixed units, so that seems right, but it is a decision for review.

## Remaining limit

Free-text string fields such as `data_ref`, `run_id`, `scenario_id`, `frame_id`, `lighting_mode` and `implementation` are checked for type here, not content, so a string could still carry arbitrary text. `data_ref` will need new values when V2-008 writes run packages, so these were not guessed at. The zero-pixel `stats_available` mismatch from #92 also stands.

## Not run

Windows. V2-006 studies, TRAIN, VAL or TEST.
