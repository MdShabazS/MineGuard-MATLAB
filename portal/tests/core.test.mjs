import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {buildTasks, taskOfBranch, ciFor, attachPRs, summarize, whoIsDoingWhat, fileUrl, safeGithub, ago, PHASE, mainShaFromRuns} from "../core.mjs";

const mf = {tasks: {
  "V22-T1": {owner: "Shabaz", kind: "DOC", dependsOn: [], title: "Plan"},
  "V22-T2": {owner: "Shabaz", kind: "BUILD", dependsOn: ["V22-T1"], title: "Dashboard"},
  "V22-T3": {owner: "Danish", kind: "DOC", dependsOn: ["V22-T1"], title: "Map source"},
  "V22-T4": {owner: "Rahil", kind: "BUILD", dependsOn: ["V22-T3"], title: "Satellite module"}}};
const st = () => ({tasks: {"V22-T1": {state: "DONE", evidence: "v2_2/evidence/V22-T1.md"}, "V22-T2": {state: "TODO"}, "V22-T3": {state: "TODO"}, "V22-T4": {state: "TODO"}}});
const run = (sha, status, conclusion, created = "2026-11-15T10:00:00Z") => ({name: "Task Gate", head_sha: sha, status, conclusion, created_at: created, html_url: "https://github.com/MdShabazS/MineGuard-MATLAB/actions/runs/1", head_commit: {timestamp: created}});
const pr = (n, ref, sha) => ({number: n, title: "PR " + n, html_url: "https://github.com/MdShabazS/MineGuard-MATLAB/pull/" + n, head: {ref, sha}, user: {login: "x"}, updated_at: "2026-11-15T09:00:00Z"});

test("READY and Waiting come from dependencies on main", () => {
  const t = buildTasks(mf, st());
  assert.deepEqual(t.map(x => x.display), ["DONE", "READY", "READY", "BLOCKED"]);
  assert.deepEqual(t[3].waitingFor, ["V22-T3"]);
  assert.deepEqual(summarize(t), {total: 4, counts: {DONE: 1, IN_PROGRESS: 0, READY: 2, BLOCKED: 1}, percent: 25});
});

test("rejects mismatched or invalid records", () => {
  assert.throws(() => buildTasks(mf, {tasks: {"V22-T1": {state: "DONE"}}}), /disagree/);
  const bad = st(); bad.tasks["V22-T2"].state = "MAYBE";
  assert.throws(() => buildTasks(mf, bad), /Invalid/);
});

test("task branches map to tasks; CI uses the newest Task Gate run of the PR head", () => {
  assert.equal(taskOfBranch("task/V22-T4-satellite"), "V22-T4");
  assert.equal(taskOfBranch("task/V22-T4"), "V22-T4");
  assert.equal(taskOfBranch("task/V22-T40x"), null);
  assert.equal(taskOfBranch("feature/x"), null);
  assert.equal(ciFor([], "a").state, "none");
  assert.equal(ciFor([run("a", "in_progress", null)], "a").state, "running");
  assert.equal(ciFor([run("a", "completed", "failure", "2026-11-15T09:00:00Z"), run("a", "completed", "success", "2026-11-15T11:00:00Z")], "a").state, "pass");
  assert.equal(ciFor([run("b", "completed", "success")], "a").state, "none");
});

test("open PRs attach to their task as live work; others are counted separately", () => {
  const t = buildTasks(mf, st());
  const other = attachPRs(t, [pr(7, "task/V22-T3-map", "s3"), pr(8, "docs/x", "s8")], [run("s3", "completed", "success")]);
  assert.equal(t[2].prs.length, 1);
  assert.equal(t[2].prs[0].ci.state, "pass");
  assert.equal(t[2].prs[0].lastCommit, "2026-11-15T10:00:00Z");
  assert.equal(other.length, 1);
});

test("who is doing what: working, ready and waiting with the blocking owner", () => {
  const t = buildTasks(mf, st());
  attachPRs(t, [pr(7, "task/V22-T3-map", "s3")], []);
  const p = Object.fromEntries(whoIsDoingWhat(t).map(x => [x.name, x]));
  assert.equal(p.Danish.kind, "working");
  assert.match(p.Danish.now, /V22-T3/);
  assert.equal(p.Shabaz.kind, "ready");
  assert.match(p.Shabaz.now, /V22-T2/);
  assert.equal(p.Rahil.kind, "waiting");
  assert.match(p.Rahil.now, /V22-T4 waits for V22-T3 \(Danish's Claude\)/);
});

test("latest main commit comes from the newest Task Gate push run on main", () => {
  const r = (sha, branch, event, at) => ({name: "Task Gate", head_sha: sha, head_branch: branch, event, created_at: at});
  assert.equal(mainShaFromRuns([r("old", "main", "push", "2026-11-15T08:00:00Z"), r("new", "main", "push", "2026-11-15T09:00:00Z"), r("pr", "task/V22-T3", "pull_request", "2026-11-15T10:00:00Z")]), "new");
  assert.equal(mainShaFromRuns([r("pr", "task/x", "pull_request", "2026-11-15T10:00:00Z")]), null);
  assert.equal(mainShaFromRuns(null), null);
});

test("links stay inside the repository; times are relative", () => {
  assert.match(fileUrl("v2_2/evidence/V22-T1.md"), /\/blob\/main\/v2_2\/evidence\/V22-T1\.md$/);
  assert.equal(fileUrl("../x"), null);
  assert.equal(safeGithub("https://evil.example/MdShabazS/MineGuard-MATLAB/pull/1"), null);
  assert.equal(safeGithub("javascript:alert(1)"), null);
  assert.equal(ago("2026-11-15T10:00:00Z", Date.parse("2026-11-15T10:30:00Z")), "30 min ago");
  assert.equal(ago("bad"), "unknown");
});

test("page contract: phase records, live sources, no HTML injection", () => {
  const html = fs.readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const app = fs.readFileSync(new URL("../app.mjs", import.meta.url), "utf8");
  for (const id of ["phase", "people", "taskRows", "doneCount", "activeCount", "readyCount", "blockedCount", "lastChecked", "refresh", "notice"]) assert.match(html, new RegExp('id="' + id + '"'));
  assert.match(html, /<meta name="mineguard-dashboard" content="[^"]+">/);
  assert.match(html, /Simulation only/);
  assert.equal(PHASE.manifest, "v2_2/tasks/manifest.json");
  assert.match(app, /\/pulls\?state=open/);
  assert.match(app, /\/actions\/runs\?per_page=/);
  assert.match(app, /REFRESH_MS = 180000/);
  assert.match(app, /x-ratelimit-remaining/);
  assert.doesNotMatch(app, /innerHTML|insertAdjacentHTML|outerHTML/);
});
