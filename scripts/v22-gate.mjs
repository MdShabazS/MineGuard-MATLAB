#!/usr/bin/env node
// V2.2 task gate CLI: validate | ready | pr. Logic in scripts/v22-gate-core.mjs.
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import {validatePlan, readyTasks, auditTransition} from "./v22-gate-core.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifestPath = "v2_2/tasks/manifest.json", statusPath = "v2_2/tasks/status.json";
const load = file => JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
const readEvidence = file => { const p = path.join(root, file); return fs.existsSync(p) ? fs.readFileSync(p, "utf8") : null; };
function readBase(file) {
  const ref = "refs/remotes/origin/" + (process.env.GITHUB_BASE_REF || "main");
  execFileSync("git", ["rev-parse", "--verify", ref], {cwd: root, stdio: "pipe"});
  try { execFileSync("git", ["cat-file", "-e", ref + ":" + file], {cwd: root, stdio: "pipe"}); } catch { return null; }
  return JSON.parse(execFileSync("git", ["show", ref + ":" + file], {cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"]}));
}
try {
  const mf = load(manifestPath), st = load(statusPath);
  const ids = validatePlan(mf, st, readEvidence);
  const command = process.argv[2] || "validate";
  if (command === "validate") console.log("PASS: " + ids.length + " V2.2 tasks, owner/dependency/evidence governance");
  else if (command === "ready") {
    const ready = readyTasks(mf, st);
    console.log(ready.length ? ready.map(id => id + " [" + mf.tasks[id].owner + "] " + mf.tasks[id].title).join("\n") : "No READY V2.2 tasks");
  } else if (command === "pr") {
    const branch = process.env.GITHUB_HEAD_REF || process.env.PR_HEAD_REF || "";
    console.log("PASS: V2.2 PR governance: " + auditTransition(readBase(manifestPath), readBase(statusPath), mf, st, branch));
  } else throw Error("Use validate | ready | pr");
} catch (error) { console.error("FAIL: " + error.message); process.exitCode = 1; }
