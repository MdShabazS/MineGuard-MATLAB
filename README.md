# MineGuard — MATLAB Simulation

**Project:** MineGuard — Autonomous Aerial Landmine Detection System  
**Implementation:** MATLAB / Simulink research simulation (NOT a validated mine detector)  
**Deadline:** 2026-11-02 | **Repository:** public | **Owners:** Shabaz (ChatGPT/specification/verification), Rahil (MATLAB/Claude Code)

The academic **problem statement and four objectives are preserved verbatim** from the Phase-1 review in [docs/PHASE1_BASELINE.md](docs/PHASE1_BASELINE.md). Only the implementation shifts from costly physical UAV hardware to reproducible simulation.

## Final academic report and demonstration (MG-018)
- [Engineering report](docs/FINAL_ENGINEERING_REPORT.md): original Phase-1 objectives, source-backed methodology, held-out **negative** results, PPO comparisons and limitations.
- [Guide presentation/demo script](docs/FINAL_DEMO_SCRIPT.md): 10–12-minute speaking script, MATLAB commands, screenshot fallbacks and viva questions.
- [MG-018 evidence and open issues](tasks/evidence/MG-018.md): review traceability and scope. **Not** operational mine detection or an authorized release tag.

## Release candidate v1.0.0-rc.1 (MG-017) — advanced MATLAB research simulation, not a mine detector
- **Release notes, install, demos, limitations:** [docs/RELEASE_NOTES_v1.0.0-rc.1.md](docs/RELEASE_NOTES_v1.0.0-rc.1.md). The tag is proposed, not yet created; it needs Shabaz's authorization.
- **Fixed-grid demo (default):** from the repo root in MATLAB R2026b: `addpath('matlab'); mineguardDemo`
- **Experimental PPO vs fixed-grid demo (needs the RL/DL toolboxes):** `addpath('matlab'); mineguardPPODemo`
- **Held-out detection result (sealed MG-014 TEST, run once):** weighted fusion **TP 0, FP 26, TN 470, FN 4**. This is a negative result; no method is useful at the locked settings. 100 % survey coverage is not detection accuracy, and the S0 demo is a display fixture, not held-out performance.
- **PPO (MG-019):** lost all 8 grid-feasible paired missions. The fixed grid stays the default; PPO is EXPERIMENTAL.

**Start here:** [Documentation index](docs/INDEX.md) → [Workflow](docs/WORKFLOW.md) → [Tasks](tasks/manifest.json). No MATLAB performance, training, detection success, or cross-platform compatibility is claimed until actual runs are recorded in GitHub.

## MineGuard Advanced V2 — separate development phase

- **Existing guide portal (same Render site):** [MineGuard Guide Observatory](https://mineguard-guide-portal.onrender.com/), with independent V2 tracking and a preserved 22/22 completed V1 archive after the portal continuation PR merges into `main`.
- **V2 architecture, scope, two-person ownership and acceptance protocol:** [v2/README.md](v2/README.md).
- **V2 task manifest and authoritative statuses:** [v2/tasks/manifest.json](v2/tasks/manifest.json) and [v2/tasks/status.json](v2/tasks/status.json). All V2 tasks initially TODO; no V2 implementation is falsely claimed as completed.
- Local exploratory MATLAB UAV Toolbox 3-D flight is verified by user-reported Mac screenshots and completion output but is not yet committed V2 implementation or independently validated flight-control simulation.

## Project oversight
- [Guide's Read-Only Progress Portal](portal/README.md): Render static site showing merged GitHub task status, blockers, owner progress, review activity and evidence.
- [Rahil MATLAB Setup and ChatGPT Support](docs/RAHIL_SETUP_SUPPORT.md): first verify installed release/toolboxes, then install only eligible missing products and connect Claude Code.
- [MATLAB environment diagnostic](matlab/mineguard_environment_check.m): prints sanitized inventory from Rahil's computer; **not run remotely**.

## Scientific scope
Simulated targets and model-generated sensor signals only. Output means a **suspected anomaly**, not verified explosives or a cleared/safe area. Synthetic results must never be represented as operational mine-detection accuracy.

## Workflow
Run `node scripts/task-gate.mjs validate` and `node scripts/task-gate.mjs ready`. Node.js 20+ is used for repo checks only. MATLAB: R2026b on Windows 11 is verified (MG-002, MG-015, MG-017). GitHub Actions checks task dependencies and portal JS tests; it does not run MATLAB. MATLAB tests (`matlab/tests/`) need licensed MATLAB on a real machine with a desktop display.

## Documentation and references
- [A-to-Z documentation index](docs/INDEX.md)
- [Original Phase-1 goals](docs/PHASE1_BASELINE.md)
- [MathWorks UAV Toolbox](https://www.mathworks.com/help/uav/)
- [MathWorks Reinforcement Learning Toolbox](https://www.mathworks.com/help/reinforcement-learning/)
- [MATLAB Agentic Toolkit](https://www.mathworks.com/products/matlab-agentic-toolkit.html)
- [Render Static Sites](https://render.com/docs/static-sites)
