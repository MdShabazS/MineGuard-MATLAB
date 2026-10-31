# Third-Party MathWorks Example and Open-Source Reuse Register

## Purpose
The November 2 deadline makes verified example reuse sensible, but only with appropriate licensing and actual feature tests. This document is a policy, not evidence that a candidate was downloaded or adapted.

## Candidate library
| Candidate | Official reference | Technical use | Status |
|---|---|---|---|
| UAV Toolbox scenario examples | https://www.mathworks.com/help/uav/ | Seeded scenario, navigation/rendering | SOURCE CONFIRMED; not copied |
| UAV scenario simulation | https://www.mathworks.com/help/uav/scenario-simulation.html | Mesh/cuboid simulator | SOURCE CONFIRMED; version pending |
| MATLAB RL custom env example | https://www.mathworks.com/help/reinforcement-learning/ug/create-matlab-environments-using-custom-functions.html | Step/reset interface inspiration | SOURCE CONFIRMED; code not copied |
| PPO agent reference | https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlppoagent.html | Agent class and training interface | SOURCE CONFIRMED |
| App Designer tutorial | https://www.mathworks.com/help/matlab/creating_guis/create-a-simple-app-or-gui-using-app-designer.html | UI layout pattern | SOURCE CONFIRMED |
| Official agentic toolkit | https://github.com/matlab/matlab-agentic-toolkit | Claude Code MATLAB MCP configuration | SOURCE CONFIRMED; installation pending |

## Pre-copy checklist for every third-party component
1. Locate canonical repository or publisher; record owner, commit/tag, release and feature.
2. Read exact licence (SPDX if present), redistribution obligations and commercial/noncommercial restrictions.
3. Identify dependency and MATLAB release/toolboxes. Verify whether the example requires a Windows-only simulator.
4. Prefer linking to official samples and writing our own original modular code if licence unclear.
5. Add a `THIRD_PARTY_NOTICES.md` entry if source code is copied or materially adapted, with path and attribution.
6. Run the example in actual MATLAB. Original example PASS does not mean MineGuard integration PASS.
7. Record source URL and decision in per-task evidence. Never copy blindly from video/screenshots.

## Research gap
No third-party sample has been approved for inclusion at this foundation stage. Future Claude Code changes must update this register with actual evidence. Keep all claims traceable.
