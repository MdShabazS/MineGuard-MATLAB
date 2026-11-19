// V2.2 task gate logic (pure functions; the CLI is scripts/v22-gate.mjs).
// Rule (docs/TEAM.md): the owner builds, tests, self-reviews and merges once CI passes and every
// dependency is DONE on the target branch. A task may go TODO -> DONE in one PR.
export const OWNERS = new Set(["Shabaz", "Rahil", "Danish"]);
export const STATES = new Set(["TODO", "IN_PROGRESS", "DONE"]);
export const KINDS = new Set(["DOC", "BUILD", "TEST"]);
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const check = (ok, message) => { if (!ok) throw Error(message); };

// readEvidence(path) returns the file text or null when the file does not exist.
export function validatePlan(mf, st, readEvidence) {
  check(mf?.schemaVersion === 1 && st?.schemaVersion === 1 && mf.tasks && st.tasks, "V2.2 task schema missing");
  const ids = Object.keys(mf.tasks);
  check(ids.length > 0 && ids.length === Object.keys(st.tasks).length && ids.every(id => id in st.tasks), "V2.2 ID sets differ");
  const seen = new Map();
  const visit = id => {
    if (seen.get(id) === 1) throw Error("V2.2 dependency cycle: " + id);
    if (seen.get(id) === 2) return;
    seen.set(id, 1); for (const dep of mf.tasks[id].dependsOn) visit(dep); seen.set(id, 2);
  };
  for (const id of ids) {
    const task = mf.tasks[id], status = st.tasks[id];
    check(/^V22-T\d+$/.test(id), "Bad V2.2 task ID: " + id);
    check(OWNERS.has(task.owner) && KINDS.has(task.kind), id + " invalid owner/kind");
    check(status.owner === task.owner && STATES.has(status.state), id + " invalid owner/status");
    check(typeof task.title === "string" && task.title.length > 20, id + " title missing");
    check(Array.isArray(task.acceptance) && task.acceptance.length > 0, id + " acceptance criteria missing");
    check(Array.isArray(task.dependsOn) && task.dependsOn.every(dep => dep !== id && mf.tasks[dep]) && new Set(task.dependsOn).size === task.dependsOn.length, id + " invalid prerequisites");
    check(task.evidence === `v2_2/evidence/${id}.md`, id + " invalid evidence path");
    const unmet = task.dependsOn.filter(dep => st.tasks[dep].state !== "DONE");
    if (status.state === "TODO") check(status.evidence === null && !status.startedBy && !status.completedBy, id + " TODO claims progress");
    if (status.state === "IN_PROGRESS") check(!unmet.length && status.startedBy === task.owner && status.startedOn && status.evidence === null && !status.completedBy, id + " invalid IN_PROGRESS");
    if (status.state === "DONE") {
      check(!unmet.length && status.startedBy === task.owner && status.completedBy === task.owner && status.completedOn && status.evidence === task.evidence, id + " invalid DONE metadata");
      const body = readEvidence(task.evidence);
      check(body !== null, id + " evidence not committed");
      check(body.length > 150 && body.includes("Task: " + id) && body.includes("Owner: " + task.owner) && body.includes("Self-review:"), id + " evidence incomplete (Task, Owner, Self-review)");
      if (task.kind !== "DOC") for (const label of ["Tester:", "Environment:", "Command:", "Observed output:", "Result: PASS"]) check(body.includes(label), id + " missing verification: " + label);
    }
    visit(id);
  }
  return ids;
}

export function readyTasks(mf, st) {
  return Object.keys(mf.tasks).filter(id => st.tasks[id].state === "TODO" && mf.tasks[id].dependsOn.every(dep => st.tasks[dep].state === "DONE"));
}

// Audit a PR against the target branch records (baseMf/baseSt are null when V2.2 does not exist there yet).
export function auditTransition(baseMf, baseSt, mf, st, branch) {
  check(branch, "Missing PR head branch");
  check(!!baseMf === !!baseSt, "Target branch has incomplete V2.2 records");
  if (!baseMf) {
    check(branch.startsWith("v22/"), "Initial V2.2 plan must use a v22/ branch");
    const early = Object.keys(st.tasks).filter(id => st.tasks[id].state !== "TODO" && mf.tasks[id].dependsOn.length);
    check(!early.length, "Initial V2.2 plan may only progress tasks without dependencies: " + early.join(", "));
    return "initial V2.2 plan";
  }
  if (!same(baseMf, mf)) {
    check(branch.startsWith("v22/plan-"), "V2.2 plan changes need a v22/plan- branch");
    // Allowed status edits in a plan PR: a new TODO task, or an owner transfer of a TODO task (only the owner field changes).
    const transfer = id => baseSt.tasks[id]?.state === "TODO" && baseMf.tasks[id]?.owner !== mf.tasks[id].owner
      && same({...baseSt.tasks[id], owner: mf.tasks[id].owner}, st.tasks[id]);
    const moved = Object.keys(st.tasks).filter(id => !same(baseSt.tasks[id], st.tasks[id]));
    check(moved.every(id => (!baseSt.tasks[id] && st.tasks[id].state === "TODO") || transfer(id)),
      "Cannot change the V2.2 plan and a task status in one PR (new TODO tasks and owner transfers of TODO tasks are allowed)");
    const transfers = moved.filter(transfer);
    return "V2.2 plan update" + (transfers.length ? "; owner transfer of TODO " + transfers.join(", ") : "");
  }
  const changed = Object.keys(st.tasks).filter(id => !same(baseSt.tasks[id], st.tasks[id]));
  check(changed.length <= 1, "A V2.2 PR can change only one task's status");
  if (!changed.length) return "no V2.2 status change";
  const id = changed[0], old = baseSt.tasks[id], next = st.tasks[id], task = mf.tasks[id];
  check(branch === "task/" + id || branch.startsWith("task/" + id + "-"), "Wrong V2.2 task branch: " + branch);
  check(task.dependsOn.every(dep => baseSt.tasks[dep]?.state === "DONE"), id + " dependencies are not DONE on main: wait for them");
  const ok = (old.state === "TODO" && ["IN_PROGRESS", "DONE"].includes(next.state)) || (old.state === "IN_PROGRESS" && next.state === "DONE");
  check(ok, id + " invalid transition " + old.state + " -> " + next.state);
  return id + " " + old.state + " -> " + next.state;
}
