# Guide Progress Portal — Research, Requirements and Delivery

**Owner:** Shabaz (MG-000 foundation enhancement). **Purpose:** An academic guide can see live, evidence-backed project progress without requesting WhatsApp status updates.

## Guide's questions the portal must answer
1. What exactly is MineGuard, when is the deadline, and have objectives changed? — title, date and link to exact original objectives.
2. How much is done? — DONE/total count and percentage, based solely on merged GitHub statuses.
3. Who is doing what? — per-owner progress, currently IN_PROGRESS tasks and READY tasks.
4. What is holding the project back? — computed BLOCKED tasks and outstanding dependencies.
5. Can I verify claims? — links to task evidence files, PRs, GitHub Actions and commit history.
6. What has changed recently and what is next? — date/owner/task notes from the committed `tasks/updates.json` journal.\n7. Are test results genuine? — separate automated repository checks from actual MATLAB execution evidence.
8. What remains? — complete filterable task table and prerequisites.

## Product requirements
- Read-only public site with no logins, no editable fields, no embedded GitHub token.
- Authoritative `main` tasks only; never infer DONE from PR description or a draft branch.
- Auto refresh on visible tab every 5 minutes, manual refresh, last-checked timestamp and missing-data warnings.
- Desktop and mobile responsive, accessible names and keyboard navigation.
- Transparent status definitions and conspicuous 'simulation, not a real mine-clearance system' statement.
- Render free Static Site; deployments from main only; no backend/database required.
- GitHub REST unauthenticated rate-limit handled gracefully, with task board still functioning when activity feed fails.

## Acceptance and QA evidence
- JS syntax/unit tests plus independent hosted Chromium UI automation (desktop and mobile-emulated); actual human physical-phone check remains recommended before externally presenting layout.
- Visual review of empty/unmerged foundation state, correct blockage counts, in-progress state, date/deadline, evidence links, mobile width, rate-limit fallback.
- MG-020 was deployed at https://mineguard-guide-portal.onrender.com/ and its first HTTPS/main-data fetch verified in a hosted runner (see `tasks/evidence/MG-020.md`).
- MG-021 has actual Chromium desktop and responsive mobile-**emulated** browser QA evidence (see `tasks/evidence/MG-021.md` and GitHub Actions run 41218473248). Physical phone and independently observed real main-state transition are documented separately; don't equate emulation with hardware.

## MG-020 deployment completion gate

See [MG020_RENDER_DEPLOYMENT_CHECKLIST.md](MG020_RENDER_DEPLOYMENT_CHECKLIST.md) for the actual Render Blueprint settings, first verified HTTPS fetch, GitHub main-source check, and required evidence. The verified deployed URL is https://mineguard-guide-portal.onrender.com/. MG-021's executed browser checks and limitations are in `tasks/evidence/MG-021.md`.

## Source and deployment references
- https://render.com/docs/static-sites
- https://render.com/docs/your-first-deploy
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
- Implementation and setup: [portal/README.md](../portal/README.md).
