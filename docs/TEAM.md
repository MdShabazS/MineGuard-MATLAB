# MineGuard team and repository (current)

**Effective:** 2026-11-15 · **Decided by:** Shabaz (project lead) · This file is the single source for who works on MineGuard and how.

## 1. Team

MineGuard is now a MATLAB-only project. All work is done by three Claude Code sessions. Each session is operated by its own team member:

| # | Session | Operated by | Role |
|---|---|---|---|
| 1 | **Shabaz's Claude** (Mac, this repository's lead session) | Shabaz | **Project lead and decision maker.** Plans phases, defines and splits tasks, sets acceptance criteria, reviews all work, decides on merges and owns the documentation. |
| 2 | **Rahil's Claude** (Windows) | Rahil | Work assigned by Shabaz's Claude. Rahil's Windows laptop is currently the primary MATLAB execution and verification machine. |
| 3 | **Danish's Claude** | Danish | Work assigned by Shabaz's Claude. |

The detailed work split for the next phase will be defined later by Shabaz's Claude and recorded here.

**ChatGPT and Codex are no longer used** on this project. Earlier records (task evidence, audits, decision-log entries, frozen specifications) keep their original wording and authorship and are not rewritten.

## 2. Working rules

1. **GitHub `main` is authoritative.** A local copy, chat message or AI summary is not a result until it is merged.
2. **Humans own tasks.** Task owners are Shabaz, Rahil or Danish. A Claude session is the tool that does the work, not the evidence that it was done.
3. **Say who did what.** Every PR, comment and evidence file says which session wrote or ran it, for example "Claude Code in Rahil's Windows session". Nobody approves as someone else or records a review or witness that did not happen.
4. **Merges:**
   - Required checks (`task-gate`) must pass.
   - Shabaz's Claude decides on merges, under Shabaz's instructions.
   - A merge decision can be delegated in writing for a defined scope, as was done for V2-007 to V2-010 (`v2/docs/V2_GOVERNANCE_DELEGATION.md`) and V2.1.
5. **Honest results:**
   - Never fabricate a test, training result, accuracy figure or detection capability.
   - A test that was not executed is NOT RUN.
   - All outputs are simulated "suspected anomalies". This is not a validated landmine detector.
6. **Sealed data stays sealed:**
   - Do not rerun the V1 MG-014 sealed TEST or the V2 sealed TEST groups.
   - Do not change frozen detector thresholds.
7. **Nothing secret in the repository:** never commit licence numbers, tokens, credentials or personal data.

## 3. Repository

| Item | Value |
|---|---|
| Repository | https://github.com/MdShabazS/MineGuard-MATLAB (public) |
| Default branch | `main` |
| Clone | `git clone https://github.com/MdShabazS/MineGuard-MATLAB.git` |
| Setup and dependencies | [SETUP.md](SETUP.md) |
| CI | GitHub Actions `task-gate`: task DAG, V2/V2.1 governance and portal tests. CI does **not** run MATLAB. |
| Guide portal | https://mineguard-guide-portal.onrender.com/ (Render static site, `portal/`) |

### Layout

| Path | Phase | Content | Status on `main` |
|---|---|---|---|
| `matlab/`, `tasks/`, `experiments/`, `results/` | V1 | Core simulation, fixed-grid and PPO demos, MG task records | 22/22 tasks DONE |
| `v2/` | V2 | High-fidelity mission simulation, sensors, detector bridge, mission-control UI, export/replay | 10/10 tasks DONE |
| `v2_1/` | V2.1 | Interactive synthetic scenarios: presets, survey grid, private target placement, post-run demo evaluation | 8/8 tasks DONE |
| `docs/` | all | Project documentation ([INDEX.md](INDEX.md)) | — |
| `portal/` | all | Guide's read-only progress portal | — |
| `scripts/` | all | Task gates (`task-gate.mjs`, `v2-gate.mjs`, `pr-gate.mjs`) and portal checks | — |

### Science status

| Phase | Result |
|---|---|
| V1 sealed TEST | TP 0, FP 26, TN 470, FN 4 |
| V2 VALIDATION | 0 of 4 targets |
| V2.1 Windows flights | 0 of 12 placed targets |

The detector has not been shown to work. These results are recorded honestly and are not hidden.

### Not verified

- **Mac runtime** for V2.1 final code.
- **Human-witnessed demonstration.**
- **Formal guide approval.**
