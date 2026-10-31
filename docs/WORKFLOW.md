# GitHub-first Dependency DAG Governance

## Two members, two AI tools
- **Shabaz** with ChatGPT: source research, guide-required unchanged problem/objectives, research references, specifications, acceptance tests, independent verification, approved documentation.
- **Rahil** with Claude Code: MATLAB/Simulink code, models, automated experiments, debugging and execution proof. Shabaz may manually test MATLAB if environment permits.
- GitHub `main` is authoritative. No unpushed working copy, chat statement or AI summary is an accepted task outcome.

## Task DAG

**Independence example:** MG-002 (Rahil's local MATLAB release/toolbox check) has no hard dependency on MG-000, so he may independently inspect MATLAB while the foundation PR is in review. However he cannot record accepted DONE on main before the repository task system is merged. Other tasks remain blocked by their actual listed dependencies.

## Work journal

Each substantive progress update is recorded as a truthful, GitHub-reviewed entry in `tasks/updates.json`. Required fields: `date` (actual date), `owner` (Shabaz/Rahil), `task` (task ID), `summary`, `next`, optional `evidence` (repository file path). No fabricated updates. Guide portal reads these entries on `main` and provides a plain-English current work journal.

## Task DAG
`tasks/manifest.json` defines each task ID, owner, dependencies and artifact path; `tasks/status.json` records TODO/IN_PROGRESS/DONE. **BLOCKED is computed**, not manually set. No fake global serial order: two unrelated tasks may be IN_PROGRESS simultaneously. READY means every prerequisite is DONE on main.

## Work protocol
1. Fetch latest `main` and run `node scripts/task-gate.mjs validate`, `... ready`, and `... check MG-XXX`.
2. If blocked, STOP **only this task**; list unmet IDs. Any other independent READY task may proceed.
3. Create `task/MG-XXX-short-name` branch from latest main. Mark IN_PROGRESS and push branch; do actual source research, author deliverables and test.
4. Collect truthful proof in `tasks/evidence/MG-XXX.md` (for BUILD) or specified documentation artifact (for DOC).
5. Prepare PR, request other member's review, run CI. Proposed DONE status must not be interpreted as accepted until reviewed and merged.
6. On merge, verify merged SHA and `main` state; if not final, status remains IN_PROGRESS. No CI test should be called MATLAB validation unless MATLAB actually executed.
7. Re-evaluate READY/blocked tasks; independent work continues.

## Bootstrap exception MG-000
This feature branch creates the foundation and first task gate. MG-000 starts IN_PROGRESS. Once reviewed/merged, close MG-000 with evidence and truthful status. There is no completed task yet just because docs were created.

## Public repo controls
GitHub branch ruleset required for `main`: PR before merge, ≥1 review, required `task-gate` check, block force pushes and deletions. These are NOT active until configured in GitHub settings. Status and evidence can be forged by direct push unless ruleset is enforced; human checks remain required. Avoid an impossible self-review: each PR author is reviewed by the other person, once collaborator is invited.

## Task commands
```bash
node scripts/task-gate.mjs validate
node scripts/task-gate.mjs ready
node scripts/task-gate.mjs check MG-004
node scripts/task-gate.mjs start MG-004 Rahil
# Implement, test and write real evidence, commit/push
node scripts/task-gate.mjs complete MG-004 Rahil
```
CLI mutations change only the checkout until committed; GitHub main stays source of truth. Never force push or commit credentials.

## Security
Public repo: no MATLAB licence data, service tokens, student identity documents, private flight coordinates or unwittingly copied copyrighted materials.

**Guard against manifest edits:** a PR cannot both alter `tasks/manifest.json` and modify any task's status. Any governance DAG change must be a separately reviewed, no-status-transition PR. The PR gate audits the authoritative target-branch task manifest and status.
