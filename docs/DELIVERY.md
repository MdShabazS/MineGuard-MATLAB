# 2026-11-02 Final Demonstration and Release Checklist

**Target:** complete MATLAB demonstration matching original objectives *at the simulation level*; not a certified hardware result.

## Gate A — integrity
- Original title, five problem-statement bullets and four objectives reproduced verbatim.
- Repo public and no secret data; source/documentation/seeded scenario scripts/accepted evidence on main.
- Every declared DONE task has approved evidence; all remaining work explicitly TODO/IN_PROGRESS/BLOCKED.

## Gate B — MATLAB technical
- Real run on Rahil's licensed MATLAB environment recorded with release/toolboxes.
- Deterministic grid navigation with true code logs, 3D visualization, synthetic targets, thermal/EM sensor outputs and mapping.
- Hybrid detection baseline/fusion with synthetic held-out metrics and clear statistical limitations.
- App Designer dashboard (if actually functional); screenshot alone is insufficient.
- PPO is **trained and benchmarked** only if genuine logs/checkpoints exist; otherwise present as incomplete experiment, never simulated as completed AI learning.
- Cross-platform test on Shabaz Mac only if actual MATLAB execution succeeds; otherwise record NOT RUN.

**MG-014 test and demo prelock:** [MG014_LOCKED_TEST_MATRIX_AND_DEMO.md](MG014_LOCKED_TEST_MATRIX_AND_DEMO.md) and [30-family scenario manifest](../experiments/locked/mg014_scenario_manifest.json). The plan establishes test IDs, specific held-out groups, negative controls, metrics and fallbacks; only real subsequent MATLAB runs prove an executable gate. Freeze sensor/model/threshold hashes before testing. MG-015 remains a core grid pipeline and must not be blocked by optional PPO.

## Gate C — evaluation
- Replicable seed + version + configs, held-out scenario results, failures and limitations.
- No real-world mine safety/clearance assertion.
- Export to PDF/report via standard institutional procedures; no invented graphs or citations.

## Demo narration
State: (1) unchanged humanitarian problem/objectives, (2) cost-driven transition to MATLAB, (3) simulated architecture, (4) objective-by-objective evidence, (5) experimental quantitative results, (6) physical feasibility limitations and future validation.

## Fallback if incomplete
Demonstrate truthful validated submodules with named remaining gaps. Quality beats unsupported claims even under deadline.

## Guide portal and optional PPO release gates (added after audit)
- MG-020 Render guide site is a distinct deliverable with a real HTTPS URL and evidence, separate from MATLAB simulation.
- MG-021 requires live browser/mobile verification; static JS tests alone are insufficient.
- MG-015 core integration must be independently demonstrable even when optional RL agent is untrained or unavailable.
- MG-019 PPO integration is an optional experimental enhancement; show only executed, auditable benchmark results.
- The source Phase-1 review deck must be compared with `PHASE1_BASELINE.md` and provenance recorded before making a formal academic claim of word-for-word verification.
