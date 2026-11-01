import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
const html=fs.readFileSync(new URL("../index.html",import.meta.url),"utf8");
const app=fs.readFileSync(new URL("../app.mjs",import.meta.url),"utf8");
const core=fs.readFileSync(new URL("../core.mjs",import.meta.url),"utf8");
test("guide portal has every DOM element used by its controller",()=>{
 const ids=new Set([...html.matchAll(/id="([^"]+)"/g)].map(m=>m[1]));
 const used=[...app.matchAll(/el\("([^"]+)"\)/g)].map(m=>m[1]);
 const absent=[...new Set(used)].filter(id=>!ids.has(id));
 assert.deepEqual(absent,[]);
});
test("guide portal only reads merged main task records and never embeds credentials",()=>{
 assert.match(app,/RAW\+"tasks\/manifest\.json"/);
 assert.match(app,/RAW\+"tasks\/status\.json"/);
 assert.match(core,/head_branch==="main"/);
 assert.doesNotMatch(html+app,/github_pat_|ghp_[a-zA-Z0-9]{20,}|Bearer\s+[A-Za-z0-9_.-]{20,}/);
});
test("Render guide portal has status, blockers, ownership and evidence sections",()=>{
 for(const id of ["doneCount","activeCount","blockedCount","readyCount","owners","taskRows","ciStatus","updates","pullRequests","activity"])assert.match(html,new RegExp('id="'+id+'"'));
});

test("unmerged V2 activity is labelled separately from authoritative GitHub task state",()=>{
  const journal=JSON.parse(fs.readFileSync(new URL("../../tasks/updates.json",import.meta.url),"utf8"));
  const notes=journal.updates.filter(entry=>["V2-006","V2-007"].includes(entry.task));
  assert.equal(notes.length,2);
  assert.ok(notes.every(entry=>entry.summary.includes("not yet merged") || entry.summary.includes("not yet verified or merged")));
  assert.match(app,/workNote && task\.displayState==="READY"/);
  assert.match(app,/Local work reported · not yet merged into GitHub main/);
  assert.match(app,/if\(v2Rows\.length\)showV2Tasks\(v2Rows\)/);
  assert.match(app,/getJson\(RAW\+"v2\/tasks\/status\.json"\)/);
});
