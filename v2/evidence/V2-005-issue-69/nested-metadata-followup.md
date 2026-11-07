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

The review of #96 found a mismatch: `validateSensorConfig` accepted any `units`, which `validateSample` then refused. See below.

## Remaining limit

Free-text string fields such as `data_ref`, `run_id`, `scenario_id`, `frame_id`, `lighting_mode` and `implementation` are checked for type here, not content, so a string could still carry arbitrary text. `data_ref` will need new values when V2-008 writes run packages, so these were not guessed at. The zero-pixel `stats_available` mismatch from #92 also stands.

## Not run

Windows. V2-006 studies, TRAIN, VAL or TEST.

## Review correction: units checked at configuration time

**Tested SHA: `9ceabbe59eb5d172a27522b8726a122029d16c12`** (clean tree). The results above at `0b303d50` stay as recorded for that commit.

`validateSensorConfig` now refuses `units` that differ from `contract().units` with `mgv2:InvalidSensorConfig`, so a bad config fails before any sample exists. The rule in `validateSample` was not relaxed. Field order carries no meaning. Forbidden names and objects inside `units` still raise `mgv2:TruthLeak`.

| Suite | Passed | Failed | Incomplete |
|---|---|---|---|
| `testV2005NestedMetadataContract` (22 + 12 new) | 34 | 0 | 0 |
| `testV2005QualityContract` | 35 | 0 | 0 |
| V2-002 | 22 | 0 | 0 |
| V2-003 | 22 | 0 | 0 |
| V2-005 | 28 | 0 | 0 |
| V2-006 | 28 | 0 | 0 |
| **Total** | **169** | **0** | **0** |

New tests per sensor: default config equals the contract and keeps its fingerprint; wrong, missing, extra, nested, char, numeric and non-scalar units are refused; `SensorSystem` refuses a bad config; a valid config, including dropout, yields accepted samples.

**Unchanged:** the producers, `mg-v2-sensors/1.0`, the full-mission digest `37f7fae4104d849c3b3a7d4eac17c03f185fb1bf7643a74be912a9ad94001d21`, and detector fingerprint `fnv1a64:d6d364f988f04bb4`. The default config's channel hashes are unchanged, as the new test checks.

**A discarded run:** a first run at this SHA reported 168/169 with `d20` failing. My test script's path filter had removed MATLAB's own folders, so `readtable` could not load. It was a harness fault, shown by the error ID `MATLAB:class:InvalidSuperClass`. The path was repaired and all suites rerun; only the clean run is reported.

**Not rerun with this commit:** the #91 merge (bridge 37/37 and GUI 60/60 are from `0b303d50`). Windows was not run.
