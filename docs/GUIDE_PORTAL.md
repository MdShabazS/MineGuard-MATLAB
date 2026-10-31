# Guide Progress Portal — Research, Requirements and Delivery

**Owner:** Shabaz (MG-000 foundation enhancement). **Purpose:** An academic guide can see live, evidence-backed project progress without requesting WhatsApp status updates.

## Guide's questions the portal must answer
1. What exactly is MineGuard, when is the deadline, and have objectives changed? — title, date and link to exact original objectives.
2. How much is done? — DONE/total count and percentage, based solely on merged GitHub statuses.
3. Who is doing what? — per-owner progress, currently IN_PROGRESS tasks and READY tasks.
4. What is holding the project back? — computed BLOCKED tasks and outstanding dependencies.
5. Can I verify claims? — links to task evidence files, PRs, GitHub Actions and commit history.
6. Are test results genuine? — separate automated repository checks from actual MATLAB execution evidence.
7. What remains? — complete filterable task table and prerequisites.

## Product requirements
- Read-only public site with no logins, no editable fields, no embedded GitHub token.
- Authoritative `main` tasks only; never infer DONE from PR description or a draft branch.
- Auto refresh on visible tab every 5 minutes, manual refresh, last-checked timestamp and missing-data warnings.
- Desktop and mobile responsive, accessible names and keyboard navigation.
- Transparent status definitions and conspicuous 'simulation, not a real mine-clearance system' statement.
- Render free Static Site; deployments from main only; no backend/database required.
- GitHub REST unauthenticated rate-limit handled gracefully, with task board still functioning when activity feed fails.

## Acceptance and QA evidence
- JS syntax and unit tests in GitHub CI; browser test by actual person before external sharing.
- Visual review of empty/unmerged foundation state, correct blockage counts, in-progress state, date/deadline, evidence links, mobile width, rate-limit fallback.
- Once merged, verify URL and first real data refresh on Render (deployment **NOT YET COMPLETED**). Do not claim a Render URL before it exists.

## Source and deployment references
- https://render.com/docs/static-sites
- https://render.com/docs/your-first-deploy
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
- Implementation and setup: [portal/README.md](../portal/README.md).
