# CLAUDE.md — MineGuard-MATLAB
- Roles: Rahil (MATLAB dev/test, Claude Code) and Shabaz (docs/spec/review, ChatGPT). Only GitHub `main` counts as authoritative.
- Before working: `git fetch`, then `node scripts/task-gate.mjs validate`, `ready`, and `check MG-XXX`. Work only on READY tasks.
- Branch `task/MG-XXX-short-name`. Evidence goes in `tasks/evidence/MG-XXX.md` (template in docs/TEST_AND_EVIDENCE.md). Open a PR for Shabaz to review. Never merge or approve without a human.
- Mark progress only with `task-gate.mjs start` and `complete`. A PR must not change both tasks/manifest.json and a task's status.
- Run real MATLAB through MCP (R2026b). Never fabricate tests, training results, accuracy or detection capability. All outputs are "suspected anomaly", from simulation only.
- Toolboxes: UAV/Navigation installed. Simulink/RL/DL/Stateflow installed and smoke-tested (MG-002). Sensor Fusion & Tracking is NOT licensed, so use core-MATLAB fusion.
- Never commit licence numbers, tokens, or personal data. Read only the docs the task needs (index: docs/INDEX.md).
- Keep replies short: Task / Status / Verified / GitHub / Next.
