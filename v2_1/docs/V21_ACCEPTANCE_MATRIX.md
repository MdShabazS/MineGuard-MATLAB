# V2.1 acceptance matrix (Revision 1.0)

Every result is NOT RUN until a real MATLAB run is recorded with its commit SHA. MATLAB tests are executed on Windows by Rahil (V21-008); the Mac does no MATLAB runtime work in V2.1.

| ID | Criterion | Task | Verification | Result |
|---|---|---|---|---|
| AC21-01 | At least 3 presets. Default = V2 training field. The other two differ in terrain seed, relief, slope, object density and lighting. | V21-002 | `testV21Scenario` presets tests; terrain `Z` differs between presets | NOT RUN |
| AC21-02 | Rectangle and convex polygon boundaries accepted. Clockwise input is reordered and reported. | V21-002 | `testV21Scenario` | NOT RUN |
| AC21-03 | Each of these is rejected with `mgv21:InvalidSurvey` and a reason: NaN, < 3 vertices, duplicate vertices, self-intersecting, non-convex, tiny area, outside extent or geofence, home outside extent. | V21-002 | `testV21Scenario` | NOT RUN |
| AC21-04 | Spacing, heading, altitude and speed out of range are rejected. A route that is too long for the timeout is rejected. A V2 planner refusal is reported, not drawn. | V21-002 | `testV21Scenario` | NOT RUN |
| AC21-05 | `pub.mission` passes `mgv2.mission.validateConfig`, and `planSurvey` is accepted for every preset default. | V21-002 | `testV21Scenario` | NOT RUN |
| AC21-06 | Terrain clearance and geofence ceiling are checked when a world is given. | V21-002 | `testV21Scenario` | NOT RUN |
| AC21-07 | NONE, MANUAL and RANDOM modes. Manual targets can be added, moved and deleted. | V21-003 | `testV21Placement` | NOT RUN |
| AC21-08 | Same seed gives the same locations. A different seed or count gives different locations. The seed and generator are recorded. | V21-003 | `testV21Placement` | NOT RUN |
| AC21-09 | Minimum spacing, edge margin, exclusion zones and object/landmark keep-out hold. Manual violations are rejected with a reason. | V21-003 | `testV21Placement` | NOT RUN |
| AC21-10 | Zero targets is valid. An impossible RANDOM request throws `mgv21:PlacementInfeasible`. | V21-003 | `testV21Placement` | NOT RUN |
| AC21-11 | `pub` and the forward features pass the firewall. `pub` does not depend on `spec`. Markers are empty after LOCK and never shown for RANDOM. | V21-003 | `testV21Placement` | NOT RUN |
| AC21-12 | NONE-signature targets do not change the forward features (counterfactual). Clutter is always present, and visible features overlap the clutter distributions. | V21-003 | `testV21Placement` | NOT RUN |
| AC21-13 | Post-run evaluation reports TP, FP, FN, precision, recall, match distances, TN = NaN and NaN for undefined ratios. It reports matched target and event indices of the same one-to-one pairs, shows the placement seed for RANDOM only, refuses to run before a terminal phase, and carries the DEMO notice. | V21-004 | `testV21Evaluation` | NOT RUN |
| AC21-14 | No V1 or V2 sealed TEST group is run. V2 detector thresholds and V2 evidence are unchanged. | all | `git diff main -- v2/` is empty for V21-001 to V21-004 | PASS (static, per PR diff) |
| AC21-15 | The UI shows SETUP markers only before LOCK, and the results panel only after a terminal phase. | V21-005/006 | Windows GUI check | NOT RUN |
| AC21-16 | The operator export has no private truth. Replay reproduces the V2.1 public configuration. | V21-007 | Windows tests | NOT RUN |
| AC21-17 | All V2.1 tests and an integrated smoke run pass on Windows R2026b, with the SHA recorded. | V21-008 | Windows run | NOT RUN |
