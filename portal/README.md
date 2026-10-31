# MineGuard Guide Observatory (static, read-only)

A guide-facing status portal sourced from the **authoritative GitHub `main` branch**. No logins, tokens, additional database or manual status entries. It shows accurate task completion, activity, blockers, owner progress, pull requests, CI summary, evidence links, final deadline and project limitations.

## Data integrity and refresh
- Work journal: `tasks/updates.json` on `main` holds AI-updated concise daily progress, next steps and evidence links. Initial log is empty; no fake entry is displayed.\n- Source of truth: `tasks/manifest.json` + `tasks/status.json` from `main`. A task is BLOCKED when TODO and one or more explicit dependencies are not DONE.
- The portal never invents task completion. If the foundation PR is not merged, the page prominently displays **task status unavailable** and links to PR #1.
- Auto-refresh is 5 minutes while visible, plus on manual request or returning to tab. Latest-check time is a **fetch timestamp**, not the last project update.
- PRs, Actions and commits use GitHub's unauthenticated REST API. Public unauthenticated requests are capped (typically 60/hour/IP), so activity feeds may temporarily be unavailable. Task board can still work. All data are public and read-only.
- GitHub CI status proves workflow checks only; local MATLAB execution requires separate evidence committed to GitHub.
- **Security:** no GitHub token stored in browser. Public data only; no private student/lab information.

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

## Limitations
No notifications, approvals, or access-controlled student dashboard. No background sync guarantee; the guide must open the site (it refreshes while visible). Changes are only visible after committed status on GitHub main.

## Portal deployment and verification tasks
- `MG-020`: guide-facing Render Static Site with real URL and first actual fetch evidence, after MG-000 foundation merged.
- `MG-021`: test the real HTTPS site on desktop and phone, verify filters, source-of-truth main, warnings, PR and CI feeds and screenshot/log proof. No false claim of deployment or QA before evidence.
- CI on the portal must select the latest `main`-branch Task Gate run, not report a successful unmerged PR check as main's status.
