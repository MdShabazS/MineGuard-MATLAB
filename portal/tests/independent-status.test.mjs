import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const read = p=>fs.readFileSync(new URL(p,import.meta.url),"utf8");
const json = p=>JSON.parse(read(p));
const app=read("../app.mjs"),html=read("../index.html"),smoke=read("../../scripts/verify-render-portal.mjs");
const sourceEnh=json("../../v2/roadmap/enhancements.json"),localEnh=json("../data/enhancements.json");
const sourceManifest=json("../../v2/tasks/manifest.json"),localManifest=json("../data/v2-manifest.json");
const sourceStatus=json("../../v2/tasks/status.json"),localStatus=json("../data/v2-status.json");

test("V2 and ENH refresh independently of V1 legacy fetch",()=>{
  const start=app.indexOf("async function refresh() {");
  const end=app.indexOf('el("refresh").addEventListener(',start);
  const body=app.slice(start,end);
  const startIndependent=body.indexOf("const independent=Promise.allSettled([refreshV2(),refreshEnhancements()]);");
  const startLegacy=body.indexOf('getJson(RAW+"tasks/manifest.json")');
  assert.ok(startIndependent>=0 && startIndependent<startLegacy,"V2 and ENH must launch before legacy V1 may throw");
  assert.match(body,/finally\s*\{\s*await independent;/);
  assert.doesNotMatch(body,/\sawait refreshV2\(\);/);
  assert.doesNotMatch(body,/\sawait refreshEnhancements\(\);/);
});

test("snapshots preserve published main data without fabricating DONE",()=>{
  assert.deepEqual(localEnh,sourceEnh);
  assert.deepEqual(localManifest,sourceManifest);
  assert.equal(sourceEnh.items.length,11);
  assert.deepEqual(localEnh.items.map(x=>x.id),Array.from({length:11},(_,i)=>`ENH-${String(i+1).padStart(3,"0")}`));
  assert.deepEqual(Object.keys(localStatus.tasks),Object.keys(sourceStatus.tasks));
  for(const id of Object.keys(localStatus.tasks)){
    const snapshot=localStatus.tasks[id];
    assert.ok(["TODO","IN_PROGRESS","DONE"].includes(snapshot.state));
    // The static fallback cannot invent a more advanced status than current main.
    if(snapshot.state==="DONE")assert.equal(sourceStatus.tasks[id].state,"DONE");
  }
});

test("fallback provenance says stale when live GitHub is inaccessible",()=>{
  assert.match(app,/getPublishedWithFallback\(/);
  assert.match(app,/deployed GitHub-main snapshot \(live read unavailable; may be outdated\)/);
  assert.match(app,/\["v2\/roadmap\/enhancements.json"\],\["\.\/data\/enhancements.json"\]/);
  assert.match(app,/\["\.\/data\/v2-manifest.json","\.\/data\/v2-status.json"\]/);
  assert.match(app,/showEnhancements\(result.data\[0\],result.source\)/);
  assert.match(app,/showV2Data\(rows,result.source\)/);
});

test("a portal deployment must identify the build and include the roadmap",()=>{
  assert.match(html,/<meta name="mineguard-portal-build" content="2026-11-02-status-fix-1">/);
  assert.match(html,/id="roadmapBreakdown"/);
  assert.match(html,/id="enhancementsTitle"/);
  assert.match(html,/app\.mjs\?v=20261102-statusfix1/);
  assert.match(smoke,/DEPLOYMENT OUTDATED/);
  assert.match(smoke,/ENH-011/);
});
