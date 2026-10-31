# Research Sources, Citations, and Verification Status
**Research pass:** 2026-10-31 · **Evidence class:** Official product docs and publisher records were checked. No local MATLAB run, dataset access or experimental validation was performed in this pass.

## Immutable primary academic source
- Team's `Review1Phase1.pptx`, slides 3 and 4: original title/four objectives and five problem-statement bullets. Verbatim transcription in [PHASE1_BASELINE.md](PHASE1_BASELINE.md). Original slide bibliographic placeholder entries are not independently validated.

## MathWorks official documentation
- https://www.mathworks.com/help/uav/ — UAV Toolbox and scenarios.
- https://www.mathworks.com/help/uav/scenario-simulation.html — UAV cuboid/mesh vs Unreal (Windows/Linux only).
- https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlppoagent.html — PPO agent interface, action constraint caveats.
- https://www.mathworks.com/help/reinforcement-learning/ref/rl.env.rlfunctionenv.html — custom environment action, observation, reset and step contracts.
- https://www.mathworks.com/help/matlab/app-designer.html — interactive app creation.
- https://www.mathworks.com/help/matlab/ref/matlab.unittest-package.html — MATLAB unit tests.
- https://www.mathworks.com/help/matlab/ref/matlab.addons.installedaddons.html — add-on inventory.
- https://www.mathworks.com/help/matlab/matlab_env/get-add-ons.html — install and manage add-ons.

## MathWorks official open-source installer
- https://github.com/matlab/matlab-agentic-toolkit — official Claude Code / MATLAB MCP support, minimum MATLAB R2021a.
- https://github.com/matlab/agentic-toolkit-installer — combined MATLAB+Simulink installer and release/platform requirements.
- https://github.com/matlab/matlab-agentic-toolkit/blob/main/Configuration_and_Troubleshooting.md — Claude MCP diagnostics and setup.
**Caveat:** vendor repos may change after research date; the local installed release controls exact available functions.

## Peer-reviewed journal/publisher literature
- *Detection of anti-personnel mines of the “leg breakers” type by analyzing thermographic images captured from a drone at different heights*. Infrared Physics & Technology 142 (2024), 105567. DOI: https://doi.org/10.1016/j.infrared.2024.105567. Publisher abstract includes altitude/depth/detection-setting limits.
- *Study on the temperature field and infrared characteristics of unsaturated soils with shallow buried objects at different depths*. International Journal of Thermal Sciences (2024), 109282. DOI: https://doi.org/10.1016/j.ijthermalsci.2024.109282. Coupled heat/moisture limitations.
- *Detection of “Legbreaker” Antipersonnel Landmines by Analysis of Aerial Thermographic Images of the Soil*. Engineering Proceedings 8(1), 25 (2021). https://www.mdpi.com/2673-4591/8/1/25. Mentions a Mendeley image dataset DOI https://doi.org/10.17632/732ngnf4r3.1.
- *A Comparative Evaluation of UAV-Based Remote Sensing and Geophysical Techniques for Landmine Detection on a Seeded Minefield*. Remote Sensing 18(13), 2182 (2026). https://www.mdpi.com/2072-4292/18/13/2182. Comparative study; requires cautious transfer to our context.

The publisher abstracts/records above are **not** blanket endorsements of MineGuard's proposed performance. Some full-text pages were access-limited and complete article metadata requires final bibliographic verification before submission.

## GitHub governance
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches — review/status protection.
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets — public ruleset eligibility and configuration.

## Render guide portal
- https://render.com/docs/static-sites — static site public deploy, free tier, automatic deploy on linked branch.
- https://render.com/tutorials/web-service-vs-static-site/static-sites — `type: web, runtime: static` in Blueprint.
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api — unauthenticated API limitations.

## Research-to-code evidence flow
When code uses a paper/model, add the exact equation/parameter derivation and source/figure/section in that task's evidence. Reproducible numeric constants must not be invented. Every copied sample/dataset must have verified licence and attribution. External reported accuracies belong to their respective study, not to MineGuard.

## Still not verified
- MATLAB installed release, products and actual local `ver` results.
- Claude Code's working MATLAB MCP connection.
- Availability and reuse rights of thermal images, real EM-coil datasets or calibrated soil data.
- Actual model training runs, plots, detection metrics, standalone MATLAB UI.
- Branch protection configured on the new public repository, Render deployed URL and live portal browser test.
