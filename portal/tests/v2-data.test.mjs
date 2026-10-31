import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {spawnSync} from "node:child_process";
import {buildTaskRows,summarize} from "../core.mjs";

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"../..");
const mf=JSON.parse(fs.readFileSync(path.join(root,"v2/tasks/manifest.json"),"utf8"));
const status=JSON.parse(fs.readFileSync(path.join(root,"v2/tasks/status.json"),"utf8"));
const initial={schemaVersion:1,tasks:Object.fromEntries(Object.entries(status.tasks).map(([id,s])=>[id,{owner:s.owner,state:"TODO",evidence:null}]))};
test("V1 archive and V2 plan are independently sourced and current statuses are valid",()=>{
 const legacy=JSON.parse(fs.readFileSync(path.join(root,"tasks/status.json"),"utf8"));
 assert.equal(Object.keys(legacy.tasks).length,22);
 assert.equal(Object.values(legacy.tasks).filter(x=>x.state==="DONE").length,22);
 const rows=buildTaskRows(mf,status),summary=summarize(rows);
 assert.equal(summary.total,10);
 assert.equal(summary.counts.DONE+summary.counts.IN_PROGRESS+summary.counts.READY+summary.counts.BLOCKED,10);
 assert.ok(summary.percentage>=0 && summary.percentage<=100);
 assert.equal(summary.owners.find(x=>x.name==="Shabaz").total,4);
 assert.equal(summary.owners.find(x=>x.name==="Rahil").total,6);
});
test("all-TODO baseline correctly displays readiness and blocks",()=>{
 const rows=buildTaskRows(mf,initial),s=summarize(rows);
 assert.equal(s.counts.DONE,0);
 assert.equal(s.counts.READY,1);
 assert.equal(s.counts.BLOCKED,9);
 assert.deepEqual(rows.filter(x=>x.displayState==="READY").map(x=>x.id),["V2-001"]);
});
test("V2 ready tasks unlock only when prerequisite is DONE",()=>{
 const adjusted=structuredClone(initial);
 adjusted.tasks["V2-001"]={owner:"Shabaz",state:"DONE",evidence:"v2/evidence/V2-001.md",startedBy:"Shabaz",startedOn:"2026-11-01",completedBy:"Shabaz",completedOn:"2026-11-01"};
 const rows=buildTaskRows(mf,adjusted),summary=summarize(rows);
 assert.equal(summary.counts.DONE,1);
 assert.deepEqual(rows.filter(x=>x.displayState==="READY").map(x=>x.id),["V2-002","V2-003","V2-004"]);
 assert.equal(summary.counts.BLOCKED,6);
});
test("V2 progress refuses missing statuses and premature completion",()=>{
 const missing=structuredClone(initial);delete missing.tasks["V2-003"];
 assert.throws(()=>buildTaskRows(mf,missing),/disagree/);
 const bad=structuredClone(initial);bad.tasks["V2-005"].state="DONE";
 assert.throws(()=>buildTaskRows(mf,bad),/prerequisites/);
});
test("V2 task gate validates published task metadata",()=>{
 const result=spawnSync(process.execPath,["scripts/v2-gate.mjs","validate"],{cwd:root,encoding:"utf8"});
 assert.equal(result.status,0,result.stderr);
 assert.match(result.stdout,/PASS: 10 V2 tasks/);
});
