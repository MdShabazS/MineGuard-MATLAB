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
  assert.equal(items.length, 7);
  assert.equal(new Set(items.map(x=>x.id)).size, items.length);
  assert.ok(items.every(x => x.id.startsWith("ENH-")));
  assert.ok(items.every(x => x.status !== "DONE"));
  assert.match(enhancementLabel("DRAFT_UNVERIFIED"), /not MATLAB-verified/);
  assert.match(enhancementLabel("LOCAL_UNPUBLISHED"), /not published/);
});

test("proposal and local display fix cannot inflate authoritative V2 percent", () => {
  const official = buildTaskRows(manifest, status);
  const metrics = summarize(official);
  assert.equal(metrics.total, 10);
  assert.equal(metrics.counts.DONE, 5);
  assert.equal(metrics.percentage, 50);
  assert.deepEqual(Object.keys(status.tasks), Object.keys(manifest.tasks));
  assert.ok(!Object.keys(status.tasks).some(x=>x.startsWith("ENH-")));
  assert.match(app, /const s=summarize\(rows\)/);
  assert.match(app, /await refreshEnhancements\(\)/);
});

test("portal has a separate roadmap section, linked only to merged main roadmap data", () => {
  for (const id of ["enhancementsTitle","roadmapStatus","roadmapItems"]) {
    assert.match(html,new RegExp('id="'+id+'"'));
  }
  assert.match(app, /getJson\(RAW\+"v2\/roadmap\/enhancements\.json"\)/);
  assert.match(app, /validateEnhancements\(data\)/);
  assert.match(html,/separate from official V2 tasks|SEPARATE FROM OFFICIAL V2 TASKS/);
});

test("enhancement validator rejects duplicates, unsupported statuses and external links", () => {
  const cloned = structuredClone(roadmap);
  cloned.items.push({...cloned.items[0]});
  assert.throws(()=>validateEnhancements(cloned),/Duplicate/);
  const wrong = structuredClone(roadmap);
  wrong.items[0].status="DONE";
  assert.throws(()=>validateEnhancements(wrong),/status/);
  const external = structuredClone(roadmap);
  external.items[0].url="https://elsewhere.example.com/tracker";
  assert.throws(()=>validateEnhancements(external),/URL/);
});
