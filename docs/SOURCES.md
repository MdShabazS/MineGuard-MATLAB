# Research Sources, Citations, and Verification Status
**Research pass:** 2026-10-31 · **Evidence class:** Official product docs and publisher records were checked. No local MATLAB run, dataset access or experimental validation was performed in this pass.

## Immutable primary academic source
- **Verified 2026-10-31:** original private `Review1Phase1.pptx`, 9 slides, 1,338,001 bytes, SHA-256 `620eed853f5b7e807e3290d69b5c92485368a0e48d6985a9061b4b3648ddf236`. Slides 3–4 match title, four objectives and five problem points in [PHASE1_BASELINE.md](PHASE1_BASELINE.md), with only line-break/whitespace normalization. Recovered from a prior user project upload; not redistributed in public repo. See [SOURCE_VERIFICATION.md](SOURCE_VERIFICATION.md). Slide-5 literature entries remain historical/unverified as publications.

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
- Independent live Render browser/mobile QA and completion of task evidence MG-020/MG-021 remains separate from MG-001. The user reported Render deployment at `https://mineguard-guide-portal.onrender.com` and provided desktop screenshots, but formal evidence/CI verification belongs in MG-020/MG-021.

## New verified candidate record in audit (2026-10-31)
- Baur, J.; Steinberg, G.; Lekhak, S.; Nikulin, A.; de Smet, T.; Ientilucci, E.; Brinkley, A.; Myers, H.; Nitsche, F. (2026). *Demining Research Community Seeded Field Multimodal Landmine Detection Dataset*, Zenodo v2, DOI https://doi.org/10.5281/zenodo.19100554. Contains aerial imaging and separate handheld electromagnetic/metal detector studies. Licencing and cross-modality alignment are **unverified**, so redistribution and performance claims are blocked.
- Original Phase-1 slide-3/4 title and text: **verified against recovered original PPTX on 2026-10-31**; source copy stays private and not published to this new repository. Slide-5 placeholder bibliography remains unverified as separate publications. See `SOURCE_VERIFICATION.md`.
