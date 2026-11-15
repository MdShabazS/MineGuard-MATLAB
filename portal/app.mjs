// Guide live dashboard: fetches GitHub data and renders it. All text is inserted as text, never HTML.
import {REPO, PHASE, buildTasks, attachPRs, summarize, whoIsDoingWhat, fileUrl, ago} from "./core.mjs";

const API = "https://api.github.com/repos/" + REPO;
const RAW = "https://raw.githubusercontent.com/" + REPO + "/";
const REFRESH_MS = 60000;
const $ = id => document.getElementById(id);
const LABEL = {DONE: "Done", IN_PROGRESS: "In progress", READY: "Ready", BLOCKED: "Waiting"};
let busy = false, lastGood = null;

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) if (v !== null && v !== undefined) node.setAttribute(k, v);
  for (const c of children) if (c !== null && c !== undefined) node.append(c instanceof Node ? c : document.createTextNode(String(c)));
  return node;
}
function link(href, text) { return href ? el("a", {href, target: "_blank", rel: "noopener noreferrer"}, text) : document.createTextNode(text); }

// "no-cache" makes the browser revalidate with the ETag; GitHub's 304 replies do not use the hourly API limit.
async function api(path) {
  const r = await fetch(API + path, {cache: "no-cache", headers: {Accept: "application/vnd.github+json"}});
  if (r.status === 403 || r.status === 429) throw Object.assign(Error("GitHub rate limit reached"), {rate: true});
  if (!r.ok) throw Error("GitHub API " + r.status);
  return r.json();
}
async function raw(ref, file, cache) {
  const r = await fetch(RAW + ref + "/" + file, {cache});
  if (!r.ok) throw Error(file + " " + r.status);
  return r.json();
}

async function load() {
  let sha = "main", notes = [];
  try { sha = (await api("/commits/main")).sha; } catch (e) { notes.push(e.rate ? "GitHub rate limit: task status may be a few minutes old." : "Could not read the latest main commit."); }
  const byRef = sha === "main" ? "no-store" : "force-cache";        // a commit SHA never changes, so it may be cached
  const [manifest, status] = await Promise.all([raw(sha, PHASE.manifest, byRef), raw(sha, PHASE.status, byRef)]);
  const tasks = buildTasks(manifest, status);
  let other = [], live = true;
  try {
    const [pulls, runs] = await Promise.all([api("/pulls?state=open&per_page=50"), api("/actions/runs?event=pull_request&per_page=60")]);
    other = attachPRs(tasks, pulls, runs.workflow_runs);
  } catch (e) { live = false; notes.push((e.rate ? "GitHub rate limit: " : "") + "live pull-request data is paused; showing merged status only."); }
  return {tasks, other, live, sha, notes};
}

function render({tasks, other, live, sha, notes}) {
  const s = summarize(tasks);
  $("phase").textContent = PHASE.name + " · " + s.counts.DONE + " of " + s.total + " tasks done (" + s.percent + "%)" + (sha !== "main" ? " · main " + sha.slice(0, 7) : "");
  $("doneCount").textContent = s.counts.DONE + " / " + s.total;
  $("activeCount").textContent = String(s.counts.IN_PROGRESS + tasks.filter(t => t.display !== "IN_PROGRESS" && t.display !== "DONE" && t.prs.length).length);
  $("readyCount").textContent = String(s.counts.READY);
  $("blockedCount").textContent = String(s.counts.BLOCKED);

  $("people").replaceChildren(...whoIsDoingWhat(tasks).map(p => {
    const prs = p.working.flatMap(t => t.prs);
    return el("article", {class: "person " + p.kind},
      el("h3", {}, p.session),
      el("p", {class: "now"}, p.now),
      ...prs.map(pr => el("p", {class: "pr"}, link(pr.url, "PR #" + pr.number), " · last commit " + ago(pr.lastCommit) + " · ", el("span", {class: "ci " + pr.ci.state}, pr.ci.label))),
      el("p", {class: "muted small"}, p.done + " of " + p.total + " tasks done"));
  }));

  $("taskRows").replaceChildren(...tasks.map(t => el("tr", {},
    el("td", {}, el("strong", {}, t.id), " ", t.title, t.evidence ? el("span", {}, " · ", link(fileUrl(t.evidence), "evidence")) : null),
    el("td", {}, t.owner + "'s Claude"),
    el("td", {}, el("span", {class: "status " + t.display}, LABEL[t.display])),
    el("td", {}, t.waitingFor.length ? t.waitingFor.join(", ") : "—"),
    el("td", {}, t.prs.length ? el("span", {}, ...t.prs.map(pr => el("span", {class: "pr"}, link(pr.url, "#" + pr.number), " ", el("span", {class: "ci " + pr.ci.state}, pr.ci.label), " · " + ago(pr.lastCommit) + " "))) : (live ? "—" : "paused")))));

  $("otherPRs").textContent = other.length ? other.length + " other open pull request(s) not linked to a task." : "";
  $("notice").hidden = !notes.length;
  $("notice").textContent = notes.join(" ");
  $("lastChecked").textContent = new Date().toLocaleTimeString();
}

async function refresh() {
  if (busy) return;
  busy = true; $("refresh").disabled = true;
  try { lastGood = await load(); render(lastGood); }
  catch (e) {
    $("notice").hidden = false;
    $("notice").textContent = "Could not read the task records from GitHub (" + e.message + ")." + (lastGood ? " Showing the last good data." : "");
    $("lastChecked").textContent = "Not updated";
  } finally { busy = false; $("refresh").disabled = false; }
}

$("refresh").addEventListener("click", refresh);
setInterval(() => { if (!document.hidden) refresh(); }, REFRESH_MS);
document.addEventListener("visibilitychange", () => { if (!document.hidden) refresh(); });
refresh();
