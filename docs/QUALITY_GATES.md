# Engineering Quality Gates and Definition of Done
**Critical:** Academic honesty is more important than decorative features or completion percentages.

## Gate G0 — Documentation baseline
- Original title/problem statement/four objectives verbatim against original review.
- All design assumptions, limits, data contracts, sensor-specific feasibility, sources, risk register and owner approvals committed to GitHub.
- PR reviewed by the other team member; GitHub CI green; no unseen local-only changes.
- Unless requirements and environment are verified, implementation tasks remain blocked.

## Gate G1 — Local MATLAB readiness
- `ver` with release + toolboxes, active licence access, actual calculation smoke test.
- Claude Code ↔ official MathWorks MCP running real MATLAB command verified, with sanitized output.
- Optional Simulink/UAV/RL toolbox functions tested individually. Missing tools documented.
- Not passed until signed off with a real `MG-002` evidence record.

## Gate G2 — Deterministic scenario and grid route
- Executed on real MATLAB; schema validation/seed reproducibility, bounds and mission completion tests.
- Actual sample output/artifacts and exact command/version/commit recorded.
- Navigation does not use hidden target locations.

## Gate G3 — Sensor forward models
- Units, physically plausible standoff constraints, soil/time/noise parameters and negative controls.
- Disclose when signal is below noise floor; no invented mine detection.
- Code/test and limitations in GitHub evidence.

## Gate G4 — Fusion and experiment rigor
- Train/validation/test separated by *scenario/target*, no leakage, honest confusion matrix.
- Thermal-only and EM-only comparisons on same cases.
- Test seeds, metric formula, thresholds and variants included.

## Gate G5 — PPO
- Executed episodes, reward definition, train/validation/test seed sets and trained checkpoint.
- Quantitative comparison with fixed grid on held-out scenarios; include failures.
- No claim 'intelligent RL trained' for a manually programmed path.

## Gate G6 — Dashboard
- App Designer (or documented fallback) displays virtual mission, honest status, actual detection events and uncertainty.
- Export includes versions/seed/SHA; missing output not displayed as zero error.
- UI reviewed by a tester with real playback result.

## Gate G7 — Repo/Guide portal
- JS test/CI output recorded; real browser manual smoke test of work journal, filters, mobile readability.
- Render deployment verified at actual external HTTPS URL only after it exists.
- Guide can click evidence and see latest merged `main` status. No embedded API token or student identifiers.

## Gate G8 — Academic presentation
- Objective traceability matrix with pass/incomplete statuses, real screenshots/logs, measurement limits.
- Original objectives not rewritten to evade buried-mine feasibility.
- Presentation says 'simulated' and never claims safe cleared land.

## Definition of evidence-backed task completion
| State | Required |
|---|---|
| TODO | No work declared started |
| IN_PROGRESS | Correct owner, dependency satisfied, work branch, relevant PR/pending evidence |
| BLOCKED | Derived from unmet dependency or documented external blocker; never silently progressed |
| DONE | Merged `main`, actual files and proof, correct owner/reviewer, applicable CI + real MATLAB evidence for BUILD |

## CI limits
GitHub Actions Node.js validation checks DAG and portal JavaScript. It does not run MATLAB unless a specific licensed MATLAB execution job is configured and actually executes. Never equate CI PASS with sensing performance.
