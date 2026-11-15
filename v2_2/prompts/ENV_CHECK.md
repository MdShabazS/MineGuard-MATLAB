# Environment check (first time on a machine, then every 7 days)

Run the checks, show the person one table of results, then fix anything missing **one step at a time**. Give one instruction, wait for the person to confirm, then check again.

**Never type passwords, licence numbers or MathWorks/GitHub credentials yourself.** The person enters them.

## 1. Checks

| # | Item | How to check | Needed |
|---|---|---|---|
| 1 | Git | `git --version` | required |
| 2 | GitHub CLI signed in | `gh auth status` | required |
| 3 | Write access to the repository | `gh repo view MdShabazS/MineGuard-MATLAB --json viewerPermission -q .viewerPermission` → `WRITE` or `ADMIN` | required, to push and merge |
| 4 | Node.js 22 | `node --version` → v22.x or newer | required (task gates) |
| 5 | MATLAB MCP server connected | your MATLAB tools (for example `evaluate_matlab_code`) are available in this session | required for MATLAB tasks |
| 6 | MATLAB R2026b | in MATLAB: `version` → contains `R2026b` | required |
| 7 | Toolboxes | in MATLAB, from the repository root: `r = mineguard_setup` → `r.missing_required` empty | UAV Toolbox required; RL and DL optional |
| 8 | Map toolchain | in MATLAB: `which geobasemap` returns a path | required for V22-T4 to T8 (base MATLAB) |
| 9 | Internet map access | in MATLAB: `f = uifigure('Visible','off'); g = geoaxes(f); geobasemap(g,'satellite'); drawnow; delete(f)` with no error | required for V22-T4 to T8 |
| 10 | Desktop session | MATLAB opened in a desktop session, not `-batch` (the app tests open windows) | required for V22-T5, T6 and T8 |
| 11 | Repository checks run | `node scripts/v22-gate.mjs validate` → PASS | required |

## 2. Fix steps (only for items that failed)

1. **Git (Windows):** `winget install --id Git.Git -e`, then open a new terminal.
2. **GitHub CLI:**
   1. Install it with `winget install --id GitHub.cli -e`.
   2. The person runs `gh auth login` (GitHub.com → HTTPS → log in with a web browser) and completes the browser sign-in themselves.
3. **Write access:** the person asks Shabaz to add their GitHub username as a collaborator with *Write*, then accepts the invitation e-mail or https://github.com/MdShabazS/MineGuard-MATLAB/invitations. Check again afterwards.
4. **Node.js 22:** `winget install --id OpenJS.NodeJS.LTS -e`, or the LTS installer from https://nodejs.org. Open a new terminal and check `node --version`.
5. **MATLAB MCP server:**
   1. Install the MATLAB Agentic Toolkit (https://www.mathworks.com/products/matlab-agentic-toolkit.html) and follow its Claude Code setup page to register the MATLAB MCP server.
   2. Restart Claude Code in the repository folder.
   3. Check that the MATLAB tools appear.
6. **MATLAB R2026b:** install it with the MathWorks installer, signing in with the person's own MathWorks account. Another release is not supported for V2.2 evidence.
7. **UAV Toolbox missing:**
   1. In MATLAB, go to **Home → Add-Ons → Get Add-Ons**, search *UAV Toolbox* and click **Install**. The person signs in if asked.
   2. If it says "not licensed", the person's MATLAB licence does not include it. Stop, and tell them to check their licence with MathWorks or their college licence administrator.
   3. Restart MATLAB and run `mineguard_setup` again.
8. **Optional RL and DL Toolboxes:** only needed for the V1 PPO demo. Same Add-On steps; not required for V2.2.
9. **`geobasemap` or satellite failing:**
   - Check the internet connection, proxy and firewall: `https://services.arcgisonline.com` must be reachable.
   - `geobasemap` is base MATLAB; Mapping Toolbox is **not** required.
   - If the network blocks map services, the person must use another network for V22-T4 to T8.
10. **No desktop session:** open MATLAB normally, from the Start menu or Applications, and connect the MCP server to that session.

## 3. Record

Write `v2_2/evidence/ENV-<Name>.md` with:
- the date;
- OS;
- MATLAB version string;
- the toolbox list from `ver` (names and versions only, **no licence numbers**);
- Node and gh versions;
- `viewerPermission`;
- a line `ENV CHECK: PASS` or `ENV CHECK: FAIL (<items>)`.

Commit this file in the person's first task PR. The gate ignores it.
