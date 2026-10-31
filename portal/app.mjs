import {REPO, BASE, buildTaskRows, summarize, fileUrl, githubLink, safeDate, findMainTaskGateRun} from "./core.mjs";
const RAW="https://raw.githubusercontent.com/"+REPO+"/main/";
const API="https://api.github.com/repos/"+REPO;
let latestRows=[],filter="ALL",loading=false;
const el=id=>document.getElementById(id);
function make(tag,cls,text) {
  const node=document.createElement(tag);
  if(cls)node.className=cls;
  if(text!==undefined&&text!==null)node.textContent=String(text);
  return node;
}
function nodeLink(label,url,cls="tiny-link") {
  const a=make("a",cls,label);
  if(url){a.href=url;a.target="_blank";a.rel="noopener noreferrer";}
  return a;
}
function replace(id,nodes){
  const parent=el(id);parent.replaceChildren(...nodes);
}
function alert(message,kind="warn"){
  const target=el("alert");
  target.hidden=!message;target.className="alert "+kind;target.textContent=message||"";
}
async function getJson(url){
  const res=await fetch(url,{cache:"no-store",headers:{"Accept":"application/vnd.github+json"}});
  if(!res.ok)throw Error(res.status+" "+res.statusText);
  return res.json();
}
function statusNode(status){
  const type={DONE:"done",IN_PROGRESS:"active",READY:"ready",BLOCKED:"blocked"}[status]||"blocked";
  const label={DONE:"Done",IN_PROGRESS:"In progress",READY:"Ready",BLOCKED:"Blocked"}[status]||status;
  return make("span","status "+type,label);
}
function showTasks(rows){
  const filtered=filter==="ALL"?rows:rows.filter(row=>row.displayState===filter);
  const items=filtered.map(task=>{
    const tr=make("tr");
    const info=make("td");
    const name=make("div","task-name",task.id+" · "+task.title);
    info.append(name,make("div","task-kind",task.kind));
    const owner=make("td","owner-cell",task.owner);
    const state=make("td");state.append(statusNode(task.displayState));
    const other=make("td","dep-cell");
    if(task.displayState==="BLOCKED")other.append(make("span","warning","Waiting: "+task.unfinished.join(", ")));
    else if(task.displayState==="DONE"&&task.evidence){
      const url=fileUrl(task.evidence);if(url)other.append(nodeLink("View evidence ↗",url));
      else other.append(make("span","muted","Invalid evidence link"));
    }else if(task.displayState==="IN_PROGRESS")other.append(make("span","muted","Active · "+(task.startedOn || "date not recorded")));
    else other.append(make("span","muted",task.dependencies.length?"Prerequisites complete":"No prerequisites"));
    tr.append(info,owner,state,other);return tr;
  });
  replace("taskRows",items.length?items:[(()=>{const tr=make("tr"),td=make("td","muted","No tasks match this filter");td.colSpan=4;tr.append(td);return tr;})()]);
}
function taskSnippet(t){
  const wrapper=make("div","task-snippet"),top=make("div","task-snippet-head");
  top.append(make("span","mini-id",t.id+" · "+t.owner),statusNode(t.displayState));
  wrapper.append(top,make("strong","",t.title));
  if(t.unfinished.length)wrapper.append(make("p","subtext","Waiting for: "+t.unfinished.join(", ")));
  return wrapper;
}
function showCurrent(rows){
  const active=rows.filter(r=>r.displayState==="IN_PROGRESS");
  const ready=rows.filter(r=>r.displayState==="READY");
  const content=[];
  if(active.length){active.forEach(t=>content.push(taskSnippet(t)));}
  else content.push(make("p","muted","No tasks currently marked IN_PROGRESS on GitHub main."));
  if(ready.length){const caption=make("div","below-heading","Ready to start next");content.push(caption,...ready.slice(0,4).map(taskSnippet));}
  replace("currentTasks",content);
}
function showOwners(owners){
  replace("owners",owners.map(o=>{
    const wrapper=make("div","owner-card");
    const top=make("div","owner-top");top.append(make("strong","",o.name),make("span","owner-meta",o.done+"/"+o.total+" completed"));
    const bar=make("div","owner-bar"),fill=make("div","owner-fill");fill.style.width=o.percentage+"%";bar.append(fill);
    wrapper.append(top,bar,make("div","owner-foot",(o.active?o.active+" active · ":"")+o.percentage+"% of assigned tasks done"));
    return wrapper;
  }));
}
function showSummary(summary,rows){
  el("doneCount").textContent=summary.counts.DONE+" / "+summary.total;
  el("activeCount").textContent=summary.counts.IN_PROGRESS;
  el("readyCount").textContent=summary.counts.READY;
  el("blockedCount").textContent=summary.counts.BLOCKED;
  el("percent").textContent=summary.percentage+"%";
  el("progressRing").style.setProperty("--progress",summary.percentage);
  el("taskTotal").textContent="("+summary.total+")";
  el("buildEvidence").textContent=rows.filter(r=>r.kind==="BUILD"&&r.displayState==="DONE").length+" marked DONE";
}
function showPulls(pulls){
  replace("pullRequests",pulls.length?pulls.slice(0,6).map(pr=>{
    const item=make("div","feed-item");
    const meta=make("div","feed-meta","#"+pr.number+" · "+(pr.merged_at?"Merged":pr.state==="open"?"Open":"Closed")+" · "+safeDate(pr.updated_at));
    const url=githubLink(pr.html_url);item.append(meta,nodeLink(pr.title||"Untitled PR",url,"feed-title"));
    return item;
  }):[make("p","muted","No pull requests found.")]);
}
function showChecks(data) {
  const run=findMainTaskGateRun(data);
  el("ciStatus").textContent=run ? (run.status==="completed"?(run.conclusion||"Completed"):"Running / queued") : "No main-branch task-gate run available";
  el("ciStatus").className=run?.conclusion==="success"?"good":"";
}

function showUpdates(data) {
  const entries=Array.isArray(data?.updates)?data.updates:[];
  const sorted=[...entries].sort((a,b)=>String(b.date||"").localeCompare(String(a.date||""))).slice(0,8);
  replace("updates",sorted.length?sorted.map(entry=>{
    const card=make("div","feed-item");
    card.append(make("div","feed-meta",safeDate(entry.date)+" · "+(entry.owner||"Unknown")+" · "+(entry.task||"Task not recorded")));
    card.append(make("div","feed-title",entry.summary||"No summary provided"));
    if(entry.next)card.append(make("div","subtext","Next: "+entry.next));
    const url=fileUrl(entry.evidence);
    if(url)card.append(nodeLink("Evidence ↗",url));
    return card;
  }):[make("p","muted","No verified work-journal entries yet. The AI agents will commit evidence-backed updates when tasks progress.")]);
}

function showCommits(items){
  replace("activity",items.length?items.slice(0,6).map(c=>{
    const item=make("div","feed-item"),meta=make("div","feed-meta",safeDate(c.commit?.author?.date)+" · "+(c.sha||"").slice(0,7));
    item.append(meta,nodeLink((c.commit?.message||"Untitled commit").split("\n")[0],githubLink(c.html_url),"feed-title"));
    return item;
  }):[make("p","muted","No recent commits found.")]);
}
async function refresh() {
  if(loading)return;
  loading=true;el("refresh").disabled=true;el("refresh").textContent="Refreshing…";
  try {
    // Status from main is mandatory. Never substitute an unmerged PR branch.
    const [manifest,status]=await Promise.all([getJson(RAW+"tasks/manifest.json"),getJson(RAW+"tasks/status.json")]);
    const rows=buildTaskRows(manifest,status),summary=summarize(rows);
    latestRows=rows;showSummary(summary,rows);showCurrent(rows);showOwners(summary.owners);showTasks(rows);
    el("lastChecked").textContent=new Date().toLocaleString(undefined,{dateStyle:"medium",timeStyle:"short"});
    alert("");
    const extras=await Promise.allSettled([
      getJson(API+"/pulls?state=all&per_page=10"),
      getJson(API+"/actions/runs?per_page=10"),
      getJson(API+"/commits?per_page=6"),
      getJson(RAW+"tasks/updates.json")
    ]);
    if(extras[0].status==="fulfilled")showPulls(extras[0].value);
    else replace("pullRequests",[make("p","muted","PR feed unavailable; open GitHub to inspect.")]);
    if(extras[1].status==="fulfilled")showChecks(extras[1].value);
    else el("ciStatus").textContent="GitHub API unavailable";
    if(extras[2].status==="fulfilled")showCommits(extras[2].value);
    else replace("activity",[make("p","muted","Activity feed unavailable; open GitHub to inspect.")]);
    if(extras[3].status==="fulfilled")showUpdates(extras[3].value);
    else replace("updates",[make("p","muted","Team journal unavailable; see GitHub for task history.")]);
    if(extras.some(x=>x.status==="rejected"))alert("The project task board is current, but one or more GitHub activity feeds could not load (possibly a public API rate limit).","notice");
  }catch(error){
    if(!latestRows.length){
      const banner="Task status is not published on GitHub main yet. MG-000 foundation remains under review, or GitHub is unreachable. View foundation PR #1 for the draft files; no completion is assumed.";
      alert(banner+" ("+error.message+")","warn");
      replace("currentTasks",[nodeLink("Open foundation PR #1 ↗",BASE+"/pull/1")]);
      replace("owners",[make("p","muted","Authoritative task data is not available on main.")]);
      replace("taskRows",[(()=>{const tr=make("tr"),td=make("td","muted","Awaiting tasks/manifest.json and tasks/status.json on main.");td.colSpan=4;tr.append(td);return tr;})()]);
      el("lastChecked").textContent="Not synchronized";
    }else alert("Could not refresh. Displayed task data is from the last successful check; open GitHub to verify. ("+error.message+")","warn");
  }finally{
    loading=false;el("refresh").disabled=false;el("refresh").textContent="↻ Refresh now";
  }
}
el("refresh").addEventListener("click",refresh);
el("filters").addEventListener("click",event=>{
  const button=event.target.closest("button[data-filter]");if(!button)return;
  filter=button.dataset.filter;
  for(const b of el("filters").querySelectorAll("button[data-filter]")){
    const selected=b===button;b.classList.toggle("selected",selected);b.setAttribute("aria-pressed",String(selected));
  }
  if(latestRows.length)showTasks(latestRows);
});
const deadline=new Date("2026-11-02T23:59:59+05:30"),days=Math.ceil((deadline-new Date())/(24*60*60*1000));
el("deadlineState").textContent=days>0?"· "+days+" days remaining":days===0?"· Due today":"· Deadline passed";
refresh();setInterval(()=>{if(!document.hidden)refresh();},5*60*1000);
document.addEventListener("visibilitychange",()=>{if(!document.hidden)refresh();});
