# V2.1 acceptance matrix (Revision 1.0)

Results recorded 2026-11-04 from GitHub evidence: `v2_1/evidence/V21-008/regression_79c4537.txt` (389/389) and `v2_1/evidence/V21-008/v21_demo_check_74fbe63.txt` (51/51). Claude Code ran every test on Rahil's Windows laptop (MATLAB R2026b); **no human watched**. Mac: **NOT RUN**. `main` at `8188804` has the same product code as `79c4537`.

| ID | Criterion | Task | Verification | Result |
|---|---|---|---|---|
| AC21-01 | At least 3 presets. Default = V2 training field. The other two differ in terrain seed, relief, slope, object density and lighting. | V21-002 | `testV21Scenario` presets tests; terrain `Z` differs between presets | PASS (Windows `79c4537`, 389/389) |
| AC21-02 | Rectangle and convex polygon boundaries accepted. Clockwise input is reordered and reported. | V21-002 | `testV21Scenario` | PASS (Windows `79c4537`, 389/389) |
| AC21-03 | Each of these is rejected with `mgv21:InvalidSurvey` and a reason: NaN, < 3 vertices, duplicate vertices, self-intersecting, non-convex, tiny area, outside extent or geofence, home outside extent. | V21-002 | `testV21Scenario` | PASS (Windows `79c4537`, 389/389) |
| AC21-04 | Spacing, heading, altitude and speed out of range are rejected. A route that is too long for the timeout is rejected. A V2 planner refusal is reported, not drawn. | V21-002 | `testV21Scenario` | PASS (Windows `79c4537`, 389/389) |
| AC21-05 | `pub.mission` passes `mgv2.mission.validateConfig`, and `planSurvey` is accepted for every preset default. | V21-002 | `testV21Scenario` | PASS (Windows `79c4537`, 389/389) |
| AC21-06 | Terrain clearance and geofence ceiling are checked when a world is given. | V21-002 | `testV21Scenario` | PASS (Windows `79c4537`, 389/389) |
| AC21-07 | NONE, MANUAL and RANDOM modes. Manual targets can be added, moved and deleted. | V21-003 | `testV21Placement` | PASS (Windows `79c4537`, 389/389) |
| AC21-08 | Same seed gives the same locations. A different seed or count gives different locations. The seed and generator are recorded. | V21-003 | `testV21Placement` | PASS (Windows `79c4537`, 389/389) |
| AC21-09 | Minimum spacing, edge margin, exclusion zones and object/landmark keep-out hold. Manual violations are rejected with a reason. | V21-003 | `testV21Placement` | PASS (Windows `79c4537`, 389/389) |
| AC21-10 | Zero targets is valid. An impossible RANDOM request throws `mgv21:PlacementInfeasible`. | V21-003 | `testV21Placement` | PASS (Windows `79c4537`, 389/389) |
| AC21-11 | `pub` and the forward features pass the firewall. `pub` does not depend on `spec`. Markers are empty after LOCK and never shown for RANDOM. | V21-003 | `testV21Placement` | PASS (Windows `79c4537`, 389/389) |
| AC21-12 | NONE-signature targets do not change the forward features (counterfactual). Clutter is always present, and visible features overlap the clutter distributions. | V21-003 | `testV21Placement` | PASS (Windows `79c4537`, 389/389) |
| AC21-13 | Post-run evaluation reports TP, FP, FN, precision, recall, match distances, TN = NaN and NaN for undefined ratios. It reports matched target and event indices of the same one-to-one pairs, shows the placement seed for RANDOM only, refuses to run before a terminal phase, and carries the DEMO notice. | V21-004 | `testV21Evaluation` | PASS (Windows `79c4537`, 389/389) |
| AC21-14 | No V1 or V2 sealed TEST group is run. V2 detector thresholds and V2 evidence are unchanged. | all | `git diff main -- v2/` is empty for V21-001 to V21-004 | PASS (static on `main` `8188804`: `git diff 98e0c9e` over `v2/+detect`, `v2/+eval`, `v2/data`, `v2/evidence` is empty; V2 305/305) |
| AC21-15 | The UI shows SETUP markers only before LOCK, and the results panel only after a terminal phase. | V21-005/006 | Windows GUI check | PASS (Windows, automated: SetupUI 12/12, RunController 9/9, EvaluationView; app check 51/51 at `74fbe63`; no human) |
| AC21-16 | The operator export has no private truth. Replay reproduces the V2.1 public configuration. | V21-007 | Windows tests | PASS (Windows, automated: app check export/verify/firewall/replay, 4 runs at `74fbe63`); see limitation L1 |
| AC21-17 | All V2.1 tests and an integrated smoke run pass on Windows R2026b, with the SHA recorded. | V21-008 | Windows run | PASS (Windows: 389/389 at `79c4537`; app check 51/51 at `74fbe63`, not rerun at `79c4537`; no human) |

## Known limitations (not acceptance failures)

- **L1. Unsalted commitment.** A V2.1 export manifest stores an **unsalted** SHA-256 of the private surface features (`private_forward_model.features_sha256`). The hash does not contain positions. But for a RANDOM layout with a guessable seed (defaults: `seed` 1, `clutter_seed` 7007), someone with the code can recompute candidate layouts and match the hash. The operator package can therefore reveal a layout indirectly. The impact is limited, because the evaluation view reveals targets after the run anyway. **Fix (open):** a random salt stored only in the private evaluation file.
- **L2. Detection.** The frozen V2 detector found **0 of 12** placed synthetic targets in four full Windows flights; VALIDATION was 0 of 4 in V2. The evaluation is an INTERACTIVE SYNTHETIC DEMO, not accuracy. There is no buried-mine detection or land-clearance claim.
- **L3. Mac and witnesses.** Mac runtime is NOT RUN. No human witnessed a V2.1 run.
- **L4. Engineering limits.**
  - Survey boundaries must be convex.
  - Presets cannot change soil colours.
  - The flight-time check is an estimate.
  - Line spacing is not checked against the sensor swath.
