# MineGuard — MATLAB Simulation

**Project:** MineGuard — Autonomous Aerial Landmine Detection System  
**Implementation:** MATLAB / Simulink research simulation (NOT a validated mine detector)  
**Deadline:** 2026-11-02 | **Repository:** public | **Owners:** Shabaz (ChatGPT/specification/verification), Rahil (MATLAB/Claude Code)

The academic **problem statement and four objectives are preserved verbatim** from the Phase-1 review in [docs/PHASE1_BASELINE.md](docs/PHASE1_BASELINE.md). Only the implementation shifts from costly physical UAV hardware to reproducible simulation.

**Start here:** [Documentation index](docs/INDEX.md) → [Workflow](docs/WORKFLOW.md) → [Tasks](tasks/manifest.json). No MATLAB performance, training, detection success, or cross-platform compatibility is claimed until actual runs are recorded in GitHub.

## Project oversight
- [Guide's Read-Only Progress Portal](portal/README.md): Render static site showing merged GitHub task status, blockers, owner progress, review activity and evidence.
- [Rahil MATLAB Setup and ChatGPT Support](docs/RAHIL_SETUP_SUPPORT.md): first verify installed release/toolboxes, then install only eligible missing products and connect Claude Code.
- [MATLAB environment diagnostic](matlab/mineguard_environment_check.m): prints sanitized inventory from Rahil's computer; **not run remotely**.

## Scientific scope
Simulated targets and model-generated sensor signals only. Output means a **suspected anomaly**, not verified explosives or a cleared/safe area. Synthetic results must never be represented as operational mine-detection accuracy.

## Workflow
Run `node scripts/task-gate.mjs validate` and `node scripts/task-gate.mjs ready`. Node.js 20+ for repo checks only; MATLAB version/toolboxes pending actual `ver` report. GitHub Actions checks dependencies and portal JS tests; MATLAB tests require licensed MATLAB on a real machine.

## Documentation and references
- [A-to-Z documentation index](docs/INDEX.md)
- [Original Phase-1 goals](docs/PHASE1_BASELINE.md)
- [MathWorks UAV Toolbox](https://www.mathworks.com/help/uav/)
- [MathWorks Reinforcement Learning Toolbox](https://www.mathworks.com/help/reinforcement-learning/)
- [MATLAB Agentic Toolkit](https://www.mathworks.com/products/matlab-agentic-toolkit.html)
- [Render Static Sites](https://render.com/docs/static-sites)
