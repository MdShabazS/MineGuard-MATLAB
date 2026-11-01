import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {validateEnhancements, enhancementLabel} from "../enhancements.mjs";
import {buildTaskRows, summarize} from "../core.mjs";

const json = (relative) => JSON.parse(fs.readFileSync(new URL(relative, import.meta.url),"utf8"));
const roadmap = json("../../v2/roadmap/enhancements.json");
const manifest = json("../../v2/tasks/manifest.json");
const status = json("../../v2/tasks/status.json");
const html = fs.readFileSync(new URL("../index.html", import.meta.url),"utf8");
const app = fs.readFileSync(new URL("../app.mjs", import.meta.url),"utf8");

test("enhancement entries are all distinct, public, and never falsely DONE", () => {
  const items = validateEnhancements(roadmap);
  assert.equal(items.length, 11);
  assert.equal(items.filter(item=>item.category==="engineering").length,7);
  assert.equal(items.filter(item=>item.category==="campus").length,4);
  assert.deepEqual(items.filter(item=>item.category==="campus").map(x=>x.id),["ENH-008","ENH-009","ENH-010","ENH-011"]);
  assert.equal(new Set(items.map(x=>x.id)).size, items.length);
  assert.ok(items.every(x => x.id.startsWith("ENH-")));
  assert.ok(items.every(x => x.status !== "DONE"));
  assert.match(enhancementLabel("DRAFT_UNVERIFIED"), /not MATLAB-verified/);
  assert.match(enhancementLabel("LOCAL_UNPUBLISHED"), /not published/);
  assert.match(enhancementLabel("TESTED_BLOCKED"), /acceptance blocked/);
  assert.match(enhancementLabel("MERGED_IN_BRANCH"), /not released/);
  assert.equal(items.find(item=>item.id==="ENH-002").status,"TESTED_BLOCKED");
  assert.equal(items.find(item=>item.id==="ENH-007").status,"MERGED_IN_BRANCH");
  assert.ok(items.filter(x=>x.category==="campus").every(x=>x.url.includes("/issues/")));
});

test("proposal and local display fix cannot inflate authoritative V2 percent", () => {
  const official = buildTaskRows(manifest, status);
  const metrics = summarize(official);
  assert.equal(metrics.total, 10);
  const actualDone = Object.values(status.tasks).filter(x=>x.state==="DONE").length;
  assert.equal(metrics.counts.DONE, actualDone);
  assert.equal(metrics.percentage, Math.round(100*actualDone/metrics.total));
  assert.deepEqual(Object.keys(status.tasks), Object.keys(manifest.tasks));
  assert.ok(!Object.keys(status.tasks).some(x=>x.startsWith("ENH-")));
  assert.match(app, /const s=summarize\(rows\)/);
  assert.match(app, /await refreshEnhancements\(\)/);
});

test("portal has a separate roadmap section, linked only to merged main roadmap data", () => {
  for (const id of ["enhancementsTitle","roadmapStatus","roadmapBreakdown","roadmapItems"]) {
    assert.match(html,new RegExp('id="'+id+'"'));
  }
  assert.match(app, /getPublishedWithFallback\(/);
  assert.match(app, /\["v2\/roadmap\/enhancements\.json"\]/);
  assert.match(app, /"\.\/data\/enhancements\.json"/);
  assert.match(app, /validateEnhancements\(data\)/);
  assert.match(app, /enhancement-group-grid/);
  assert.match(app, /item.category===group.id/);
  assert.match(html,/separate from official V2 tasks|SEPARATE FROM OFFICIAL V2 TASKS/);
});

test("enhancement validator rejects duplicates, unsupported statuses and external links", () => {
  const cloned = structuredClone(roadmap);
  cloned.items.push({...cloned.items[0]});
  assert.throws(()=>validateEnhancements(cloned),/Duplicate/);
  const wrong = structuredClone(roadmap);
  wrong.items[0].status="DONE";
  assert.throws(()=>validateEnhancements(wrong),/status/);
  const wrongGroup=structuredClone(roadmap);
  wrongGroup.items[0].category="unknown";
  assert.throws(()=>validateEnhancements(wrongGroup),/status/);
  const external = structuredClone(roadmap);
  external.items[0].url="https://elsewhere.example.com/tracker";
  assert.throws(()=>validateEnhancements(external),/URL/);
});

test("BITM tasks preserve safety and distribution gates", () => {
  const campus=validateEnhancements(roadmap).filter(x=>x.category==="campus");
  assert.equal(campus.length,4);
  for(const item of campus)assert.ok(item.dependency.length>30);
  assert.match(campus.find(x=>x.id==="ENH-008").detail,/no real-campus anomaly markers/);
  assert.match(campus.find(x=>x.id==="ENH-009").detail,/source terms permit download/);
  assert.equal(campus.find(x=>x.id==="ENH-009").status,"BLOCKED");
  assert.equal(campus.find(x=>x.id==="ENH-011").status,"BLOCKED");
});
