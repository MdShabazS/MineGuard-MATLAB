#!/usr/bin/env node
/**
 * Live HTTPS check of the deployed guide dashboard (V22-T2). Node.js 22+, no credentials.
 * Run: node scripts/verify-render-portal.mjs https://mineguard-guide-portal.onrender.com/ [--require-current]
 * Without --require-current an outdated deployment is reported as advisory (Render deploys only after merge).
 * This checks served files and the public GitHub task records; it is not a browser rendering test.
 */
import process from "node:process";

const fail = message => { throw new Error(message); };
const raw = process.argv[2];
if (!raw) fail("Usage: node scripts/verify-render-portal.mjs https://<render-site>/ [--require-current]");
let site;
try { site = new URL(raw); } catch { fail("Invalid site URL"); }
if (site.protocol !== "https:" || site.username || site.password || site.search || site.hash || site.pathname !== "/") fail("Supply only the HTTPS root URL");
const repo = "MdShabazS/MineGuard-MATLAB";
const requireCurrent = process.argv.includes("--require-current") || process.env.PORTAL_REQUIRE_CURRENT === "1";
async function get(url, type) {
  const res = await fetch(url, {redirect: "follow", signal: AbortSignal.timeout(20000), cache: "no-store"});
  if (!res.ok) fail(url + " returned HTTP " + res.status);
  const ct = res.headers.get("content-type") || "";
  if (type && !ct.toLowerCase().includes(type)) fail(url + " wrong content-type: " + ct);
  return res.text();
}
const result = {site: site.href, checked_at_utc: new Date().toISOString(), mode: requireCurrent ? "strict post-deployment" : "advisory pre-deployment", checks: {}};
const html = await get(site.href, "text/html");
if (!html.includes("MineGuard")) fail("Root HTML is not a MineGuard page");
const build = html.match(/<meta name="mineguard-dashboard" content="([^"]+)"/);
if (!build) {
  const why = "DEPLOYMENT OUTDATED: the live page is not the V2.2 live dashboard yet.";
  if (requireCurrent) fail(why);
  result.checks.dashboard = "NOT_YET_DEPLOYED (advisory)"; result.notes = why;
  process.stdout.write(JSON.stringify(result, null, 2) + "\n"); process.exit(0);
}
result.dashboard_build = build[1];
for (const id of ["people", "taskRows", "doneCount", "lastChecked"]) if (!html.includes('id="' + id + '"')) fail("Dashboard HTML missing #" + id);
result.checks.html = "PASS";
const app = await get(new URL("./app.mjs", site), "javascript");
if (!app.includes("/pulls?state=open") || !app.includes("raw.githubusercontent.com/")) fail("Served app.mjs does not read live GitHub data");
const core = await get(new URL("./core.mjs", site), "javascript");
if (!core.includes(repo) || !core.includes("v2_2/tasks/manifest.json")) fail("Served core.mjs does not read the V2.2 task records");
const css = await get(new URL("./styles.css", site), "text/css");
if (!css.includes(".people")) fail("Served stylesheet is not the dashboard stylesheet");
result.checks.client = "PASS";
const base = "https://raw.githubusercontent.com/" + repo + "/main/";
const [mf, st] = (await Promise.all([get(base + "v2_2/tasks/manifest.json"), get(base + "v2_2/tasks/status.json")])).map(JSON.parse);
const ids = Object.keys(mf.tasks || {});
if (!ids.length || ids.some(id => !st.tasks?.[id])) fail("GitHub main V2.2 task records are invalid");
result.checks.github_records = "PASS";
result.v22_tasks = ids.length;
result.v22_done = ids.filter(id => st.tasks[id].state === "DONE").length;
process.stdout.write(JSON.stringify(result, null, 2) + "\n");
