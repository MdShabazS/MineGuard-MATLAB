#!/usr/bin/env node
// GitHub is authoritative; local status updates take effect only once committed/merged to main.
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {fileURLToPath} from "node:url";
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
const load=p=>JSON.parse(fs.readFileSync(path.join(root,p),"utf8"));
const mf=load("tasks/manifest.json"), st=load("tasks/status.json");
const validStates=new Set(["TODO","IN_PROGRESS","DONE"]);
const fail=s=>{throw new Error(s)};
const assert=(b,s)=>{if(!b)fail(s)};
const ownPath=p=>typeof p==="string"&&p.trim()!==""&&!path.isAbsolute(p)&&!p.split(/[\\/]/).includes("..");
function artifactExists(p){return ownPath(p)&&fs.existsSync(path.join(root,p));}
function blocked(id){
  const t=mf.tasks[id];assert(t,"Unknown task "+id);
  return t.dependsOn.filter(dep=>st.tasks[dep]?.state!=="DONE");
}
function validate(){
  assert(mf.schemaVersion===1&&st.schemaVersion===1,"Schema mismatch");
  assert(mf.tasks&&st.tasks&&Object.keys(mf.tasks).length>0,"No tasks");
  const ids=Object.keys(mf.tasks);
  assert(ids.length===Object.keys(st.tasks).length&&ids.every(id=>st.tasks[id]),"Task/status ID set mismatch");
  const visits=new Map();
  function walk(id){
    if(visits.get(id)===1)fail("Dependency cycle at "+id);
    if(visits.get(id)===2)return;
    visits.set(id,1);
    for(const dep of mf.tasks[id].dependsOn){assert(mf.tasks[dep],id+" unknown dependency "+dep);assert(dep!==id,id+" self dependency");walk(dep);}
    visits.set(id,2);
  }
  for(const id of ids){
    const t=mf.tasks[id],s=st.tasks[id];
    assert(["Shabaz","Rahil"].includes(t.owner)&&["BUILD","DOC"].includes(t.kind),id+" invalid kind/owner");
    assert(Array.isArray(t.dependsOn)&&new Set(t.dependsOn).size===t.dependsOn.length,id+" duplicate dependencies");
    assert(ownPath(t.evidence),id+" unsafe artifact path");
    assert(s.owner===t.owner&&validStates.has(s.state),id+" owner/state invalid");
    if(s.state==="TODO")assert(s.evidence===null&&!s.startedBy,id+" TODO contains completion/start data");
    if(s.state==="IN_PROGRESS"){
      assert(s.startedBy===t.owner,id+" started by wrong owner");
      assert(s.evidence===null,id+" in progress with completed evidence");
      assert(blocked(id).length===0,id+" started before prerequisites completed");
    }
    if(s.state==="DONE"){
      assert(blocked(id).length===0,id+" DONE with unfinished prerequisite");
      assert(s.evidence===t.evidence&&artifactExists(s.evidence),id+" missing/wrong evidence");
      assert(s.completedBy===t.owner&&s.startedBy===t.owner,id+" owner/transition metadata missing");
      const body=fs.readFileSync(path.join(root,s.evidence),"utf8");
      assert(body.length>150,id+" evidence too short");
      assert(body.includes("Task: "+id)&&body.includes("Owner: "+t.owner),id+" evidence metadata mismatch");
      if(t.kind==="BUILD"){
        for(const term of ["Tester:","Result: PASS","Command:","Observed output:","Environment:","Research:"])
          assert(body.includes(term),id+" missing executed test evidence field "+term);
      }
    }
    walk(id);
  }
}
function write(){fs.writeFileSync(path.join(root,"tasks/status.json"),JSON.stringify(st,null,2)+"\n");}
try {
 validate();
 const [command,id,actor]=process.argv.slice(2);
 if(command==="validate"){console.log("PASS: task DAG, statuses, owners and evidence consistent");}
 else if(command==="ready"){
  const ids=Object.keys(mf.tasks).filter(x=>st.tasks[x].state==="TODO"&&blocked(x).length===0);
  console.log(ids.length?ids.map(x=>x+" ["+mf.tasks[x].owner+"] "+mf.tasks[x].title).join("\n"):"No READY TODO tasks");
 }
 else if(command==="check"){
  assert(id,"Usage: check MG-XXX");
  const b=blocked(id),s=st.tasks[id];assert(s,"Unknown task "+id);
  console.log(id+" ["+mf.tasks[id].owner+"] "+(b.length?"BLOCKED by "+b.join(", "):s.state==="TODO"?"READY":s.state));
  if(b.length)process.exitCode=2;
 }
 else if(command==="start"){
  assert(id&&actor,"Usage: start MG-XXX Shabaz|Rahil");
  const t=mf.tasks[id],s=st.tasks[id];assert(t&&s,"Unknown task");
  assert(t.owner===actor&&s.state==="TODO","Wrong owner or task is not TODO");
  assert(blocked(id).length===0,id+" blocked by "+blocked(id).join(", "));
  s.state="IN_PROGRESS";s.startedBy=actor;s.startedOn=new Date().toISOString().slice(0,10);
  write();validate();console.log("IN_PROGRESS "+id+" (commit/push; not authoritative until merged)");
 }
 else if(command==="complete"){
  assert(id&&actor,"Usage: complete MG-XXX Shabaz|Rahil");
  const t=mf.tasks[id],s=st.tasks[id];assert(t&&s,"Unknown task");
  assert(t.owner===actor&&s.state==="IN_PROGRESS"&&s.startedBy===actor,"Not in progress by assigned owner");
  assert(blocked(id).length===0,id+" blocked");
  assert(artifactExists(t.evidence),"Required evidence file missing: "+t.evidence);
  s.state="DONE";s.evidence=t.evidence;s.completedBy=actor;s.completedOn=new Date().toISOString().slice(0,10);
  try{validate();write();console.log("Proposed DONE "+id+"; must pass PR review/CI and merge to main");}
  catch(e){s.state="IN_PROGRESS";s.evidence=null;delete s.completedBy;delete s.completedOn;throw e;}
 }
 else fail("Usage: validate | ready | check ID | start ID OWNER | complete ID OWNER");
} catch(err){console.error("FAIL: "+err.message);process.exitCode=1;}
