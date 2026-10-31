# Decisions, Assumptions and Open Issues (as of 2026-10-31)

## Confirmed by user/guide
- Preserve **exact** original Phase-1 title, problem statement and four objectives. Only implementation becomes MATLAB/Simulink.
- Research-grade advanced virtual environment, thermal + metal-response simulation, hybrid mathematical+AI fusion, fixed-grid flight vs PPO, App Designer GCS.
- Full project final demonstration target **2026-11-02**. No skipped QA or false claims for schedule.
- Public new GitHub `MdShabazS/MineGuard-MATLAB`; old MineGuard repo unchanged.
- Shabaz owns ChatGPT-led research, documentation, project coordination and independent testing if available.
- Rahil owns Claude Code programming, MATLAB local execution and reproducible tests.
- PR review by other member, GitHub Actions task validation and dependency DAG. Independent work allowed when truly unblocked.
- Guide portal: Render Static Site, read-only GitHub task/evidence dashboard with owner progress, blockers, work journal and PR/CI.
- Rahil reports MATLAB Desktop installed on Windows; student licence available through college; exact version/toolboxes/activation not verified.

## Independently checked in connected GitHub
- New public repository exists and `MdRahilA` has **write** permission.
- Foundation PR #1 open on `setup/mg-000-foundation`, review requested from Rahil.
- PR GitHub Actions checks previously passed for DAG and four guide-portal tests; **not MATLAB**.
- Public repo ruleset not configured at last check; no authenticated Render deployment verified.

## Critical uncertainty
The Phase-1 objective says 'accurate subsurface detection' from airborne metal-coil+thermal. Physics imposes severe coil standoff and environmental limits. **Keep wording but explicitly explain unvalidated feasibility.**

## Unresolved decisions
See [OPEN_DECISIONS_AND_RISKS.md](OPEN_DECISIONS_AND_RISKS.md) for detailed risk log and required evidence. Changes to plan must go through reviewed PR, never silently alter Phase-1 baseline.

## Next milestone
Review/merge PR #1 after docs QA. Then record approved MG-000 completion and enable dependent tasks. Rahil may independently inspect MATLAB even while the PR is pending, but must submit real `ver`/MCP evidence before claiming MG-002 DONE.

## 2026-10-31 foundation audit follow-up
- Corrected critical weakness where task prerequisites were checked against a PR's proposed statuses rather than authoritative target-branch statuses; added PR comparison CI and negative tests.
- PPO MG-013 no longer blocks core MG-015, and optional PPO integration MG-019 is separately tracked.
- Guide portal Render deployment MG-020 and real browser QA MG-021 are explicit tasks; no live site is claimed.
- Primary original slide deck is absent from new repository, so original-wording verification remains PENDING. Wording itself has not been changed.
- Zenodo DRC 2026 candidate added as research only, **licence not established** and no data downloaded.
- Read-only guide portal Task Gate CI presentation will filter to actual `main` runs.
