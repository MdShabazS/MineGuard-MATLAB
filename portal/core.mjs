/**
 * Guide live dashboard: pure calculations (no DOM, no network), unit-tested in portal/tests.
 * Status comes only from the task records on GitHub main; open PRs are shown as live, NOT merged, work.
 */
export const REPO = "MdShabazS/MineGuard-MATLAB";
export const BASE = "https://github.com/" + REPO;
export const PHASE = {name: "V2.2 — BITM satellite view", manifest: "v2_2/tasks/manifest.json", status: "v2_2/tasks/status.json", readme: "v2_2/README.md"};
export const MEMBERS = ["Shabaz", "Rahil", "Danish"];
const STATES = new Set(["TODO", "IN_PROGRESS", "DONE"]);

export function buildTasks(manifest, status) {
  if (!manifest?.tasks || !status?.tasks) throw Error("Task records unavailable");
  const ids = Object.keys(manifest.tasks);
  if (!ids.length || ids.some(id => !status.tasks[id])) throw Error("Task list and statuses disagree");
  return ids.map(id => {
    const t = manifest.tasks[id], s = status.tasks[id];
    if (!STATES.has(s.state) || !Array.isArray(t.dependsOn)) throw Error("Invalid record for " + id);
    const waitingFor = t.dependsOn.filter(dep => status.tasks[dep]?.state !== "DONE");
    const display = s.state === "TODO" ? (waitingFor.length ? "BLOCKED" : "READY") : s.state;
    return {id, owner: t.owner, kind: t.kind, title: t.title, dependsOn: t.dependsOn, waitingFor, display,
      evidence: s.evidence || null, completedOn: s.completedOn || null, startedOn: s.startedOn || null, prs: []};
  });
}

// "task/V22-T4-satellite" -> "V22-T4"; anything else -> null.
export function taskOfBranch(ref) {
  const m = /^task\/(V22-T\d+)(?:-|$)/.exec(ref || "");
  return m ? m[1] : null;
}

// CI for a commit from an Actions runs listing: the newest "Task Gate" run on that SHA.
export function ciFor(runs, sha) {
  const run = (runs || []).filter(r => r.head_sha === sha && (r.name === "Task Gate" || r.path?.includes("task-gate")))
    .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))[0];
  if (!run) return {state: "none", label: "CI not run yet"};
  if (run.status !== "completed") return {state: "running", label: "CI running", url: run.html_url};
  return run.conclusion === "success" ? {state: "pass", label: "CI passed", url: run.html_url} : {state: "fail", label: "CI " + (run.conclusion || "failed"), url: run.html_url};
}

// Attach open PRs to their tasks. Returns PRs that are not task PRs as `other`.
export function attachPRs(tasks, pulls, runs) {
  const byId = Object.fromEntries(tasks.map(t => [t.id, t]));
  const other = [];
  for (const pr of pulls || []) {
    const id = taskOfBranch(pr.head?.ref);
    const run = (runs || []).find(r => r.head_sha === pr.head?.sha);
    const live = {number: pr.number, title: pr.title, url: safeGithub(pr.html_url), draft: !!pr.draft, branch: pr.head?.ref,
      author: pr.user?.login || "", lastCommit: run?.head_commit?.timestamp || pr.updated_at || null, ci: ciFor(runs, pr.head?.sha)};
    if (id && byId[id]) byId[id].prs.push(live); else other.push(live);
  }
  return other;
}

export function summarize(tasks) {
  const counts = Object.fromEntries(["DONE", "IN_PROGRESS", "READY", "BLOCKED"].map(k => [k, tasks.filter(t => t.display === k).length]));
  return {total: tasks.length, counts, percent: tasks.length ? Math.round(counts.DONE / tasks.length * 100) : 0};
}

// What each member's Claude session is doing right now, from records plus open PRs.
export function whoIsDoingWhat(tasks) {
  const owners = [...new Set([...MEMBERS, ...tasks.map(t => t.owner)])];
  return owners.map(name => {
    const mine = tasks.filter(t => t.owner === name);
    const working = mine.filter(t => t.display === "IN_PROGRESS" || (t.display !== "DONE" && t.prs.length));
    const ready = mine.filter(t => t.display === "READY" && !t.prs.length);
    const blocked = mine.filter(t => t.display === "BLOCKED" && !t.prs.length);
    let now, kind;
    if (working.length) { now = working.map(t => t.id + " " + t.title).join(" · "); kind = "working"; }
    else if (ready.length) { now = "Ready to start " + ready[0].id + ": " + ready[0].title; kind = "ready"; }
    else if (blocked.length) {
      const t = blocked[0];
      now = t.id + " waits for " + t.waitingFor.map(d => d + " (" + (tasks.find(x => x.id === d)?.owner || "?") + "'s Claude)").join(", ");
      kind = "waiting";
    } else { now = mine.length ? "All assigned tasks done" : "No task assigned"; kind = "idle"; }
    return {name, session: name + "'s Claude", now, kind, working, done: mine.filter(t => t.display === "DONE").length, total: mine.length};
  });
}

export function fileUrl(path) {
  if (!path || !/^[a-zA-Z0-9_./-]+$/.test(path) || path.split("/").includes("..")) return null;
  return BASE + "/blob/main/" + path.split("/").map(encodeURIComponent).join("/");
}
export function safeGithub(value) {
  try { const u = new URL(value); return u.protocol === "https:" && u.hostname === "github.com" && u.pathname.startsWith("/" + REPO + "/") ? u.href : null; }
  catch { return null; }
}
export function ago(iso, now = Date.now()) {
  const t = new Date(iso).getTime();
  if (!Number.isFinite(t)) return "unknown";
  const s = Math.max(0, Math.round((now - t) / 1000));
  if (s < 90) return "just now";
  const m = Math.round(s / 60); if (m < 90) return m + " min ago";
  const h = Math.round(m / 60); if (h < 36) return h + " h ago";
  return Math.round(h / 24) + " days ago";
}
