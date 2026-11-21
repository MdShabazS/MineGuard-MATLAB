# MineGuard team and repository (current)

**Effective:** 2026-11-15 · **Decided by:** Shabaz (project lead) · This file is the single source for who works on MineGuard and how.

## 1. Team

MineGuard is now a MATLAB-only project. All work is done by three Claude Code sessions. Each session is operated by its own team member:

| # | Session | Operated by | Role |
|---|---|---|---|
| 1 | **Shabaz's Claude** (Mac, this repository's lead session) | Shabaz | **Project lead and decision maker.** Plans phases, defines and splits tasks, sets acceptance criteria, reviews all work, decides on merges and owns the documentation. |
| 2 | **Rahil's Claude** (Windows) | Rahil | Work assigned by Shabaz's Claude. Rahil's Windows laptop is currently the primary MATLAB execution and verification machine. |
| 3 | **Danish's Claude** | Danish | Work assigned by Shabaz's Claude. |

### Current phase: V2.2 BITM satellite view ([v2_2/README.md](../v2_2/README.md))

**How to work:**
1. Check the guide dashboard for your READY task.
2. Tell your Claude one line, for example *"I'm Rahil, let's do V22-T6"*.
3. The predefined master prompt in [v2_2/prompts/](../v2_2/prompts/README.md) does the rest: it marks the task started, builds, verifies, self-reviews, marks it done and merges.
4. On a new machine it first runs the environment check.

| Session | V2.2 tasks |
|---|---|
| Shabaz's Claude | V22-T1 plan and tracking; V22-T2 guide live dashboard; V22-T3 map source, licence and BITM location (moved from Danish); V22-T4 clean satellite preview module (moved from Rahil); V22-T5 virtual route over BITM (moved from Danish), all moved 2026-11-19; V22-T9 reel-style cut/fill map (added 2026-11-19); V22-T10 honest evaluation, V22-T11 draw-any-field survey, V22-T12 relief anomalies (added 2026-11-21 from the deep research); V22-T7 Mac verification (short tests only) |
| Rahil's Claude | V22-T6 mission-control integration |
| Danish's Claude | V22-T8 Windows acceptance and demo (includes the Windows run of all v2_2 tests) |

**ChatGPT and Codex are no longer used** on this project. Earlier records (task evidence, audits, decision-log entries, frozen specifications) keep their original wording and authorship and are not rewritten.

## 2. Working rules

1. **GitHub `main` is authoritative.** A local copy, chat message or AI summary is not a result until it is merged.
2. **Humans own tasks.** Task owners are Shabaz, Rahil or Danish. A Claude session is the tool that does the work, not the evidence that it was done.
3. **Say who did what.** Every PR, comment and evidence file says which session wrote or ran it, for example "Claude Code in Rahil's Windows session". Nobody approves as someone else or records a review or witness that did not happen.
4. **Owner merges (from V2.2, decided 2026-11-15).** The task owner builds, tests, **self-reviews and merges** their own task. There is no second-person review.
   - **Conditions for merging:**
     - the required `task-gate` check passes;
     - every dependency is DONE on `main`.
   - **Dependencies:** if a dependency is not DONE, stop that task and wait for its owner. If there is no dependency, continue.
   - **Self-review:** the PR and evidence state that the owner reviewed their own work (`Self-review:` line, enforced by `scripts/v22-gate.mjs`).
   - **Lead role:** Shabaz's Claude plans phases, defines and splits tasks and tracks progress. It does not review other owners' PRs.
   - **Never** bypass the check, merge a task whose dependencies are not DONE, or merge someone else's task.
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
