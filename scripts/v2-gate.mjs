#!/usr/bin/env node
// Independent V2 task gate: never change V1 records or treat a draft PR as accepted work.
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
const manifestPath="v2/tasks/manifest.json", statusPath="v2/tasks/status.json";
const load=file=>JSON.parse(fs.readFileSync(path.join(root,file),"utf8"));
const mf=load(manifestPath), st=load(statusPath);
const fail=message=>{throw Error(message)};
const check=(ok,message)=>{if(!ok)fail(message)};
const owners=new Set(["Shabaz","Rahil"]), states=new Set(["TODO","IN_PROGRESS","DONE"]);
const ownPath=value=>typeof value==="string" && value.startsWith("v2/evidence/V2-") && !value.includes("..") && !path.isAbsolute(value);
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);

function validate() {
  check(mf.schemaVersion===1&&st.schemaVersion===1&&mf.tasks&&st.tasks,"V2 task schema missing");
  const ids=Object.keys(mf.tasks);
  check(ids.length>0&&ids.length===Object.keys(st.tasks).length&&ids.every(id=>id in st.tasks),"V2 ID sets differ");
  const visited=new Map();
  function visit(id){
    if(visited.get(id)===1)fail("V2 dependency cycle: "+id);
    if(visited.get(id)===2)return;
    visited.set(id,1);
    for(const dep of mf.tasks[id].dependsOn)visit(dep);
    visited.set(id,2);
  }
  for(const id of ids) {
    const task=mf.tasks[id],status=st.tasks[id];
    check(/^V2-\d{3}$/.test(id),"Bad V2 task ID: "+id);
    check(owners.has(task.owner)&&["DOC","BUILD"].includes(task.kind),id+" invalid owner/kind");
    check(status.owner===task.owner&&states.has(status.state),id+" invalid owner/status");
    check(typeof task.title==="string"&&task.title.length>20,id+" title missing");
    check(Array.isArray(task.dependsOn)&&task.dependsOn.every(dep=>dep!==id&&mf.tasks[dep])&&new Set(task.dependsOn).size===task.dependsOn.length,id+" invalid prerequisites");
    check(ownPath(task.evidence)&&task.evidence===`v2/evidence/${id}.md`,id+" invalid evidence path");
    const unmet=task.dependsOn.filter(dep=>st.tasks[dep].state!=="DONE");
    if(status.state==="TODO")check(status.evidence===null&&!status.startedBy&&!status.completedBy,id+" TODO claims progress");
    if(status.state==="IN_PROGRESS")check(!unmet.length&&status.startedBy===task.owner&&status.startedOn&&status.evidence===null&&!status.completedBy,id+" invalid IN_PROGRESS");
    if(status.state==="DONE"){
      check(!unmet.length&&status.startedBy===task.owner&&status.completedBy===task.owner&&status.completedOn&&status.evidence===task.evidence,id+" invalid DONE metadata");
      const file=path.join(root,task.evidence);
      check(fs.existsSync(file),id+" evidence not committed");
      const body=fs.readFileSync(file,"utf8");
      check(body.length>150&&body.includes("Task: "+id)&&body.includes("Owner: "+task.owner),id+" evidence incomplete");
      if(task.kind==="BUILD")for(const label of ["Tester:","Environment:","Command:","Observed output:","Result: PASS","Research:"])check(body.includes(label),id+" missing BUILD verification: "+label);
    }
    visit(id);
  }
  return ids;
}
function readBase(file){
  const base=process.env.GITHUB_BASE_REF||"main";
  const ref="refs/remotes/origin/"+base;
  execFileSync("git",["rev-parse","--verify",ref],{cwd:root,stdio:"pipe"});
  try{execFileSync("git",["cat-file","-e",ref+":"+file],{cwd:root,stdio:"pipe"});}
  catch{return null;}
  return JSON.parse(execFileSync("git",["show",ref+":"+file],{cwd:root,encoding:"utf8",stdio:["ignore","pipe","pipe"]}));
}
function auditPR(){
  const branch=process.env.GITHUB_HEAD_REF||process.env.PR_HEAD_REF||"";
  check(branch,"Missing PR head branch");
  const baseMf=readBase(manifestPath),baseSt=readBase(statusPath);
  check(!!baseMf===!!baseSt,"Target main has incomplete V2 records");
  if(!baseMf){
    check(branch.startsWith("v2/"),"Initial V2 tracker must use v2/ branch");
    check(Object.values(st.tasks).every(s=>s.state==="TODO"&&s.evidence===null),"Initial V2 task statuses must all be TODO");
    return "initial V2 plan, all TODO; no completed work claimed";
  }
  if(!same(baseMf,mf)){
    check(branch.startsWith("v2/plan-"),"V2 task plan changes need v2/plan- branch");
    check(same(baseSt,st),"Cannot change V2 plan and V2 status in one PR");
    return "separate proposed V2 plan update";
  }
  const changed=Object.keys(st.tasks).filter(id=>!same(baseSt.tasks[id],st.tasks[id]));
  check(changed.length<=1,"A V2 PR can transition only one task");
  if(!changed.length)return "no V2 state transition";
  const id=changed[0],old=baseSt.tasks[id],next=st.tasks[id],task=mf.tasks[id];
  check(branch.startsWith("task/"+id+"-")||branch==="task/"+id,"Wrong V2 task branch: "+branch);
  check(task.dependsOn.every(dep=>baseSt.tasks[dep]?.state==="DONE"),id+" prerequisites not DONE on main");
  check((old.state==="TODO"&&next.state==="IN_PROGRESS")||(old.state==="IN_PROGRESS"&&next.state==="DONE"),id+" invalid transition");
  if(next.state==="IN_PROGRESS")check(next.startedBy===task.owner&&next.startedOn&&next.evidence===null,id+" wrong start metadata");
  else check(next.completedBy===task.owner&&next.completedOn&&next.evidence===task.evidence,id+" wrong completion metadata");
  return id+" "+old.state+" -> "+next.state;
}
try {
  const ids=validate();
  const command=process.argv[2]||"validate";
  if(command==="validate")console.log("PASS: "+ids.length+" V2 tasks, owner/dependency/evidence governance");
  else if(command==="ready"){
    const ready=ids.filter(id=>st.tasks[id].state==="TODO"&&mf.tasks[id].dependsOn.every(dep=>st.tasks[dep].state==="DONE"));
    console.log(ready.length?ready.map(id=>id+" ["+mf.tasks[id].owner+"] "+mf.tasks[id].title).join("\n"):"No READY V2 tasks");
  }else if(command==="pr")console.log("PASS: V2 PR governance: "+auditPR());
  else fail("Use validate | ready | pr");
}catch(error){console.error("FAIL: "+error.message);process.exitCode=1;}
