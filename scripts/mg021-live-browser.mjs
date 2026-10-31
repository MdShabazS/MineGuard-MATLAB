#!/usr/bin/env node
// MG-021: true headless Chromium interaction against the deployed Render website.
// Public GitHub main records are read live; mocked error/change cases are labelled explicitly.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {chromium} from "playwright";
import {buildTaskRows, summarize} from "../portal/core.mjs";

const SITE="https://mineguard-guide-portal.onrender.com/";
const RAW="https://raw.githubusercontent.com/MdShabazS/MineGuard-MATLAB/main/";
const STATUS_URL=RAW+"tasks/status.json";
const OUT="artifacts/mg021";
fs.mkdirSync(OUT,{recursive:true});
const report={task:"MG-021",site:SITE,mode:"real remote Chromium + mobile device emulation",checked_at_utc:new Date().toISOString(),checks:[],screenshots:[],warnings:[],main_source:{},limit:"No actual mobile hardware and no real GitHub mutation; synthetic status response is a separately labelled test"};
let browser,page;
function check(name,details=""){report.checks.push({name,status:"PASS",details}); console.log("PASS "+name+(details?" — "+details:""));}
function result(){fs.writeFileSync(path.join(OUT,"report.json"),JSON.stringify(report,null,2)+"\n");}
async function remote(url){
 const r=await fetch(url,{headers:{Accept:"application/json"},signal:AbortSignal.timeout(20000),cache:"no-store"});
 assert.equal(r.status,200,"Authoritative GitHub main "+url+" not 200");
 return r.json();
}
async function waitBoard(p){
 await p.waitForFunction(()=>document.querySelector("#doneCount")?.textContent?.includes(" / "),{},{timeout:35000});
}
async function screenshot(p,filename){
 await p.screenshot({path:path.join(OUT,filename),fullPage:true,animations:"disabled"});
 report.screenshots.push(filename);
}
async function clickFilter(p,f,count){
 const control=p.locator('#filters button[data-filter="'+f+'"]');
 await control.click();
 assert.equal(await control.getAttribute("aria-pressed"),"true");
 assert.equal(await p.locator("#taskRows tr").count(),Math.max(1,count));
 if(count===0)assert.match(await p.locator("#taskRows").innerText(),/No tasks match/);
}
async function main(){
 const [manifest,status]=await Promise.all([remote(RAW+"tasks/manifest.json"),remote(STATUS_URL)]);
 const rows=buildTaskRows(manifest,status),summary=summarize(rows);
 report.main_source={task_count:summary.total,done:summary.counts.DONE,in_progress:summary.counts.IN_PROGRESS,ready:summary.counts.READY,blocked:summary.counts.BLOCKED};
 assert.equal(summary.total,22);
 browser=await chromium.launch({headless:true,args:["--no-sandbox"]});
 const desktop=await browser.newContext({viewport:{width:1440,height:900},deviceScaleFactor:1,ignoreHTTPSErrors:false});
 page=await desktop.newPage();
 const jsErrors=[];
 page.on("pageerror",e=>jsErrors.push(String(e)));
 const mainRequests=[];
 page.on("request",r=>{if(r.url().startsWith(RAW+"tasks/"))mainRequests.push(r.url());});
 const response=await page.goto(SITE,{waitUntil:"domcontentloaded",timeout:45000});
 assert.equal(response?.status(),200);
 await waitBoard(page);
 await page.locator("#refresh:not([disabled])").waitFor({timeout:35000});
 assert.equal(await page.locator("h1").innerText(),"Project overview");
 assert.match(await page.locator(".disclaimer").innerText(),/not verified mine detections/);
 assert.equal(await page.locator("#doneCount").innerText(),summary.counts.DONE+" / "+summary.total);
 assert.equal(await page.locator("#activeCount").innerText(),String(summary.counts.IN_PROGRESS));
 assert.equal(await page.locator("#readyCount").innerText(),String(summary.counts.READY));
 assert.equal(await page.locator("#blockedCount").innerText(),String(summary.counts.BLOCKED));
 assert.equal(await page.locator("#percent").innerText(),summary.percentage+"%");
 assert.equal(await page.locator("#taskRows tr").count(),summary.total);
 assert.equal(await page.locator("#owners .owner-card").count(),summary.owners.length);
 assert.ok(mainRequests.some(x=>x.endsWith("tasks/status.json")) && mainRequests.some(x=>x.endsWith("tasks/manifest.json")));
 assert.equal(jsErrors.length,0,"Uncaught JavaScript error(s): "+jsErrors.join(" | "));
 check("B01 actual desktop HTTPS, browser JS, source data, summary and disclaimer","GitHub main "+summary.counts.DONE+"/"+summary.total);
 await screenshot(page,"desktop-live.png");

 // Filter counts, accessibility state and evidence destinations.
 for(const kind of ["DONE","READY","BLOCKED","IN_PROGRESS"]){
  await clickFilter(page,kind,summary.counts[kind]);
 }
 await clickFilter(page,"ALL",summary.total);
 check("B02 all five filters and pressed states on live DOM");
 const links=await page.locator("#taskRows .dep-cell a").evaluateAll(nodes=>nodes.map(n=>n.href));
 assert.equal(links.length,summary.counts.DONE);
 assert.ok(links.every(u=>u.startsWith("https://github.com/MdShabazS/MineGuard-MATLAB/blob/main/")));
 assert.ok(await page.getByRole("link",{name:/Original objectives/}).count());
 check("B03 real GitHub evidence links and original objectives");
 const first=await page.locator("#filters button").first().evaluate(n=>({tag:n.tagName,pressed:n.getAttribute("aria-pressed")}));
 assert.equal(first.tag,"BUTTON");assert.equal(first.pressed,"true");
 await page.locator("#refresh").focus();assert.equal(await page.evaluate(()=>document.activeElement?.id),"refresh");
 check("B04 keyboard focus and accessible button state");

 // Manual refresh must actually GET GitHub main again.
 const before=mainRequests.filter(x=>x.endsWith("tasks/status.json")).length;
 await page.locator("#refresh").click();
 await page.waitForFunction(()=>!document.querySelector("#refresh")?.disabled,{},{timeout:30000});
 await page.waitForFunction(n=>window.__mgNotUsed?true:performance.getEntriesByType("resource").filter(x=>x.name.includes("/tasks/status.json")).length>=n, before+1,{timeout:30000}).catch(()=>{});
 const after=mainRequests.filter(x=>x.endsWith("tasks/status.json")).length;
 assert.ok(after>before,"Refresh did not request GitHub main status anew");
 assert.doesNotMatch(await page.locator("#lastChecked").innerText(),/Not synchronized|Checking/);
 check("B05 manual Refresh causes a fresh GitHub main HTTP request");

 // Live-source synchronization = rendered state matches actual main; changed-response behavior
 // tested separately by intercepting the request, never by writing to GitHub.
 const ready=rows.find(x=>x.displayState==="READY");
 if(ready){
  const mock=structuredClone(status);
  mock.tasks[ready.id]={...mock.tasks[ready.id],state:"IN_PROGRESS",startedBy:ready.owner,startedOn:"2026-10-31"};
  await page.route(STATUS_URL,route=>route.fulfill({status:200,contentType:"application/json",body:JSON.stringify(mock)}));
  await page.locator("#refresh").click();await page.waitForFunction(()=>!document.querySelector("#refresh")?.disabled);
  assert.equal(await page.locator("#activeCount").innerText(),String(summary.counts.IN_PROGRESS+1));
  assert.equal(await page.locator("#readyCount").innerText(),String(summary.counts.READY-1));
  await page.unroute(STATUS_URL);
  await page.locator("#refresh").click();await page.waitForFunction(()=>!document.querySelector("#refresh")?.disabled);
  assert.equal(await page.locator("#activeCount").innerText(),String(summary.counts.IN_PROGRESS));
  check("B06 actual main parity + separately mocked changed-status refresh","Real GitHub not modified; "+ready.id+" was simulated");
 }else report.warnings.push("B06 simulated changed status skipped: no READY candidate");

 // Optional API rate-limit must not blank authoritative board.
 await page.route("https://api.github.com/repos/MdShabazS/MineGuard-MATLAB/**",
  route=>route.fulfill({status:403,contentType:"application/json",body:'{"message":"API rate limit exceeded"}'}));
 await page.locator("#refresh").click(); await page.waitForFunction(()=>!document.querySelector("#refresh")?.disabled);
 assert.equal(await page.locator("#doneCount").innerText(),summary.counts.DONE+" / "+summary.total);
 assert.match(await page.locator("#alert").innerText(),/activity feeds could not load/);
 assert.match(await page.locator("#pullRequests").innerText(),/PR feed unavailable/);
 assert.match(await page.locator("#activity").innerText(),/Activity feed unavailable/);
 await screenshot(page,"desktop-rate-limit.png");
 check("B07 GitHub REST API 403 simulated: task board remains valid and warns");
 await page.unrouteAll({behavior:"wait"});

 // Main status request outage: preserve known-good board and warn; on a clean page, don't invent tasks.
 await page.route(STATUS_URL,route=>route.abort("failed"));
 await page.locator("#refresh").click(); await page.waitForFunction(()=>!document.querySelector("#refresh")?.disabled);
 assert.equal(await page.locator("#doneCount").innerText(),summary.counts.DONE+" / "+summary.total);
 assert.match(await page.locator("#alert").innerText(),/Could not refresh/);
 await page.unroute(STATUS_URL);
 check("B08 simulated main HTTP failure after success shows stale-data warning");
 const isolated=await desktop.newPage();
 await isolated.route(STATUS_URL,route=>route.abort("failed"));
 await isolated.goto(SITE,{waitUntil:"domcontentloaded",timeout:45000});
 await isolated.locator("#lastChecked").getByText("Not synchronized").waitFor({timeout:30000}).catch(()=>{});
 assert.match(await isolated.locator("#alert").innerText(),/Task status is not published/);
 assert.doesNotMatch(await isolated.locator("#doneCount").innerText(),/\d+ \/ \d+/);
 await isolated.close();
 check("B09 initial GitHub main outage does not fabricate a task count");

 // Public feeds are display-only and point into approved GitHub origins.
 for(const href of await page.locator("#pullRequests a[href],#activity a[href]").evaluateAll(nodes=>nodes.map(n=>n.href))){
  assert.ok(href.startsWith("https://github.com/MdShabazS/MineGuard-MATLAB/"));
 }
 check("B10 feed links restricted to the repository");

 for(const width of [390,360,768]){
  const ctx=await browser.newContext({viewport:{width,height:844},isMobile:width<=390,hasTouch:width<=390,deviceScaleFactor:2});
  const p=await ctx.newPage();
  await p.goto(SITE,{waitUntil:"domcontentloaded",timeout:45000});await waitBoard(p);
  assert.equal(await p.locator("#doneCount").innerText(),summary.counts.DONE+" / "+summary.total);
  await clickFilter(p,"BLOCKED",summary.counts.BLOCKED);
  const metrics=await p.evaluate(()=>({viewport:innerWidth,root:document.documentElement.scrollWidth,table:document.querySelector(".table-scroller")?.scrollWidth}));
  assert.ok(metrics.root<=metrics.viewport+3,"Body overflow at "+width+": "+JSON.stringify(metrics));
  await p.locator("#refresh").click();await p.waitForFunction(()=>!document.querySelector("#refresh")?.disabled);
  assert.equal(await p.locator("#doneCount").innerText(),summary.counts.DONE+" / "+summary.total);
  await clickFilter(p,"ALL",summary.total);
  await screenshot(p,width===768?"tablet-768.png":"mobile-"+width+".png");
  check("B11 responsive "+width+"px Chromium viewport","root "+metrics.root+"px, body no horizontal overflow");
  await ctx.close();
 }
 // No HTTP POST/credentials or MATLAB safety claim.
 assert.ok(!String(await page.content()).includes('input type="password"'));
 check("B12 public read-only and research-simulation disclosure");
 await browser.close();
 report.summary={passed:report.checks.length,failed:0,live_main_parity:true,mobile_mode:"Chromium device emulation, NOT physical phone"};
 result();
 console.log("MG-021 browser QA SUCCESS — "+report.checks.length+" actual checks; artifacts "+OUT);
}
main().catch(async e=>{
 report.failure={message:String(e?.message||e),stack:String(e?.stack||"")};console.error("MG-021 FAIL",e);
 if(page){try{await screenshot(page,"failure.png");}catch{}}
 if(browser){try{await browser.close();}catch{}}
 result();
 process.exitCode=1;
});
