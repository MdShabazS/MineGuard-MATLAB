# Reproducible Implementation & Installation Runbook
**This runbook is a plan, not evidence of execution.** Every step with actual output must be recorded in its task evidence file.

## 0 — GitHub rules before creating MATLAB code
- Branch `main` is authority; owner tasks and dependencies in `tasks/manifest.json`.
- Create task branch only when READY; independent tasks may run concurrently. No direct-push-to-main policy.
- Include full code/tests/config in PR; require opposite member review and green CI.
- Preserve original Phase-1 statement/objectives exactly, and no operational mine-detection claims.

## 1 — Rahil checks local MATLAB (can be independent task)
1. Start MATLAB Desktop Windows and ensure no licence prompt blocks running simple code.
2. Run `ver`, then `matlab.addons.installedAddons` (these show products/add-ons, not all licence permissions).
3. Run `report = mineguard_environment_check` from the checked-out `matlab/` folder.
4. Verify syntax and actual function availability with `which uavScenario`, `which rlPPOAgent`, `which uifigure`.
5. If functions missing, check entitlement in the MathWorks student/college account; install **only required licensed products** through the official installer or MATLAB Add-Ons.
6. Save sanitized evidence: exact release, product inventory, simple MATLAB computation PASS/FAIL and first error. Do not share account details, licence ID or full machine path.

## 2 — Official Claude Code integration
Latest official options, subject to installed MATLAB version:
- CLI installer repository: https://github.com/matlab/agentic-toolkit-installer (supports Windows x64, Mac and Linux; both MATLAB and Simulink toolkit setup documented for R2023a+, MATLAB-only for R2021a+).
- MATLAB installer: https://github.com/matlab/matlab-agentic-toolkit; download `agenticToolkitInstaller.mltbx` from official releases, open MATLAB Add-On, run:
```matlab
setupAgenticToolkit("install")
```
- For an existing MATLAB session intended for agent tools:
```matlab
shareMATLABSession()
```
- Verify in Claude Code that the MATLAB MCP tools are available and that calling MATLAB with `2+3` really returns 5. Use `claude mcp list` if not connected.
- Optional data collection control documented by MathWorks: `setupAgenticToolkit("configure", DisableTelemetry=true)`; review terms and ensure it works in the installed toolkit release.
- Install only relevant skills (MATLAB core, app building, UAV, reinforcement learning) rather than every available group.
- Security: review executed commands, file writes, network requests and service installations before approving. No automatic access to academic accounts or secret data without permission.

**Caution:** Multiple official methods and versions exist. Use the **actual current official release instructions**, not a stale command copied unverified.

## 3 — Recommended repo implementation layout (not yet created)
```text
matlab/
  +mineguard/            % namespaced functions
    +scenario/            % seeded scene and truth (evaluation-only truth)
    +nav/                 % grid and optional PPO survey policy
    +sensing/             % thermal / EM forward model
    +detection/           % scores, classifiers, calibrated fusion
    +mapping/             % virtual geotags, uncertainty
    +reports/             % exports and metrics
  apps/                  % App Designer application
  models/                % Simulink .slx if available
  scripts/               % one-command demo runner
tests/matlab/            % matlab.unittest
experiments/config/      % seed, model settings
results/approved/        % small reviewed reproducible outputs
```

## 4 — Automated MATLAB tests (example call, adapt to actual installed release)
```matlab
results = runtests("tests/matlab");
disp(table(results));
assert(all([results.Passed]), "One or more MATLAB tests failed.");
```
Rahil must actually run the test after writing it. A blank tests directory is NOT a successful test run.

## 5 — Experiment run evidence
Every run must record: task ID, Git SHA, MATLAB version and toolboxes, command, seed, scenario config, elapsed time, inputs/source, observed values and failures, warning messages and exported file paths. Save to reviewed PR under `tasks/evidence`; no screenshots without logs.

## 6 — Quick-start demo command (to be implemented)
Choose and document one stable entrypoint `mineguard_demo` or `run_mineguard`, which prints configured scene, runs baseline, renders dashboard, exports evidence. Until actually committed and tested, **DO NOT** suggest it exists.

## 7 — Troubleshooting escalation
- Licence/incompatibility → installed product inventory and official version docs, not guessing.
- MATLAB MCP fails → official toolkit troubleshooting and `claude mcp list` output (without secrets).
- Sensor outputs physically unreasonable → unit/standoff review and negative controls before classifier tuning.
- RL unstable → verify step/reset observation/action shapes, terminal/reward and initial baseline; simplify environment.
- App freezes → separate simulation engine from UI refresh and use bounded update rate.
- Error reports must include first failing command, full relevant error ID, release, input seed and expected/observed outputs.

## 8 — Two-day schedule discipline
Deadline Nov 2 is a **target**, not proof of capability. Prioritize working deterministic integration before advanced PPO complexity; name unverified features explicitly. Do not suppress limitations just to meet review expectations.
