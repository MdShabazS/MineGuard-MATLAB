# Environment check: Shabaz (Mac)

Date: 2026-11-19
Checked by: Claude Code in Shabaz's Mac session (v2_2/prompts/ENV_CHECK.md)

| # | Item | Result |
|---|---|---|
| 1 | Git | 2.54.0 (Apple Git-157) |
| 2 | GitHub CLI | 2.92.0. `gh auth status` timed out reading the keychain once, but authenticated `gh repo view` and `gh pr` commands work |
| 3 | Repository permission | ADMIN |
| 4 | Node.js | v24.15.0 (meets 22 or newer) |
| 5 | MATLAB MCP server | connected (`evaluate_matlab_code` works) |
| 6 | MATLAB | 26.2.0.3433840 (R2026b) Update 1 |
| 7 | Toolboxes (`mineguard_setup`) | required OK (UAV Toolbox 26.2); optional not installed: Deep Learning, Reinforcement Learning (V1 PPO demo only). Also installed: Computer Vision 26.2, Image Processing 26.2, MATLAB MCP Server Toolbox 0.5.0 |
| 8 | `geobasemap` | /Applications/MATLAB_R2026b.app/toolbox/matlab/graphics/maps/geobasemap.m (base MATLAB) |
| 9 | Satellite basemap | opened at the BITM view window without error |
| 10 | Desktop session | MATLAB desktop session via MCP |
| 11 | `v22-gate.mjs validate` | PASS |

OS: macOS 27.2.1. This was also the first execution of `mineguard_setup.m` (added in PR #137 as NOT RUN). It ran correctly.

ENV CHECK: PASS
