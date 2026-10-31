# Rahil Setup and Troubleshooting — ChatGPT Support Protocol

**Owner:** Rahil for MG-002; **support:** Shabaz/ChatGPT for research and stepwise troubleshooting. Status is PENDING until tests are executed on Rahil's Windows laptop.

## Step 0 — Preconditions
Confirm MATLAB Desktop opens and student account is activated. Never paste passwords, activation keys, licence IDs, private file paths or other secrets into the public repository.

## Step 1 — Inventory before downloading anything
Open MATLAB → Command Window:
```matlab
ver
```
Then, after the repo has been cloned:
```matlab
addpath(fullfile(pwd,'matlab'));
report = mineguard_environment_check;
```
Save a **sanitized summary** with release, toolbox names/versions, missing functions and smoke test into `tasks/evidence/MG-002.md`; don't store personal identifiers. The script only checks installed products and runs a trivial MATLAB computation. **It does not prove toolbox licence activation or overall simulation readiness.**

## Step 2 — Required vs optional MathWorks products
- MATLAB: REQUIRED for any work. App Designer is part of MATLAB.
- Simulink: REQUIRED for Simulink model execution; baseline can use .m scripts if unavailable.
- UAV Toolbox: HIGH priority for prebuilt UAV scenarios; use a simple MATLAB-based grid model if unavailable.
- Reinforcement Learning Toolbox: REQUIRED only for PPO training; fallback is fixed grid navigation clearly labelled baseline.
- Sensor Fusion and Tracking Toolbox: HELPFUL, but transparent mathematical late fusion can be implemented in core MATLAB.
- Deep Learning Toolbox: Needed if proposed trained network or RL release requires it; verify actual release/dependencies.
- Stateflow: OPTIONAL; can use MATLAB mission state logic instead.
Never install toolboxes blindly. Use MATLAB → Home → Add-Ons / installation management or MathWorks installer **only if student licence covers the selected toolbox and release**. This project does not require pirated/cracked copies.

## Step 3 — Set up MATLAB Agentic Toolkit for Claude Code
Official GitHub instructions: https://github.com/matlab/matlab-agentic-toolkit and https://github.com/matlab/matlab-agentic-toolkit/blob/main/Configuration_and_Troubleshooting.md

1. Install/confirm Claude Code and Git in PowerShell: `claude --version`, `git --version`.
2. From official MathWorks GitHub releases, download **agenticToolkitInstaller.mltbx**, open it in MATLAB, and run `setupAgenticToolkit("install")`. Follow prompts to select Claude Code and relevant MATLAB/Simulink skills. The toolkit requires MATLAB R2021a or later.
3. Restart Claude Code so MCP registration is loaded. Ask Claude to list connected tools and execute a harmless MATLAB command, such as `2+3` through the MATLAB MCP connection.
4. If the installer can't find MATLAB or MCP download fails, consult official troubleshooting and reconfigure; do not fabricate connectivity.
5. Record actual result/errors in MG-002 evidence. Never include credentials.

## Step 4 — Claude Code task workflow
After MG-000 merge and task gate READY:
```powershell
git clone https://github.com/MdShabazS/MineGuard-MATLAB.git
cd MineGuard-MATLAB
node scripts/task-gate.mjs validate
node scripts/task-gate.mjs ready
```
Claude Code must research release-specific documentation, implement only a READY task, execute tests in MATLAB and open a GitHub PR. ChatGPT can review copied non-sensitive error messages or screenshots to give one debugging step at a time. The laptop holds a **temporary working checkout**; only approved GitHub commits are authoritative.

## Support triage
- MATLAB fails to open: check actual install and account activation before toolboxes.
- Toolbox absent: inspect `ver`; use Add-Ons/MathWorks installer; check student licence entitlements.
- Toolbox listed but function missing: check release-specific function docs/which path and installed files.
- Claude Code MCP unavailable: check `claude mcp list`, toolkit setup and user configuration; re-run documented setup steps.
- MATLAB code errors: preserve first error identifier, stack trace, release, command and smallest reproducible case.
- GPU/RL training slow: scale scenario/training episodes; do not invent a successful checkpoint.

## Handoff protocol
Rahil supplies the current task ID, exact error, command, MATLAB release and short sanitized log. Shabaz/ChatGPT returns the next reproducible check or patch prompt, verifies source references and updates the task only after actual evidence.
