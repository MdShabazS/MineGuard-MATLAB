#!/usr/bin/env node
/**
 * MG-020 first-deploy HTTPS smoke check. Node.js 22+, no credentials.
 * Run: node scripts/verify-render-portal.mjs https://<actual-service>.onrender.com/
 * This verifies reachable static content and public GitHub main JSON.
 * Actual desktop/mobile browser QA belongs to MG-021.
 */
import process from "node:process";

const fail = (message) => { throw new Error(message); };
const raw = process.argv[2];
if (!raw) fail("Usage: node scripts/verify-render-portal.mjs https://<actual-render-URL>/");
let site;
try { site = new URL(raw); } catch { fail("Invalid HTTPS site URL"); }
if (site.protocol !== "https:" || site.username || site.password || site.search || site.hash || site.pathname !== "/") {
  fail("Supply only the verified HTTPS root URL; no credentials, path, query or fragment");
}

const expectedRepo = "MdShabazS/MineGuard-MATLAB";
const base = "https://raw.githubusercontent.com/" + expectedRepo + "/main/";
async function get(url, expectedContentType) {
  const res = await fetch(url, {redirect:"follow", signal:AbortSignal.timeout(20000), headers:{"Accept":"*/*"}, cache:"no-store"});
  if (!res.ok) fail(url + " returned HTTP " + res.status);
  const ct = res.headers.get("content-type") || "";
  if (expectedContentType && !ct.toLowerCase().includes(expectedContentType)) fail(url + " wrong content-type: " + ct);
  const body = await res.text();
  if (body.length < 40) fail(url + " unexpectedly empty");
  return body;
}
const result = {site:site.href, checked_at_utc:new Date().toISOString(), checks:{}};
const html = await get(site.href, "text/html");
if (!html.includes("MineGuard") || !html.includes('src="./app.mjs"') || !html.includes('href="./styles.css"')) {
  fail("Root HTML is not the MineGuard Guide Observatory");
}
result.checks.homepage = "PASS";
const app = await get(new URL("./app.mjs",site), "javascript");
if (!app.includes('raw.githubusercontent.com/') || !app.includes('tasks/status.json') || !app.includes('tasks/manifest.json')) {
  fail("Served app.mjs does not contain GitHub main-branch task data fetch");
}
result.checks.client_code = "PASS";
const core = await get(new URL("./core.mjs",site), "javascript");
if (!core.includes(expectedRepo) || !core.includes("buildTaskRows")) fail("Served core.mjs does not match expected repository");
result.checks.core_module = "PASS";
const css = await get(new URL("./styles.css",site), "text/css");
if (!css.includes("@media") || !css.includes(".shell")) fail("Served stylesheet failed sanity check");
result.checks.stylesheet = "PASS";
const [manifestText,statusText] = await Promise.all([
  get(base+"tasks/manifest.json",""),
  get(base+"tasks/status.json","")
]);
const manifest=JSON.parse(manifestText), status=JSON.parse(statusText);
if (manifest.schemaVersion!==1 || status.schemaVersion!==1 || !manifest.tasks || !status.tasks) {
  fail("GitHub main task schemas are not valid");
}
const ids=Object.keys(manifest.tasks);
if (!ids.length || ids.some(id=>!(id in status.tasks))) fail("GitHub main task ID sets do not match");
result.checks.github_main_task_data="PASS";
result.github_main_task_count=ids.length;
result.github_main_done_count=ids.filter(id=>status.tasks[id].state==="DONE").length;
result.notes="Remote HTTP and public GitHub raw-data smoke check only. MG-021 still requires independent browser/mobile and live-sync testing. Does not verify that JavaScript executed in a browser.";
process.stdout.write(JSON.stringify(result,null,2)+"\n");
