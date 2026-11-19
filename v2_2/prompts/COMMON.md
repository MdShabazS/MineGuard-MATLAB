# COMMON master prompt (every V2.2 task)

You are the Claude Code session of the person named in the request, for example "I'm Rahil, let's do V22-T6". Do the task end to end by following these steps in order. Then load `v2_2/prompts/V22-Tn.md` for the task details. Rules: `docs/TEAM.md`.

## 0. Save tokens (applies throughout)

- **Read only what you need:** the files this prompt and the task file name. Use `grep`/`sed -n` ranges instead of whole large files. Never re-read a file you just wrote.
- **Keep output short:** write long logs to a file and show only the summary lines or `tail`.
- **Run things once:** batch independent commands in one call. Run the full regression only where the task file says so.
- **Subagents:** give them a short, exact brief and ask for a summary of 10 lines or fewer (pass/fail, file paths, SHAs). Don't paste their raw output into the main conversation.
- **Messages to the person:** in the format Task / Status / Verified / GitHub / Next.

## 1. Who and which task

1. **Name:** must be Shabaz, Rahil or Danish. The task ID is `V22-Tn` ("Task n" means `V22-Tn`).
2. **Owner:** read the task's owner in `v2_2/tasks/manifest.json`. If it isn't this person, **stop**. Say whose task it is, and list this person's READY tasks instead.

## 2. Sync and environment

1. **Sync:** `git fetch origin && git switch main && git pull --ff-only`. If local changes block this, ask; never discard them.
2. **Environment:** if this machine has no `v2_2/evidence/ENV-<Name>.md` with a PASS line from the last 7 days, run [ENV_CHECK.md](ENV_CHECK.md) first. If a required item is missing, guide the installation step by step and stop the task until it passes.

## 3. Is the task READY?

1. Run `node scripts/v22-gate.mjs ready`.
2. **Not listed:** **stop**. Explain why:
   - already DONE; or
   - waiting for which task, owned by whom (from `dependsOn`).
3. Also tell the person which of their tasks are READY, if any. Never start a task whose dependencies are not DONE on `main`.

## 4. Start, so the dashboard shows it as ongoing

1. **Branch:** `git switch -c task/V22-Tn-<short-name>`. The dashboard only recognises a branch named `task/V22-Tn-…`.
2. **Status:** in `v2_2/tasks/status.json`, set the task to `"state": "IN_PROGRESS"`, `"startedBy": "<Name>"` and `"startedOn": "<today YYYY-MM-DD>"`, with `"evidence": null`.
3. **Evidence stub:** create `v2_2/evidence/V22-Tn.md` containing `Task: V22-Tn`, `Owner: <Name>` and `Built by: Claude Code in <Name>'s session`.
4. **Check, commit, push:** run `node scripts/v22-gate.mjs validate`, then commit `V22-Tn: start` and push.
5. **Draft PR:** `gh pr create --draft --title "V22-Tn: <task title>" --body "Started by Claude Code in <Name>'s session. Plan: …"`.
6. The guide's dashboard shows the task as in progress, with this PR, within 3 minutes.

## 5. Build

1. **Follow the task file:** do what it says, nothing outside its scope. Keep V1, V2 and V2.1 behaviour, the detector, sealed TEST data and other owners' files unchanged unless the task file says otherwise.
2. **Subagents, wherever work is independent:** launch them in parallel and integrate their results yourself. Typical splits:
   - one researches sources or reads old code;
   - one writes tests while you write the code;
   - one checks the diff against the acceptance criteria.
   Never give two subagents the same file.
3. **Commit as you go:** push small commits to the PR branch, so the dashboard's "last commit" stays current.

## 6. Verify

1. **Run real tests:** run the exact tests the task file lists, with MATLAB through the MATLAB MCP server where MATLAB is needed.
2. **Record each result in the evidence file:**
   - `Tester:`, `Environment:` (OS, MATLAB release, toolboxes);
   - `Command:`, `Observed output:` (pass/fail counts, checkcode messages);
   - the exact commit SHA;
   - `Result: PASS` only if everything required passed.
3. **Honesty:**
   - A test you did not run is **NOT RUN**; never write PASS for it.
   - Never weaken or delete a test to make it pass.
   - Never record a person watching, reviewing or approving something that did not happen.

## 7. Self-review (you are the only reviewer)

Before marking DONE, check each point and write the outcome under `Self-review:` in the evidence file:

- **Acceptance:** every acceptance criterion of the task in `v2_2/tasks/manifest.json` is met, with proof such as a test name, a file or an observed output.
- **Scope:** `git diff origin/main --stat` touches only this task's scope.
- **Secrets:** no secrets, licence data or personal data.
- **Map imagery:** no map tiles or screenshots of imagery committed, unless `v2_2/docs/V22_T3_MAP_SOURCE_AND_LOCATION.md` allows it. Keep screenshots local and describe them in the evidence.
- **Markers:** no mine, target, truth or anomaly marker drawn on real campus imagery. Mission geometry is labelled VIRTUAL.
- **Code quality:** `checkcode` reports 0 messages on changed MATLAB files.
- **Gates:** `node scripts/v22-gate.mjs validate` and the Node tests (`node --test scripts/tests/*.test.mjs portal/tests/*.test.mjs`) pass.
- **Big tasks:** for BUILD tasks, ask one fresh subagent to review the diff against the acceptance criteria, and fix what it finds.

If a criterion can't be met, don't mark DONE. Leave the task IN_PROGRESS, explain in the PR, and tell the person.

## 8. Complete, so the dashboard shows Done

1. **Status:** in `status.json`, set `"state": "DONE"`, `"completedBy": "<Name>"`, `"completedOn": "<today>"` and `"evidence": "v2_2/evidence/V22-Tn.md"`.
2. **Gates and push:** run `node scripts/v22-gate.mjs validate` and push.
3. **PR ready:** `gh pr ready`. Update the PR body: what was done, test results with SHA, the self-review, and "Built, self-reviewed and merged by Claude Code in <Name>'s session".
4. **Wait for CI:** `gh pr checks --watch`. `task-gate` must pass. If `main` moved, merge `main` into the branch, re-run the gates and push. Never force-push.
5. **Merge:** `gh pr merge --merge`, then `git switch main && git pull`.
6. **Confirm:** the dashboard shows the task Done within 3 minutes. If this unblocked someone else's task, say so: "V22-T4 (Rahil) is now READY".

## 9. Stop conditions (stop and tell the person)

- **Missing software:** a required tool is missing or not licensed.
- **Unmet dependency:** a dependency is not DONE.
- **CI failing:** CI fails for a reason outside this task.
- **Defect elsewhere:** a defect in someone else's merged task blocks you. Open a GitHub issue that names the task and the failing test, and tell the person.
- **Licence doubt:** licence terms are unclear. Choose the safe option (don't commit imagery) and record it.
