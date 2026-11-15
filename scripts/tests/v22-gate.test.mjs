import test from "node:test";
import assert from "node:assert/strict";
import {validatePlan, readyTasks, auditTransition} from "../v22-gate-core.mjs";

const task = (owner, deps = [], kind = "DOC") => ({owner, kind, dependsOn: deps, title: "A sufficiently long task title", evidence: "", acceptance: ["x"]});
function plan() {
  const mf = {schemaVersion: 1, tasks: {"V22-T1": task("Shabaz"), "V22-T2": task("Rahil", ["V22-T1"], "BUILD"), "V22-T3": task("Danish", ["V22-T1"])}};
  for (const id in mf.tasks) mf.tasks[id].evidence = `v2_2/evidence/${id}.md`;
  const st = {schemaVersion: 1, tasks: Object.fromEntries(Object.entries(mf.tasks).map(([id, t]) => [id, {owner: t.owner, state: "TODO", evidence: null}]))};
  return {mf, st};
}
const done = (id, owner) => ({owner, state: "DONE", evidence: `v2_2/evidence/${id}.md`, startedBy: owner, startedOn: "2026-11-15", completedBy: owner, completedOn: "2026-11-15"});
const doc = (id, owner, extra = "") => `Task: ${id}\nOwner: ${owner}\nSelf-review: checked by the owner.\n${extra}\n` + "x".repeat(160);
const clone = o => JSON.parse(JSON.stringify(o));

test("valid plan; ready tasks follow dependencies", () => {
  const {mf, st} = plan();
  assert.deepEqual(validatePlan(mf, st, () => null), ["V22-T1", "V22-T2", "V22-T3"]);
  assert.deepEqual(readyTasks(mf, st), ["V22-T1"]);
  st.tasks["V22-T1"] = done("V22-T1", "Shabaz");
  validatePlan(mf, st, p => doc("V22-T1", "Shabaz"));
  assert.deepEqual(readyTasks(mf, st), ["V22-T2", "V22-T3"]);
});

test("rejects unknown owner, bad ID, missing acceptance and cycles", () => {
  let {mf, st} = plan(); mf.tasks["V22-T3"].owner = "Codex"; st.tasks["V22-T3"].owner = "Codex";
  assert.throws(() => validatePlan(mf, st, () => null), /invalid owner/);
  ({mf, st} = plan()); mf.tasks["V22-T1"].acceptance = [];
  assert.throws(() => validatePlan(mf, st, () => null), /acceptance/);
  ({mf, st} = plan()); mf.tasks["V22-T1"].dependsOn = ["V22-T2"];
  assert.throws(() => validatePlan(mf, st, () => null), /cycle/);
});

test("DONE needs dependencies, evidence and a self-review; BUILD needs verification labels", () => {
  let {mf, st} = plan(); st.tasks["V22-T2"] = done("V22-T2", "Rahil");
  assert.throws(() => validatePlan(mf, st, () => null), /invalid DONE/);
  ({mf, st} = plan()); st.tasks["V22-T1"] = done("V22-T1", "Shabaz");
  assert.throws(() => validatePlan(mf, st, () => `Task: V22-T1\nOwner: Shabaz\n` + "x".repeat(200)), /Self-review/);
  st.tasks["V22-T2"] = done("V22-T2", "Rahil");
  const ev = p => p.includes("T1") ? doc("V22-T1", "Shabaz") : doc("V22-T2", "Rahil");
  assert.throws(() => validatePlan(mf, st, ev), /missing verification/);
  const full = p => p.includes("T1") ? doc("V22-T1", "Shabaz") : doc("V22-T2", "Rahil", "Tester: x\nEnvironment: x\nCommand: x\nObserved output: x\nResult: PASS");
  validatePlan(mf, st, full);
});

test("initial plan may only progress tasks without dependencies", () => {
  const {mf, st} = plan(); st.tasks["V22-T1"] = done("V22-T1", "Shabaz");
  assert.match(auditTransition(null, null, mf, st, "v22/plan-x"), /initial/);
  assert.throws(() => auditTransition(null, null, mf, st, "task/V22-T1"), /v22\//);
  const st2 = clone(st); st2.tasks["V22-T3"] = done("V22-T3", "Danish");
  assert.throws(() => auditTransition(null, null, mf, st2, "v22/plan-x"), /only progress/);
});

test("owner PR: one task, own branch, TODO -> DONE allowed only after dependencies are DONE on main", () => {
  const {mf, st} = plan();
  const base = clone(st); base.tasks["V22-T1"] = done("V22-T1", "Shabaz");
  const next = clone(base); next.tasks["V22-T3"] = done("V22-T3", "Danish");
  assert.match(auditTransition(mf, base, mf, next, "task/V22-T3-map-source"), /TODO -> DONE/);
  assert.throws(() => auditTransition(mf, base, mf, next, "task/V22-T2-x"), /Wrong V2.2 task branch/);
  const early = clone(st); early.tasks["V22-T3"] = done("V22-T3", "Danish");
  assert.throws(() => auditTransition(mf, st, mf, early, "task/V22-T3"), /wait for them/);
  const two = clone(next); two.tasks["V22-T2"] = {...done("V22-T2", "Rahil")};
  assert.throws(() => auditTransition(mf, base, mf, two, "task/V22-T3"), /only one/);
  const back = clone(base); back.tasks["V22-T1"] = {owner: "Shabaz", state: "TODO", evidence: null};
  assert.throws(() => auditTransition(mf, base, mf, back, "task/V22-T1"), /invalid transition/);
});

test("plan changes need a v22/plan- branch and no status change", () => {
  const {mf, st} = plan(); const mf2 = clone(mf); mf2.tasks["V22-T3"].title = "A different but long enough title";
  assert.match(auditTransition(mf, st, mf2, st, "v22/plan-retitle"), /plan update/);
  assert.throws(() => auditTransition(mf, st, mf2, st, "task/V22-T3"), /v22\/plan-/);
  const st2 = clone(st); st2.tasks["V22-T1"] = done("V22-T1", "Shabaz");
  assert.throws(() => auditTransition(mf, st, mf2, st2, "v22/plan-retitle"), /Cannot change/);
});
