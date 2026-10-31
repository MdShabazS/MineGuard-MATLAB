import test from "node:test";
import assert from "node:assert/strict";
import {buildTaskRows,summarize,fileUrl,githubLink,findMainTaskGateRun} from "../core.mjs";
const manifest={tasks:{
  "MG-000":{owner:"Shabaz",kind:"DOC",title:"Foundation",dependsOn:[],evidence:"docs/FOUNDATION.md"},
  "MG-001":{owner:"Rahil",kind:"BUILD",title:"MATLAB",dependsOn:["MG-000"],evidence:"tasks/evidence/MG-001.md"},
  "MG-002":{owner:"Shabaz",kind:"DOC",title:"Design",dependsOn:["MG-000","MG-001"],evidence:"tasks/evidence/MG-002.md"},
  "MG-003":{owner:"Shabaz",kind:"DOC",title:"Independent research",dependsOn:[],evidence:"tasks/evidence/MG-003.md"}
}};
test("accurate readiness and blocked dependency status",()=>{
 const status={tasks:{"MG-000":{state:"DONE",evidence:"docs/FOUNDATION.md"},"MG-001":{state:"IN_PROGRESS"},"MG-002":{state:"TODO"},"MG-003":{state:"TODO"}}};
 const rows=buildTaskRows(manifest,status);
 assert.deepEqual(rows.map(x=>x.displayState),["DONE","IN_PROGRESS","BLOCKED","READY"]);
 assert.deepEqual(rows[2].unfinished,["MG-001"]);
 const summary=summarize(rows);
 assert.equal(summary.total,4);assert.equal(summary.percentage,25);
 assert.equal(summary.counts.BLOCKED,1);assert.equal(summary.counts.READY,1);
 assert.deepEqual(summary.owners.find(o=>o.name==="Rahil"),{name:"Rahil",total:1,done:0,active:1,percentage:0});
});
test("no false READY for incomplete prerequisites",()=>{
 const s={tasks:Object.fromEntries(Object.keys(manifest.tasks).map(id=>[id,{state:"TODO"}]))};
 const rows=buildTaskRows(manifest,s);
 assert.equal(rows.find(x=>x.id==="MG-001").displayState,"BLOCKED");
 assert.equal(rows.find(x=>x.id==="MG-002").displayState,"BLOCKED");
 assert.equal(rows.find(x=>x.id==="MG-003").displayState,"READY");
});
test("contradictory or missing statuses are not accepted",()=>{
 assert.throws(()=>buildTaskRows(manifest,{tasks:{"MG-000":{state:"DONE"}}}),/disagree/);
 const s={tasks:Object.fromEntries(Object.keys(manifest.tasks).map(id=>[id,{state:"TODO"}]))};
 s.tasks["MG-001"]={state:"DONE"};
 assert.throws(()=>buildTaskRows(manifest,s),/violates task prerequisites/);
});
test("evidence and feed links reject unsafe domains and path traversal",()=>{
 assert.match(fileUrl("tasks/evidence/MG-001.md"),/github.com\/MdShabazS\/MineGuard-MATLAB\/blob\/main/);
 assert.equal(fileUrl("../.env"),null);
 assert.equal(githubLink("https://evil.example/x"),null);
 assert.equal(githubLink("javascript:alert(1)"),null);
 assert.ok(githubLink("https://github.com/MdShabazS/MineGuard-MATLAB/pull/1"));
});

test("CI status must not show an unmerged PR result as main success",()=>{
 const runs={workflow_runs:[
  {name:"Task Gate",head_branch:"setup/mg-000-foundation",status:"completed",conclusion:"success"},
  {name:"Task Gate",head_branch:"main",status:"completed",conclusion:"failure"}
 ]};
 assert.equal(findMainTaskGateRun(runs)?.conclusion,"failure");
 assert.equal(findMainTaskGateRun({workflow_runs:[runs.workflow_runs[0]]}),null);
});
