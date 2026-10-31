/**
 * Pure task calculations: same manifest/status records as GitHub main.
 * No optimistic status, fabricated completion, or private data.
 */
export const REPO = "MdShabazS/MineGuard-MATLAB";
export const BASE = "https://github.com/" + REPO;
const validStates = new Set(["TODO", "IN_PROGRESS", "DONE"]);
export function buildTaskRows(manifest, status) {
  if (!manifest || !status || !manifest.tasks || !status.tasks) throw Error("Task manifest/status unavailable");
  const tasks = manifest.tasks;
  const states = status.tasks;
  const ids = Object.keys(tasks);
  if (!ids.length) throw Error("No task records available");
  if (ids.length !== Object.keys(states).length || ids.some(id => !states[id])) throw Error("Task list and statuses disagree");
  return ids.map(id => {
    const t = tasks[id], state = states[id];
    if (!validStates.has(state.state) || !Array.isArray(t.dependsOn)) throw Error("Invalid status or dependency for " + id);
    const unfinished = t.dependsOn.filter(dep => !states[dep] || states[dep].state !== "DONE");
    if ((state.state === "DONE" || state.state === "IN_PROGRESS") && unfinished.length) throw Error(id + " violates task prerequisites");
    const displayState = state.state === "TODO" ? (unfinished.length ? "BLOCKED" : "READY") : state.state;
    return { id, owner:t.owner, kind:t.kind, title:t.title, path:t.evidence, state:state.state, displayState,
      unfinished, dependencies:t.dependsOn, evidence:state.evidence || null, startedOn:state.startedOn || null, completedOn:state.completedOn || null };
  });
}
export function summarize(rows) {
  const total = rows.length;
  const counts = Object.fromEntries(["DONE","IN_PROGRESS","READY","BLOCKED"].map(key => [key,rows.filter(t=>t.displayState===key).length]));
  const owners = [...new Set(rows.map(t=>t.owner))].sort().map(name=>{
    const mine=rows.filter(t=>t.owner===name),done=mine.filter(t=>t.displayState==="DONE").length,active=mine.filter(t=>t.displayState==="IN_PROGRESS").length;
    return {name,total:mine.length,done,active,percentage:mine.length?Math.round(done/mine.length*100):0};
  });
  return {total,counts,percentage:total?Math.round(counts.DONE/total*100):0,owners};
}
export function fileUrl(path) {
  if (!path || !/^[a-zA-Z0-9_./-]+$/.test(path) || path.split("/").includes("..")) return null;
  return BASE + "/blob/main/" + path.split("/").map(encodeURIComponent).join("/");
}
export function githubLink(value) {
  try {const u=new URL(value);return u.protocol==="https:" && u.hostname==="github.com" && u.pathname.startsWith("/"+REPO+"/") ? u.href : null;}
  catch {return null;}
}
export function safeDate(iso) {
  if (!iso) return "Date unavailable";
  const date=new Date(iso);
  return Number.isFinite(date.getTime()) ? date.toLocaleDateString(undefined,{day:"numeric",month:"short",year:"numeric"}) : "Date unavailable";
}
