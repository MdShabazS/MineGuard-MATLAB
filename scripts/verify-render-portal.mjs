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
const requireCurrent = process.argv.includes("--require-current") || process.env.PORTAL_REQUIRE_CURRENT==="1";
const result = {site:site.href, checked_at_utc:new Date().toISOString(), checks:{},
  deployment_check_mode:requireCurrent?"strict post-deployment":"advisory pre-deployment"};
const html = await get(site.href, "text/html");
if (!html.includes("MineGuard") || !/src="\.\/app\.mjs(?:\?[^"]*)?"/.test(html) || !/href="\.\/styles\.css(?:\?[^"]*)?"/.test(html)) {
  fail("Root HTML is not the MineGuard Guide Observatory");
}
result.checks.homepage = "PASS";
// On pull requests, the hosted Render page cannot yet include the proposed code.
 // A blocking remote check would deadlock Render's checksPass auto-deploy.
 // Require current deployment only AFTER Render has deployed the merged commit.
const roadmapPresent=html.includes('id="enhancementsTitle"') && html.includes('id="roadmapBreakdown"') && html.includes('id="roadmapItems"');
const buildMatch=html.match(/<meta name="mineguard-portal-build" content="([^"]+)"/);
if (!roadmapPresent || !buildMatch) {
  const why="DEPLOYMENT OUTDATED: live Render HTML does not include the required roadmap and build marker. Deploy latest main on Render.";
  if (requireCurrent) fail(why);
  result.checks.enhancement_deployment="NOT_YET_DEPLOYED (advisory pre-deploy)";
  result.notes=why+" This non-strict CI check does not assert the proposed portal is live.";
  process.stdout.write(JSON.stringify(result,null,2)+"\\n");
  process.exit(0);
}
result.portal_build=buildMatch[1];
result.checks.enhancement_html="PASS";
const app = await get(new URL("./app.mjs",site), "javascript");
if (!app.includes('raw.githubusercontent.com/') || !app.includes('tasks/status.json') || !app.includes('tasks/manifest.json') || !app.includes('getPublishedWithFallback') || !app.includes('refreshEnhancements')) {
  fail("Served app.mjs does not contain GitHub main-branch task data fetch");
}
result.checks.client_code = "PASS";
const snapshotText=await get(new URL("./data/enhancements.json",site),"json");
const enh=JSON.parse(snapshotText);
const ids=enh.items?.map(item=>item.id)||[];
if (ids.length!==11 || new Set(ids).size!==11 || !ids.includes("ENH-008") || !ids.includes("ENH-011")) {
  fail("Deployed enhancement snapshot is missing valid ENH-001..011 records.");
}
result.checks.enhancement_snapshot="PASS";
result.enhancement_count=ids.length;
const [v2ManifestText,v2StatusText]=await Promise.all([
  get(new URL("./data/v2-manifest.json",site),"json"),
  get(new URL("./data/v2-status.json",site),"json")
]);
const v2Manifest=JSON.parse(v2ManifestText),v2Status=JSON.parse(v2StatusText);
const v2Ids=Object.keys(v2Manifest.tasks||{});
if(v2Ids.length!==10 || v2Ids.some(id=>!v2Status.tasks?.[id])) fail("Invalid deployed V2 status snapshot.");
result.checks.v2_status_snapshot="PASS";
result.v2_snapshot_done_count=v2Ids.filter(id=>v2Status.tasks[id].state==="DONE").length;
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
const idsV1=Object.keys(manifest.tasks);
if (!idsV1.length || idsV1.some(id=>!(id in status.tasks))) fail("GitHub main task ID sets do not match");
result.checks.github_main_task_data="PASS";
result.github_main_task_count=idsV1.length;
result.github_main_done_count=idsV1.filter(id=>status.tasks[id].state==="DONE").length;
result.notes="Remote HTTP/source smoke check for a DEPLOYED 11-entry roadmap and 10-task V2 snapshot, not a browser rendering test or proof the remote GitHub live fetch succeeds. The bundled status can lag GitHub main and must be labelled as a snapshot. MG-021 browser QA remains separate.";
process.stdout.write(JSON.stringify(result,null,2)+"\n");
