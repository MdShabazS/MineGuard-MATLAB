import {REPO, BASE, buildTaskRows, summarize, fileUrl, githubLink, safeDate, findMainTaskGateRun} from "./core.mjs";
import {validateEnhancements, enhancementLabel} from "./enhancements.mjs";
const RAW="https://raw.githubusercontent.com/"+REPO+"/main/";
const API="https://api.github.com/repos/"+REPO;
let latestRows=[],filter="ALL",loading=false;
let v2Rows=[],v2Filter="ALL",v2WorkNotes=new Map(),v2SourceLabel="GitHub main";
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
  const notes=new Map();
  for(const entry of [...entries].reverse()){
    if(/^V2-\d{3}$/.test(entry.task) && !notes.has(entry.task))notes.set(entry.task,entry);
  }
  v2WorkNotes=notes;
  if(v2Rows.length)showV2Data(v2Rows);
  const sorted=[...entries].map((entry,index)=>({...entry,index})).sort((a,b)=>String(b.date||"").localeCompare(String(a.date||"")) || b.index-a.index).slice(0,8);
  replace("updates",sorted.length?sorted.map(entry=>{
    const card=make("div","feed-item");
    card.append(make("div","feed-meta",safeDate(entry.date)+" · "+(entry.owner||"Unknown")+" · "+(entry.task||"Task not recorded")));
    card.append(make("div","feed-title",entry.summary||"No summary provided"));
    if(entry.next)card.append(make("div","subtext","Next: "+entry.next));
    const url=fileUrl(entry.evidence);
    if(url)card.append(nodeLink("Evidence ↗",url));
    const pr=githubLink(entry.pr_url);
    if(pr)card.append(nodeLink("Review PR",pr));
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

/** V2 has independent task records on main; no draft branch can claim accepted work. */
function showV2Tasks(rows) {
  const filtered=v2Filter==="ALL"?rows:rows.filter(t=>t.displayState===v2Filter);
  const entries=filtered.map(task=>{
    const tr=make("tr"),info=make("td"),state=make("td"),detail=make("td");
    info.append(make("div","task-name",task.id+" · "+task.title),make("div","task-kind",task.kind));
    const workNote=v2WorkNotes.get(task.id);
    const reported=workNote && ["READY","IN_PROGRESS"].includes(task.displayState);
    if(reported){
      info.append(make("div","subtext","Active contribution reported · not a DONE task"));
      detail.append(make("div","subtext",workNote.summary));
      const pr=githubLink(workNote.pr_url);
      if(pr)detail.append(nodeLink("Review contribution PR",pr));
    }
    state.append(statusNode(task.displayState));
    if(task.displayState==="BLOCKED")detail.append(make("span","warning","Waiting: "+task.unfinished.join(", ")));
    else if(task.displayState==="DONE" && task.evidence){
      const url=fileUrl(task.evidence);
      detail.append(url?nodeLink("View evidence ↗",url):make("span","muted","Invalid evidence link"));
    }else if(task.displayState==="IN_PROGRESS")detail.append(make("span","muted","Active · "+(task.startedOn||"date not recorded")));
    else detail.append(make("span","muted",task.dependencies.length?"Prerequisites complete":"No prerequisites"));
    const owner=make("td","owner-cell",task.owner);
    if(reported && workNote.owner && workNote.owner!==task.owner){
      owner.append(make("div","subtext","MATLAB contributor: "+workNote.owner));
    }
    tr.append(info,owner,state,detail);return tr;
  });
  if(!entries.length){
    const tr=make("tr"),td=make("td","muted","No V2 tasks match this filter");
    td.colSpan=4;tr.append(td);entries.push(tr);
  }
  replace("v2TaskRows",entries);
}
function showV2Data(rows, sourceLabel=v2SourceLabel) {
  v2SourceLabel=sourceLabel;
  const s=summarize(rows);
  v2Rows=rows;
  el("v2Percent").textContent=s.percentage+"%";
  el("v2Done").textContent=s.counts.DONE+" / "+s.total+" tasks DONE";
  el("v2TaskTotal").textContent="("+s.total+")";
  for(const [id,value] of [["v2DoneCount",s.counts.DONE],["v2ActiveCount",s.counts.IN_PROGRESS],["v2ReadyCount",s.counts.READY],["v2BlockedCount",s.counts.BLOCKED]])el(id).textContent=value;
  el("v2SourceStatus").textContent=sourceLabel+" · "+s.counts.DONE+" DONE, "+s.counts.IN_PROGRESS+" IN PROGRESS";
  const active=rows.filter(t=>t.displayState==="IN_PROGRESS");
  const ready=rows.filter(t=>t.displayState==="READY");
  const now=[];
  if(active.length)now.push(...active.map(taskSnippet));
  else now.push(make("p","muted","No V2 task is currently IN_PROGRESS on GitHub main."));
  const reported=rows.filter(t=>["READY","IN_PROGRESS"].includes(t.displayState) && v2WorkNotes.has(t.id));
  if(reported.length){
    now.push(make("div","below-heading","Parallel MATLAB development (reported, not merged)"));
    for(const task of reported){
      const note=v2WorkNotes.get(task.id),item=make("div","task-snippet");
      item.append(make("strong","",task.id+" · "+note.owner+" · MATLAB development"));
      item.append(make("p","subtext",note.summary));
      const pr=githubLink(note.pr_url);
      if(pr)item.append(nodeLink("View active contribution PR",pr));
      now.push(item);
    }
  }
  if(ready.length){now.push(make("div","below-heading","Officially READY on GitHub main"));now.push(...ready.slice(0,4).map(taskSnippet));}
  replace("v2Current",now);
  replace("v2Owners",s.owners.map(o=>{
    const item=make("div","owner-card"),top=make("div","owner-top");
    top.append(make("strong","",o.name),make("span","owner-meta",o.done+" / "+o.total+" done"));
    const bar=make("div","owner-bar"),fill=make("div","owner-fill");
    fill.style.width=o.percentage+"%";bar.append(fill);
    item.append(top,bar,make("div","owner-foot",(o.active?o.active+" active · ":"")+o.percentage+"% of assigned V2 tasks complete"));
    return item;
  }));
  showV2Tasks(rows);
}
/** Enhancement roadmap is editorial planning data, never official V2 completion. */
function showEnhancements(data, sourceLabel="GitHub main") {
  const rows=validateEnhancements(data);
  const groups=[
    {id:"engineering",title:"Engineering enhancements",subtitle:"Detector integration, satellite prototype, mission UI, 3-D realism and scientific safeguards"},
    {id:"campus",title:"BITM / Ballari college presentation",subtitle:"Recognizable geographic context, offline backup and synthetic-to-satellite visualization"}
  ];
  const sections=groups.map(group=>{
    const items=rows.filter(item=>item.category===group.id);
    if(!items.length)return null;
    const section=make("section","enhancement-group");
    const heading=make("div","enhancement-group-heading");
    heading.append(make("h4","",group.title),
      make("span","enhancement-count",items.length+" planned/tracked entries"));
    section.append(heading,make("p","enhancement-group-subtitle",group.subtitle));
    const grid=make("div","enhancement-group-grid");
    for(const item of items){
      const card=make("article","enhancement-card");
      const header=make("div","enhancement-head");
      const meta=make("span","mini-id",item.id+" · "+item.priority);
      const state=make("span","enhancement-state "+item.status.toLowerCase().replaceAll("_","-"),enhancementLabel(item.status));
      header.append(meta,state);
      card.append(header,make("h5","enhancement-title",item.title));
      card.append(make("p","enhancement-owner","Owner: "+item.owner));
      card.append(make("p","enhancement-detail",item.detail));
      card.append(make("p","enhancement-dependency","Next gate: "+item.dependency));
      const url=githubLink(item.url);
      if(url)card.append(nodeLink(item.urlLabel,url,"tiny-link"));
      grid.append(card);
    }
    section.append(grid);
    return section;
  }).filter(Boolean);
  replace("roadmapItems",sections);
  const counts=Object.fromEntries(["ACTIVE_UNMERGED","TESTED_BLOCKED","MERGED_IN_BRANCH","PLANNED","BLOCKED"]
    .map(key=>[key,rows.filter(item=>item.status===key).length]));
  el("roadmapBreakdown").textContent=
    counts.ACTIVE_UNMERGED+" in development · "+
    counts.TESTED_BLOCKED+" tested, blocked · "+
    counts.MERGED_IN_BRANCH+" merged in a feature branch · "+
    counts.PLANNED+" planned · "+counts.BLOCKED+" blocked";
  el("roadmapStatus").textContent=rows.length+
    " tracked enhancements · "+rows.filter(x=>x.category==="campus").length+
    " campus-specific · source: "+sourceLabel+" · reviewed "+String(data.asOf || "date unavailable")+
    " · status notes are curated, not live PR automation · excluded from official V2 progress";
}
/**
 * A public main-branch fetch is preferred. The bundled snapshot is the exact
 * main-branch data at this portal build, marked as potentially outdated if used.
 * Never treat an unmerged PR or stale fallback as current task completion.
 */
async function getPublishedWithFallback(remotePaths, localPaths) {
  try {
    return {data:await Promise.all(remotePaths.map(p=>getJson(RAW+p))),source:"GitHub main (live read)"};
  }catch(remoteError) {
    try {
      return {data:await Promise.all(localPaths.map(p=>getJson(p))),
        source:"deployed GitHub-main snapshot (live read unavailable; may be outdated)"};
    }catch(localError){
      throw Error("Live GitHub read failed ("+remoteError.message+
        "); deployment snapshot failed ("+localError.message+")");
    }
  }
}
async function refreshEnhancements() {
  try {
    const result=await getPublishedWithFallback(
      ["v2/roadmap/enhancements.json"],["./data/enhancements.json"]);
    showEnhancements(result.data[0],result.source);
  }catch(error) {
    replace("roadmapItems",[make("p","muted","Enhancement roadmap unavailable. Open the source on GitHub main; no completion is assumed.")]);
    el("roadmapBreakdown").textContent="Enhancement status unavailable";
    el("roadmapStatus").textContent="Enhancement roadmap unavailable: "+error.message;
  }
}

async function refreshV2() {
  try {
    const result=await getPublishedWithFallback(
      ["v2/tasks/manifest.json","v2/tasks/status.json"],
      ["./data/v2-manifest.json","./data/v2-status.json"]);
    const [manifest,status]=result.data;
    const rows=buildTaskRows(manifest,status);
    if(rows.some(t=>!t.id.startsWith("V2-")))throw Error("Unexpected V2 task identifier");
    showV2Data(rows,result.source);
  }catch(error){
    // Main branch is authoritative. Never silently copy draft statuses or show stale values as current.
    v2Rows=[];
    el("v2SourceStatus").textContent="V2 status unavailable on GitHub main: "+error.message;
    for(const id of ["v2Percent","v2Done","v2TaskTotal","v2DoneCount","v2ActiveCount","v2ReadyCount","v2BlockedCount"])el(id).textContent="—";
    replace("v2Current",[make("p","muted","V2 records are unavailable. No task completion is assumed; inspect the published GitHub files.")]);
    replace("v2Owners",[make("p","muted","Owner progress unavailable.")]);
    const tr=make("tr"),td=make("td","muted","V2 task records unavailable from GitHub main.");
    td.colSpan=4;tr.append(td);replace("v2TaskRows",[tr]);
  }
}

async function refresh() {
  if(loading)return;
  loading=true;el("refresh").disabled=true;el("refresh").textContent="Refreshing…";
  // Independent V2 and enhancement fetches must run even when the legacy V1 fetch fails.
  const independent=Promise.allSettled([refreshV2(),refreshEnhancements()]);
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
    await independent;
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
el("v2Filters").addEventListener("click",event=>{
  const button=event.target.closest("button[data-filter]");
  if(!button)return;
  v2Filter=button.dataset.filter;
  for(const b of el("v2Filters").querySelectorAll("button[data-filter]")){
    const selected=b===button;b.classList.toggle("selected",selected);b.setAttribute("aria-pressed",String(selected));
  }
  if(v2Rows.length)showV2Tasks(v2Rows);
});
const deadline=new Date("2026-11-02T23:59:59+05:30"),days=Math.ceil((deadline-new Date())/(24*60*60*1000));
el("deadlineState").textContent=days>0?"· "+days+" days remaining":days===0?"· Due today":"· Deadline passed";
refresh();setInterval(()=>{if(!document.hidden)refresh();},5*60*1000);
document.addEventListener("visibilitychange",()=>{if(!document.hidden)refresh();});
