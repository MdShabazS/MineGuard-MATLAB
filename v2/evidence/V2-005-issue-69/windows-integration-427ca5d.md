# Issue #69 (PRs #92 and #96): Windows regression on the integrated tree

Tested tree: `427ca5d`, which is `main` at `ebe7084` (V2-007 DONE, V2-008 started) merged with `fix/V2-005-nested-metadata-schema` (#96, which contains #92). The tree of this branch after merging #96 and `main` is identical to `427ca5d` (`git diff 427ca5d` is empty).
Tester: Claude Code (Opus 5.5) running real MATLAB on Rahil's Windows laptop, at Rahil's direction. No human watched the run.
Environment: Windows 11 Pro (build 26300), MATLAB R2026b Update 1 (26.2.0.3433840), desktop session; UAV and Navigation Toolboxes 26.2.
Command: `r_tree` calling `runtests` on each suite in a fresh desktop MATLAB, clean checkout (`git status --short` empty).
Observed output: `windows_regression_427ca5d.txt` beside this file.

| Suite | Run | Pass | Fail | Incomplete |
|---|---:|---:|---:|---:|
| testV2002MissionEngine | 22 | 22 | 0 | 0 |
| testV2003Scene | 22 | 22 | 0 | 0 |
| testV2005Sensors | 28 | 28 | 0 | 0 |
| testV2005QualityContract | 35 | 35 | 0 | 0 |
| testV2005NestedMetadataContract | 34 | 34 | 0 | 0 |
| testV2006Detection | 28 | 28 | 0 | 0 |
| testV2007Bridge | 42 | 42 | 0 | 0 |
| testV2007MissionControlUI | 73 | 73 | 0 | 0 |
| **Total** | **284** | **284** | **0** | **0** |

`checkcode` on `+ui` and `+bridge`: no messages listed.

This closes the "Windows was not run" gap in `nested-metadata-followup.md` and covers the V2-007 code now on `main`, which every sample passes through (`SensorSystem` validates each sample). It is the schema base for V2-008. The review of the `9ceabbe` units fix is this run plus a reading of its diff: `validateSensorConfig` now refuses units that `validateSample` would refuse.

A first run on this tree was discarded: other files were edited while it ran. Only this clean run is reported.

SIMULATION ONLY. No detection claim.
