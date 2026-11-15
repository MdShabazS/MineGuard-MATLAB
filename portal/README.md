# Guide live dashboard (V22-T2)

**Live site:** https://mineguard-guide-portal.onrender.com/ (Render static site, `render.yaml`; deploys `portal/` from `main` after checks pass).

One page for the project guide. It shows:
- the current phase's tasks, with owner and status (Done, In progress, Ready, or Waiting for a dependency);
- **who is doing what**: each team member's Claude session, its current task, open pull request, last commit time and CI result;
- a single link to the project history (V1, V2, V2.1).

## Where the data comes from (refreshed every 3 minutes, no server, no credentials)

| Data | Source |
|---|---|
| Official status | `v2_2/tasks/manifest.json` and `status.json` at the latest `main` commit, read from `raw.githubusercontent.com` by commit SHA |
| Live work | GitHub REST API, 2 requests per refresh: the Actions runs list (CI results and the latest `main` commit) and open pull requests. A PR on `task/V22-Tn-*` is shown against task V22-Tn as **not merged** work |

The GitHub API allows 60 unauthenticated requests per hour per network, and for unauthenticated visitors even "304 Not Modified" replies count. The page therefore makes 2 requests every 3 minutes (about 40 per hour). If the limit is reached, for example by many reloads or several viewers on one network, it stops calling the API, says when live data resumes, and keeps showing the merged status read from `raw.githubusercontent.com`, which has no such limit.

## Files

| File | Content |
|---|---|
| `index.html` | the page |
| `styles.css` | light and dark themes, phone layout |
| `core.mjs` | pure logic: READY and Waiting from dependencies, PR-to-task matching, CI result, who is doing what. Tested in `tests/core.test.mjs` |
| `app.mjs` | fetching and rendering. Text is inserted as text only, never as HTML |

## Checks

```bash
node --test portal/tests/*.test.mjs
node scripts/verify-render-portal.mjs https://mineguard-guide-portal.onrender.com/ --require-current   # after deployment
```

## Next phase

To show the next phase, change `PHASE` in `core.mjs` to that phase's task files.

The V1 board, the V2 board and the enhancement roadmap that used to be on this page were replaced on 2026-11-15. Their records remain in `tasks/`, `v2/`, `v2_1/` and the Git history.
