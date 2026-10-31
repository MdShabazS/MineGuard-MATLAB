import test from "node:test";
import assert from "node:assert/strict";
import {auditProposedTaskChanges as audit} from "../pr-gate-core.mjs";
const manifest={schemaVersion:1,tasks:{
 "MG-000":{owner:"Shabaz",dependsOn:[],evidence:"docs/FOUNDATION.md"},
 "MG-001":{owner:"Rahil",dependsOn:["MG-000"],evidence:"tasks/evidence/MG-001.md"},
 "MG-002":{owner:"Shabaz",dependsOn:["MG-001"],evidence:"tasks/evidence/MG-002.md"}
}};
const entry=(state,owner,evidence=null)=>({state,owner,evidence});
const base={schemaVersion:1,tasks:{"MG-000":entry("DONE","Shabaz","docs/FOUNDATION.md"),"MG-001":entry("TODO","Rahil"),"MG-002":entry("TODO","Shabaz")}};
const clone=x=>JSON.parse(JSON.stringify(x));
test("correct task starts when base prerequisite DONE",()=>{
 const next=clone(base);next.tasks["MG-001"]={state:"IN_PROGRESS",owner:"Rahil",evidence:null,startedBy:"Rahil",startedOn:"2026-10-31"};
 assert.deepEqual(audit(base,next,manifest,"task/MG-001-build").changes,["MG-001"]);
});
test("cannot mark dependency DONE in same PR to unlock downstream task",()=>{
 const initial=clone(base);initial.tasks["MG-000"]=entry("IN_PROGRESS","Shabaz");
 const next=clone(initial);next.tasks["MG-000"]=entry("DONE","Shabaz","docs/FOUNDATION.md");
 next.tasks["MG-001"]={state:"IN_PROGRESS",owner:"Rahil",evidence:null,startedBy:"Rahil",startedOn:"2026-10-31"};
 assert.throws(()=>audit(initial,next,manifest,"task/MG-001-build"),/only one task/);
});
test("cannot start a task whose prerequisite is only proposed as complete",()=>{
 const initial=clone(base);initial.tasks["MG-000"]=entry("IN_PROGRESS","Shabaz");
 const next=clone(initial);next.tasks["MG-001"]={state:"IN_PROGRESS",owner:"Rahil",evidence:null,startedBy:"Rahil",startedOn:"2026-10-31"};
 assert.throws(()=>audit(initial,next,manifest,"task/MG-001-build"),/not DONE on target/);
});
test("can't leap from TODO to DONE with fake evidence",()=>{
 const next=clone(base);next.tasks["MG-001"]={state:"DONE",owner:"Rahil",evidence:"tasks/evidence/MG-001.md",startedBy:"Rahil",completedBy:"Rahil",completedOn:"2026-10-31"};
 assert.throws(()=>audit(base,next,manifest,"task/MG-001-build"),/invalid state transition/);
});
test("can't modify status from an unrelated branch",()=>{
 const next=clone(base);next.tasks["MG-001"]={state:"IN_PROGRESS",owner:"Rahil",evidence:null,startedBy:"Rahil",startedOn:"2026-10-31"};
 assert.throws(()=>audit(base,next,manifest,"random-feature"),/require task/);
});
test("documentation-only PR with no status change remains valid",()=>{
 assert.deepEqual(audit(base,clone(base),manifest,"docs/typo").changes,[]);
});
test("bootstrap only on exact foundation branch and no task marked DONE",()=>{
 const baseline=clone(base);baseline.tasks["MG-000"]={state:"IN_PROGRESS",owner:"Shabaz",evidence:null,startedBy:"Shabaz",startedOn:"2026-10-31"};
 assert.equal(audit(null,baseline,manifest,"setup/mg-000-foundation").bootstrap,true);
 assert.throws(()=>audit(null,baseline,manifest,"malicious-branch"),/only to initial/);
 baseline.tasks["MG-000"].state="DONE";
 assert.throws(()=>audit(null,baseline,manifest,"setup/mg-000-foundation"),/must be IN_PROGRESS/);
});
test("completion has to retain owner and evidence path",()=>{
 const initial=clone(base);initial.tasks["MG-001"]={state:"IN_PROGRESS",owner:"Rahil",evidence:null,startedBy:"Rahil",startedOn:"2026-10-31"};
 const next=clone(initial);next.tasks["MG-001"]={...next.tasks["MG-001"],state:"DONE",evidence:"tasks/evidence/MG-001.md",completedBy:"Rahil",completedOn:"2026-10-31"};
 assert.equal(audit(initial,next,manifest,"task/MG-001-test").detail,"IN_PROGRESS -> DONE");
 next.tasks["MG-001"].evidence="wrong.md";assert.throws(()=>audit(initial,next,manifest,"task/MG-001-test"),/Evidence path/);
});

test("changing prerequisites and task status together cannot bypass main",()=>{
 const proposedManifest=clone(manifest);
 proposedManifest.tasks["MG-002"].dependsOn=[];
 const next=clone(base);
 next.tasks["MG-002"]={state:"IN_PROGRESS",owner:"Shabaz",evidence:null,startedBy:"Shabaz",startedOn:"2026-10-31"};
 assert.throws(()=>audit(base,next,proposedManifest,"task/MG-002-bypass",manifest),/Cannot change task manifest/);
});
