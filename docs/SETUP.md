# Setup and dependencies

How to get a working MineGuard checkout on a new machine. Team and rules: [TEAM.md](TEAM.md).

## 1. Clone

```bash
git clone https://github.com/MdShabazS/MineGuard-MATLAB.git
cd MineGuard-MATLAB
```

Everything the project needs is in this repository. MATLAB itself and its toolboxes are licensed software and are **not** in the repository.

## 2. MATLAB

| Dependency | Needed for | Required? |
|---|---|---|
| MATLAB **R2026b** (tested: Update 1, 26.2.0.3433840) | everything | **required** |
| **UAV Toolbox** | V1 scenario, V2 and V2.1 mission simulation | **required** |
| Reinforcement Learning Toolbox + Deep Learning Toolbox | V1 experimental PPO demo (`mineguardPPODemo`) and its tests only | optional |
| Sensor Fusion and Tracking Toolbox | not used; fusion is in core MATLAB | not needed |

Also installed on the tested Windows host, but not required by the code: Aerospace, Mapping, Navigation, Simulink, Stateflow and MATLAB MCP Server Toolbox.

### Path and dependency check

From the repository root in MATLAB:

```matlab
mineguard_setup            % adds matlab/, v2/matlab and v2_1/matlab to the path and lists missing toolboxes
```

## 3. Run

| What | Command (MATLAB, repository root, after `mineguard_setup`) |
|---|---|
| V1 fixed-grid demo | `mineguardDemo` |
| V2 mission control | `mgv2MissionControl` |
| V2.1 interactive scenarios | `mgv21MissionControl` |
| V2.1 tests | `runtests('v2_1/tests')` |
| V2 tests | `runtests('v2/matlab/tests')` |
| V1 tests | `runtests('matlab/tests')` |

The V2 and V2.1 suites need a desktop session (they open windows). The full V2 + V2.1 regression takes over an hour on the Windows laptop.

## 4. Repository checks (Node.js)

Node.js **22** (as in CI). The gate scripts use only Node's built-in modules, so `npm install` is not needed.

```bash
node scripts/task-gate.mjs validate
node scripts/v2-gate.mjs validate
node --test scripts/tests/*.test.mjs portal/tests/*.test.mjs
```

Only the optional live-portal browser check (`scripts/mg021-live-browser.mjs`) needs Playwright, which CI installs with `npm install --no-save playwright@1.56.1`.

## 5. Claude Code and MATLAB

Each team member's Claude Code session drives MATLAB through the MATLAB MCP server. See [MathWorks MATLAB Agentic Toolkit](https://www.mathworks.com/products/matlab-agentic-toolkit.html). Never commit licence files or MATLAB credentials.
