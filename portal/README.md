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
