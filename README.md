# MineGuard — MATLAB Simulation

**Project:** MineGuard — Autonomous Aerial Landmine Detection System  
**Implementation:** MATLAB / Simulink simulation research prototype (NOT a validated mine detector)  
**Deadline:** 2026-11-02 | **Repository:** public | **Owners:** Shabaz (specification/verification), Rahil (MATLAB/Claude Code)

The academic **problem statement and four objectives are preserved verbatim** from the Phase-1 review in [docs/PHASE1_BASELINE.md](docs/PHASE1_BASELINE.md). Only the implementation shifts from costly physical UAV hardware to reproducible simulation.

**Start here:** [Documentation index](docs/INDEX.md) → [Workflow](docs/WORKFLOW.md) → [Tasks](tasks/manifest.json). No MATLAB performance, training, detection success, or cross-platform compatibility is claimed until actual runs are recorded in GitHub. 

**Safety and scientific scope:** simulated targets and model-generated sensor signals only. Output means a **suspected anomaly**, not verified explosives or a cleared/safe area. Synthetic results must never be represented as operational mine-detection accuracy.

**Task gate:** `node scripts/task-gate.mjs validate` and `node scripts/task-gate.mjs ready`. Node.js 20+ for task checks only; MATLAB version/toolboxes pending an actual `ver` report. GitHub Actions checks dependency integrity; MATLAB tests require a licensed MATLAB runner.

**External documentation:** [MathWorks UAV Toolbox](https://www.mathworks.com/help/uav/), [Reinforcement Learning Toolbox](https://www.mathworks.com/help/reinforcement-learning/), [MATLAB Agentic Toolkit](https://www.mathworks.com/products/matlab-agentic-toolkit.html).
