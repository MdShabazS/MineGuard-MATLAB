# Why Each GitHub Task Is Owned and Blocked
**Machine authority:** `tasks/manifest.json` and merged `tasks/status.json` on `main`, not this explanatory page. This page explains reasons and recommended execution waves.

## Roles
**Shabaz (ChatGPT):** research, objective preservation, specs, experiment design, review, documentation; also may run independent MATLAB on Mac after environment verified. **Rahil (Claude Code):** MATLAB installed environment, code, test/execution logs, bug fixes, technical handoff. Both inspect PRs; nobody self-approves.

## Task dependency table
| Task | Owner | Needs | Why / handoff |
|---|---|---|---|
| MG-000 | Shabaz | None | Repo, immutable Phase-1, docs, task gate. Needs Rahil review before merge. |
| MG-001 | Shabaz | MG-000 | Literature/source validation uses approved baseline. |
| MG-002 | Rahil | None | MATLAB inventory is technically independent of documentation; local check may run immediately. Accepted task status in main awaits foundation merger. |
| MG-003 | Shabaz | MG-001, MG-002 | Freeze architecture only once requirements and local products known. |
| MG-004 | Rahil | MG-003 | Scenario implementation depends on fixed data types and coordinate system. |
| MG-005 | Rahil | MG-004 | Navigation must know scenario geometry/terrain/seed. |
| MG-006 | Shabaz | MG-003 | Sensor physics contract depends on intended data API. |
| MG-007 | Rahil | MG-004, MG-006 | Sensor models need truth generator and verified physical constraints. |
| MG-008 | Shabaz | MG-006 | Fusion plan requires established sensor characteristics. |
| MG-009 | Rahil | MG-007, MG-008 | Inference must know sensor sampling and evaluation protocol. |
| MG-010 | Shabaz | MG-003 | UI design can progress parallel to sensor work after schemas fixed. |
| MG-011 | Rahil | MG-005, MG-009, MG-010 | Dashboard requires route logs, detection outputs and UI contract. |
| MG-012 | Shabaz | MG-005 | PPO planning needs actual baseline action space and route semantics. |
| MG-013 | Rahil | MG-005, MG-012 | PPO train and compare only against functioning baseline. |
| MG-014 | Shabaz | MG-008, MG-012 | Lock test set/fairness after sensor/fusion and RL specs ready. |
| MG-015 | Rahil | MG-011, MG-014 | Core integration needs tested route/sensor fusion/app and test plan; PPO is not required to establish a functional baseline. |
| MG-016 | Shabaz | MG-015 | Evaluate actual reproducible evidence and original objectives. |
| MG-017 | Rahil | MG-016 | Final corrections based on verified review findings. |
| MG-018 | Shabaz | MG-017 | Final report and presentation from actual release evidence. |
| MG-019 | Rahil | MG-013, MG-015 | Optional PPO integrated benchmarking; no fake training; failure cannot block MG-015. |
| MG-020 | Shabaz | MG-000 | Deploy guide portal, capture live URL and first real GitHub sync evidence. |
| MG-021 | Shabaz | MG-020 | Browser/mobile accessibility, refresh, accuracy and error-state tests of live Render portal. |

## Dependency graph (conceptual)
```text
MG-000 -> MG-001 -------+
                        +--> MG-003 -> MG-004 -> MG-005 -----+-----> MG-011 ----+
MG-002 -----------------+        |       |                  |                  |
                                  |       +-> MG-007 -> MG-009+                  +-> MG-015 -> MG-016 -> MG-017 -> MG-018
                                  +-> MG-006 -> MG-008 ----+                    |
                                  +-> MG-010 --------------+                    |
                                                MG-012 -> MG-013 ----------------+
                                                      \
                                                       MG-014 (with MG-008)
```
The diagram is explanatory; **use manifest** for exact edges.

## Workflow states
- `TODO` with all dependencies DONE: READY.
- `TODO` with unmet dependencies: BLOCKED (computed, not stored).
- `IN_PROGRESS`: active work with owner on its branch; **not** proof of completion.
- `DONE`: merged evidence on main and required fields verified. A branch-level DONE proposal does not authorize a downstream task before merge.

## Independent work examples
Rahil can inspect MATLAB (`MG-002`) while Shabaz prepares foundation (`MG-000`). After architecture freezes, Rahil may implement a scenario while Shabaz designs sensor requirements if prerequisites are met. Shabaz cannot mark validation complete merely because Claude reports 'tests passing'.

## Critical operational caveat
Most development work takes real MATLAB execution on Rahil's machine; ChatGPT cannot install toolboxes or run the desktop remotely by reading GitHub. Human inputs must be requested only where essential and their evidence uploaded to GitHub.

## Deadline treatment
Original target is 2026-11-02. Strict dependency coverage may make all 19 tasks impossible in two days. Do **not** bypass gates or claim completion. Use explicit task statuses and a truthful demonstrable baseline, with incomplete advanced items named. Any reprioritization requires its own reviewed change to manifest; never silently edit the baseline objectives.

## Core critical path and optional research path
Core demonstration and final report use `MG-015 → MG-016 → MG-017 → MG-018`. PPO can be implemented and compared via `MG-013 → MG-019` after a working grid baseline. Reporting may include that work only when actual training and held-out benchmark evidence exists. A failed PPO training attempt remains scientifically valuable and must not be marked DONE without evidence. The guide portal's **deployment and browser acceptance** use separate `MG-020 → MG-021` tasks.
