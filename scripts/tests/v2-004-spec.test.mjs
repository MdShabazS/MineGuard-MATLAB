import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"../..");
const read=p=>fs.readFileSync(path.join(root,p),"utf8");
const docs=[
 "v2/docs/V2_004_SENSOR_CONTRACTS.md",
 "v2/docs/V2_004_EVALUATION_PROTOCOL.md",
 "v2/docs/V2_004_VERIFICATION_MATRIX.md",
];
const [sensor,evaluation,verification]=docs.map(read);
const manifest=JSON.parse(read("v2/tasks/manifest.json"));

test("V2-004 substantive source-backed design docs exist and belong to Shabaz",()=>{
 assert.equal(manifest.tasks["V2-004"].owner,"Shabaz");
 assert.deepEqual(manifest.tasks["V2-004"].dependsOn,["V2-001"]);
 for(let i=0;i<docs.length;i++){
  assert.ok([sensor,evaluation,verification][i].length>5000,docs[i]+" unexpectedly short");
  assert.match([sensor,evaluation,verification][i],/https:\/\//);
 }
});
test("V2 sensor contract includes distinct RGB, numerical thermal, LiDAR, GPS and pose clock",()=>{
 for(const keyword of ["RGB_NADIR","THERMAL_LWIR","LIDAR_TERRAIN","VIRTUAL_GNSS_INS","temperature_K","T_world_sensor","pose_id","tick_id","mg-v2-sensors/1.0"]){
  assert.ok(sensor.includes(keyword),"Missing contract item "+keyword);
 }
 assert.match(sensor,/apparent-temperature/);
 assert.match(sensor,/NOT a calibrated IR camera/);
 assert.match(sensor,/cannot measure a buried object|not.*buried/i);
});
test("prespecified future checks remain numbered and comprehensive",()=>{
 const ids=[...verification.matchAll(/\|\s*(SC-\d{2})\s*\|/g)].map(m=>m[1]);
 assert.equal(ids.length,30);
 assert.equal(new Set(ids).size,30);
 assert.equal(ids[0],"SC-01");
 assert.equal(ids.at(-1),"SC-30");
 for(const id of ids)assert.match(verification,new RegExp(id.replace("-","-")));
});
test("evaluation protocol includes disjoint splits, falsification and original negative V1 evidence",()=>{
 for(const keyword of ["TRAIN","VALIDATION","HELD-OUT TEST","TargetTruth","counterfactual","TP 0, FP 26, TN 470, FN 4","undefined","SUSPECTED"]){
  assert.ok(evaluation.includes(keyword),"Missing evaluation item "+keyword);
 }
 assert.match(evaluation,/not a V2 baseline/i);
 assert.match(evaluation,/once after implementation freeze|one-time fresh held-out/i);
});
test("no V2 DOC claims MATLAB simulation tests were executed",()=>{
 assert.match(verification,/no MATLAB V2 sensor implementation tested/i);
 assert.match(evaluation,/no V2 inference model, trial, or held-out test executed/i);
 assert.match(sensor,/implementation and MATLAB execution are NOT claimed/i);
});
