# MATLAB and Simulink Research: Supported Capabilities vs Project Decisions
**Researched:** 2026-10-31 · **Vendor documentation version viewed:** online current pages may show R2026b; Rahil's installed release is **UNKNOWN**, so no API can be declared executable on his laptop yet.

## Capability verification table
| Need | MathWorks product/API | Verified at documentation level? | Local user evidence? | Notes |
|---|---|---|---|---|
| MATLAB scripts/numerics, 2D and 3D graphics | MATLAB | Yes | Installed reported; actual run PENDING | Common portable foundation |
| Interactive mission-control GUI | MATLAB App Designer, `uifigure`, `uiaxes` | Yes | PENDING | App Designer is within MATLAB; no separate App Designer toolbox purchase |
| UAV scenario, body trajectory and sensor outputs | UAV Toolbox; `uavScenario` | Yes | PENDING | Cuboid/mesh fast scenario supported in MATLAB; depends on release/toolbox |
| Visualize high-fidelity 3D via Unreal | UAV Toolbox + Simulink/Simulink 3D Animation | Yes | PENDING | **Windows/Linux only**: never require for Shabaz Mac |
| Simulink dynamic models | Simulink | Yes | PENDING | Optional blocks might require further toolboxes |
| RL custom step/reset environment | Reinforcement Learning Toolbox, `rlFunctionEnv` | Yes | PENDING | Version-specific signatures; train only after validating environment |
| PPO survey optimization | Reinforcement Learning Toolbox, `rlPPOAgent` | Yes | PENDING | Discrete/continuous action support; environment must enforce constraints |
| Trained deep learning model | Deep Learning Toolbox etc | Conditional | PENDING | Prefer mathematical baselines before training |
| Tests | `matlab.unittest`, `runtests` | Yes | PENDING | Must record actual command/log; testing framework in MATLAB |
| Sensor-data fusion helpers | Sensor Fusion and Tracking Toolbox | Yes | PENDING | Can implement transparent mathematical fusion in core MATLAB instead |
| PDE heat-transport solver | PDE Toolbox | Yes | PENDING | Not mandatory; start with documented discretization for scope/time |
| Claude Code execution of MATLAB | MATLAB Agentic Toolkit + MCP server | Yes | PENDING | MATLAB R2021a+ minimum for MATLAB toolkit; newer features vary |
| Claude Code full Simulink toolkit | Simulink Agentic Toolkit | Yes | PENDING | Official installer docs indicate combined setup uses MATLAB R2023a+ |

## Direct official sources and functionality
1. UAV Toolbox overview: https://www.mathworks.com/help/uav/
2. Scenario Simulation: https://www.mathworks.com/help/uav/scenario-simulation.html — documents both Unreal (Windows/Linux) and cuboid environments (MATLAB/Simulink).
3. RL PPO: https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlppoagent.html — policy/critic interface and action constraints.
4. RL custom env: https://www.mathworks.com/help/reinforcement-learning/ref/rl.env.rlfunctionenv.html — required step/reset outputs.
5. App Designer: https://www.mathworks.com/help/matlab/app-designer.html — UI components and code.
6. MATLAB testing: https://www.mathworks.com/help/matlab/ref/matlab.unittest-package.html.
7. Agentic Toolkit: https://github.com/matlab/matlab-agentic-toolkit — MCP runs code/tests, detects toolboxes, requires human security review.
8. Installer: https://github.com/matlab/agentic-toolkit-installer — Windows x64 / macOS / Linux and release prerequisites.

## No premature product installation
- First collect `ver`, `which`, add-on inventory, working session and product entitlements; sanitize licence info.
- MATLAB core required; App Designer built in. Simulink/UAV/RL Toolbox only install if licensed and required by actual model paths.
- If a product is not available, isolate the feature and use fallback MATLAB core version; **do not** claim the full selected requirement is satisfied.
- MATLAB package/add-on installation guidance: https://www.mathworks.com/help/matlab/matlab_env/get-add-ons.html.
- Claude MCP setup and diagnostics: https://github.com/matlab/matlab-agentic-toolkit/blob/main/Configuration_and_Troubleshooting.md.

## Technical consequences for MineGuard
1. Use MATLAB-only computational pipeline and cuboid/mesh visuals first so both Windows and macOS have plausible compatibility.
2. Use App Designer for interactive demo; avoid a separate React main dashboard.
3. Keep Render guide portal a **separate** read-only progress/status website; it does not execute MATLAB.
4. MATLAB code must be modular enough that unavailable toolboxes don't stop all independent work.
5. PPO training may require considerable time; reserve honest incomplete flag if local resources cannot train by Nov 2.

## Research/design versus evidence
All rows above say **documented capability**, not 'installed' or 'tested'. The first actual `ver`, `runtests`, and Claude MCP execution logs must be attached to `tasks/evidence/MG-002.md` after executable work begins.
