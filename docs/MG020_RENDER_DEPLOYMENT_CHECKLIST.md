# MG-020 — Render Static Site deployment and first HTTPS verification

Task: MG-020
Owner: Shabaz
Date: 2026-10-31
Type: Deployment handoff / evidence checklist

## Task completion rule

MG-020 is **NOT DONE** until the guide portal is actually deployed on Render, its **actual** Render-supplied HTTPS URL has been recorded, the first HTTP/HTTPS fetch and public GitHub main JSON reachability check have passed, and a reviewed GitHub completion PR is merged. A committed `render.yaml`, green Task Gate or claimed unverified URL is not deployment evidence.

The follow-up **MG-021** separately covers **real browser and phone** UI/filter/live synchronization verification. The MG-020 smoke check does not substitute for MG-021.

## What is already prepared in this repository

- `portal/index.html`, `portal/styles.css`, `portal/app.mjs`, `portal/core.mjs` and `portal/tests/*.test.mjs`: read-only guide observatory displaying the GitHub `main` authoritative task states and evidence.
- `render.yaml`: Render static-site Blueprint, `main` branch, `portal` publish directory, build command for no-build static assets, auto-deploy **after CI passes**, basic browser security headers.
- `scripts/verify-render-portal.mjs`: post-deploy HTTPS and source-data smoke test (requires the **real** URL).
- Task Gate CI: Node syntax checks and portal unit tests. CI is **not** evidence that Render published the site.

## One-time Render dashboard action (account owner)

Use the [Render dashboard](https://dashboard.render.com/) or [Deploy to Render Blueprint](https://render.com/deploy?repo=https%3A%2F%2Fgithub.com%2FMdShabazS%2FMineGuard-MATLAB).

**Recommended: New → Blueprint** to import `render.yaml` from `MdShabazS/MineGuard-MATLAB`; review **only** the `mineguard-guide-portal` static service and confirm deployment. (Alternatively **New → Static Site** and connect the same repository manually.)

For manual Static Site creation set:

| Render setting | Value |
|---|---|
| Repository | `MdShabazS/MineGuard-MATLAB` |
| Branch | `main` |
| Service type / runtime | **Static Site**, not Web Service/Node runtime |
| Root directory | empty (repo root) |
| Build command | `echo "Static portal: no build required; Task Gate checks source and tests"` |
| Publish directory | `portal` |
| Automatic deployment | After CI checks pass (if available), else deploy on commit |
| API keys, environment variables, database | **none required** |

Read the Render deployment log; it must show a successful deploy from `main`. Render supplies an actual unique **`https://…onrender.com/` URL** on its service details page. **Do not infer it from the Blueprint service name** and do not enter a guessed URL into project docs.

This is a public read-only status page. Do not enter GitHub PAT, Render API key or student confidential data into the public site or repo. The portal does not run the MATLAB mission dashboard.

## HTTPS verification immediately after the deploy

From a machine with Node.js 22+ and a real network connection, after checking out a commit with this script:

```bash
node --check scripts/verify-render-portal.mjs
node --test portal/tests/*.test.mjs
node scripts/verify-render-portal.mjs "https://ACTUAL-SERVICE.onrender.com/"
```

Replace the uppercase placeholder with the **exact URL Render provides**. The verifier checks:

1. A successful HTTPS response with the expected MineGuard HTML and static asset references.
2. Served JavaScript and stylesheet, not a Render error page.
3. The served app's data source is the public GitHub main branch.
4. Live public `tasks/manifest.json` and `tasks/status.json` JSON from `raw.githubusercontent.com` are accessible and have matching task IDs.
5. UTC check timestamp and actual public-main task summary are emitted as JSON.

**Record the actual script JSON output**, full checked URL, Render deployment status/commit, reviewer and test time. If something fails, capture the honest error, fix the configuration on a reviewed branch and rerun. Do not mark MG-020 complete on a failed fetch.

Then manually load the actual website once and confirm visible title plus the live task board or a transparent fetch warning. Save the tested service URL and evidence timestamp in `tasks/evidence/MG-020.md`.

## Final GitHub completion workflow

1. Merge the MG-020 implementation/deployment-readiness PR after its Task Gate CI passes. The task may be **IN_PROGRESS** on main.
2. Only after the real deployment and verification are proven, update this doc/evidence with the real (not guessed) Render URL, deploy SHA, check timestamp, exact command/output and any warnings.
3. Open a distinct `task/MG-020-complete` PR that updates **only MG-020** `IN_PROGRESS → DONE`, `evidence: tasks/evidence/MG-020.md`, and completion metadata; include any required finalized evidence amendments in that reviewed PR.
4. Wait for GitHub Task Gate success; only Shabaz/reviewer authorizes merging. Verify DONE on `main`.
5. MG-021 then becomes READY for independent desktop/mobile and live main-branch synchronization checks. No untested browser claim is allowed.

## Relevant provider and project documentation

- Render Blueprint spec: https://render.com/docs/blueprint-spec
- Render static site deployment: https://render.com/docs/static-sites
- Render CI-gated auto-deploy: https://render.com/docs/deploys
- Project portal: [../portal/README.md](../portal/README.md)
- Repo task policy: [WORKFLOW.md](WORKFLOW.md)

**Scientific disclosure:** MineGuard-MATLAB is an academic synthetic simulation. Portal status does not validate any real mine detector or field safety.
