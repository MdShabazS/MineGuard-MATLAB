# MineGuard Guide Observatory (static, read-only)

A guide-facing status portal sourced from the **authoritative GitHub `main` branch**. No logins, tokens, additional database or manual status entries. It shows accurate task completion, activity, blockers, owner progress, pull requests, CI summary, evidence links, final deadline and project limitations.

## Advanced V2 continuation in the SAME portal

The portal at **https://mineguard-guide-portal.onrender.com/** now has two distinct tracking phases after this change is merged into `main`:

- **Advanced V2 (new top section):** `v2/tasks/manifest.json` + `v2/tasks/status.json` on `main`; ten new proposed tasks, with task ownership, dependency-aware READY/BLOCKED states, active work and evidence.
- **V1 research baseline (existing archive):** the original `tasks/manifest.json` + `tasks/status.json` on `main`; keeps all **22/22 V1 DONE** statuses and evidence unchanged.

V2 is deliberately shown separately so V1's 100% does **not** imply V2 is completed. V2 begins 0/10 DONE and must not be populated from an unmerged `v2/` branch. Until the PR merges and Render redeploys, the public guide continues to see only the previous version. No second portal, Render service, API credentials or database is created.

V2 governance: `node scripts/v2-gate.mjs validate` and `node scripts/v2-gate.mjs ready`; the existing Task Gate workflow also audits V2 PR transitions. The local, manually run 3-D feasibility demo is not represented as completed V2 engineering evidence. See [V2 scope and workflow](../v2/README.md).

## Data integrity and refresh
- Work journal: `tasks/updates.json` on `main` holds AI-updated concise daily progress, next steps and evidence links. Initial log is empty; no fake entry is displayed.\n- Source of truth: `tasks/manifest.json` + `tasks/status.json` from `main`. A task is BLOCKED when TODO and one or more explicit dependencies are not DONE.
- The portal never invents task completion. If the foundation PR is not merged, the page prominently displays **task status unavailable** and links to PR #1.
- Auto-refresh is 5 minutes while visible, plus on manual request or returning to tab. Latest-check time is a **fetch timestamp**, not the last project update.
- PRs, Actions and commits use GitHub's unauthenticated REST API. Public unauthenticated requests are capped (typically 60/hour/IP), so activity feeds may temporarily be unavailable. Task board can still work. All data are public and read-only.
- GitHub CI status proves workflow checks only; local MATLAB execution requires separate evidence committed to GitHub.
- **Security:** no GitHub token stored in browser. Public data only; no private student/lab information.

## MG-020 exact deployment and verification guide

The authoritative deployment/first-HTTPS-proof procedure is [docs/MG020_RENDER_DEPLOYMENT_CHECKLIST.md](../docs/MG020_RENDER_DEPLOYMENT_CHECKLIST.md). A reproducible post-deployment verifier is `scripts/verify-render-portal.mjs`. A successful GitHub Task Gate does **not** mean the site is live. Record the actual Render-supplied URL and smoke-test output in `tasks/evidence/MG-020.md` before marking MG-020 DONE.

**One-click deployment setup:** [Open the MineGuard Blueprint on Render](https://render.com/deploy?repo=https%3A%2F%2Fgithub.com%2FMdShabazS%2FMineGuard-MATLAB) (account holder confirms any service creation; this is not a verified live-site URL).

## Deploy on Render — FREE Static Site
1. Ensure foundation PR and portal code are merged into `main` through review.
2. Open https://dashboard.render.com/ → New → Static Site. Connect `MdShabazS/MineGuard-MATLAB`.
3. Branch: `main`; Root directory: blank; Build command: `echo "No build required"`; Publish directory: `portal`.
4. Deploy. Render supplies an `onrender.com` URL and redeploys for commits to main. No server process, database or API key.
5. Optional alternative: use the repository root `render.yaml` Blueprint for the same configuration.
6. Share URL with the college guide. Note that the site is **publicly viewable**, because the GitHub repository is public.

## Verify before linking guide
- GitHub CI: `node --test portal/tests/*.test.mjs` and `node --check portal/app.mjs`.
- Browser smoke test manually (actual browser, not asserted here): desktop/mobile, All/Blocked filters, refresh, evidence links, failure when main files absent, GitHub API limit/offline behaviour, accessibility.
- Check that `main` reflects merged task transitions. An unmerged branch must not influence visible progress.

## MG-021 executed live browser and mobile-viewport QA

On 2026-10-31, the real deployed portal passed **14/14** hosted Chromium assertions in [GitHub Actions run 41218473248](https://github.com/MdShabazS/MineGuard-MATLAB/actions/runs/41218473248), with downloadable desktop/tablet/mobile-view screenshots and `report.json`. The suite checks GitHub main-source parity, all filters, user refresh, evidence links, simulated rate limit and stale/unavailable source fallback. The mobile tests run in Chromium viewport/touch **emulation, not actual phone hardware**. A simulated changed status response is *not* proof of a real GitHub main mutation; post-merge verification is a separate explicit checkpoint. See [MG-021 evidence](../tasks/evidence/MG-021.md).

## Limitations
No notifications, approvals, or access-controlled student dashboard. No background sync guarantee; the guide must open the site (it refreshes while visible). Changes are only visible after committed status on GitHub main.

## Portal deployment and verification tasks
- `MG-020`: guide-facing Render Static Site with real URL and first actual fetch evidence, after MG-000 foundation merged.
- `MG-021`: test the real HTTPS site on desktop and phone, verify filters, source-of-truth main, warnings, PR and CI feeds and screenshot/log proof. No false claim of deployment or QA before evidence.
- CI on the portal must select the latest `main`-branch Task Gate run, not report a successful unmerged PR check as main's status.

## Optional V2 Mission Intelligence enhancement roadmap

A separately rendered section below the official ten-task V2 tracker shows the **non-authoritative** enhancement work in `v2/roadmap/enhancements.json`. It includes the evidence explorer/integration, optional satellite preview, Focus Mode, 3-D realism, replay/debrief, sensor input hardening and Mac demo theme fix.

- Enhancement identifiers are `ENH-001` etc., not new official V2 tasks. **Never add them to `v2/tasks/manifest.json` or infer a new official completion percentage from them.** V2 remains 5/10 DONE until accepted, task-gated merges alter the authoritative status.
- An entry may be marked `ACTIVE_UNMERGED`, `DRAFT_UNVERIFIED`, `PLANNED`, `BLOCKED` or `LOCAL_UNPUBLISHED`; **none means DONE**. For each update, verify associated issue/PR/test evidence and update the JSON on a reviewed branch. The portal does not auto-read unmerged PR status into roadmap state.
- The enhancement view is fetched from GitHub **main** only, every ordinary portal refresh. It fails safely if missing/invalid. A passing CI gate does not prove MATLAB, satellite tile, Render deployment or physical detector validation.
- The official V2 tracker, owners, journal and V1 historical archive are unaffected. One-time MATLAB satellite previews and locally tested display fixes are clearly reported as *unverified* or *not yet published*.
- Guide-site deployment follows the existing Render auto-deploy-from-main workflow; **publishing a PR alone does not update the live portal**.

### 2026-11-02: 11-entry enhancement roadmap and BITM campus demonstration

The guide portal's **Mission Intelligence enhancement roadmap** now groups seven engineering enhancements (`ENH-001..007`) and four BITM/Ballari college presentation enhancements (`ENH-008..011`), preserving the original official V2 task counts.

- Campus entries: [#78](https://github.com/MdShabazS/MineGuard-MATLAB/issues/78) for BITM simulated campus-context mode; [#79](https://github.com/MdShabazS/MineGuard-MATLAB/issues/79) for license-permitted offline imagery or fallback; [#80](https://github.com/MdShabazS/MineGuard-MATLAB/issues/80) for city-to-campus intro; [#81](https://github.com/MdShabazS/MineGuard-MATLAB/issues/81) for single-clock satellite/3-D synchronization.
- Each card provides an evidence/issue link, owner, P1/P2 priority, reviewed progress category, description and explicit next acceptance gate. The status breakdown is **not** a fabricated completion percentage.
- **Corrected engineering states:** ENH-002 is `TESTED_BLOCKED` because 7/7 Mac geographic tests and actual satellite imagery PASSED but attribution and light-theme readability FAILED; PR #75 is untested. ENH-007 is `MERGED_IN_BRANCH`, because the Mac correction was merged through PR #74 into PR #66's feature branch, **not** into `main`.
- The bridge remains not accepted: Windows reported 143/143 tests but integrated GUI performance was 0.54× and the full UI evidence-click flow is missing; issue #76 tracks performance.
- All ten original V2 statuses are still sourced independently from `v2/tasks/manifest.json` and `v2/tasks/status.json`. Enhancement categories and status labels are manually maintained by reviewed PRs, **not automatically synchronized** with GitHub issue states.
- Campus geographic imagery is **presentation context only**, not measured UAV telemetry, real suspected-mine locations or real-world georegistration. Do not download/rehost basemap tiles without provider permission. See [BITM/Ballari demonstration roadmap](../v2/docs/V2_BITM_BALLARI_PRESENTATION_ROADMAP.md).
- Portal refresh pulls only **GitHub `main`**. A PR needs Shabaz's merge and Render's redeploy before the guide-facing site displays its changes; actual live browser smoke test is a separate step.

