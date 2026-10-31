# Verified Literature Review — MineGuard MATLAB
**Literature status:** references researched 2026-10-31 using publisher/index records. Some full texts/data require permission; numerical results below are **authors' reported results only**.

## Selection criteria
Prioritize named publisher records/DOIs, actual experimental acquisition or described simulation, relevant thermal/sensor physics, UAV height and burial depth, reproducible datasets, stated limitations. Do not turn generic AI or UAV papers into evidence for buried mine detection.

## Peer-reviewed and published studies
### L-01 — Thermographic detection from drone, 2024
- **Title:** *Detection of anti-personnel mines of the “leg breakers” type by analyzing thermographic images captured from a drone at different heights*.
- **Journal:** Infrared Physics & Technology, Volume 142 (November 2024), article 105567.
- **DOI:** https://doi.org/10.1016/j.infrared.2024.105567
- **Research:** thermographic images with mines in terrain, flight heights 1–5 m. Publisher abstract reports 92.13% accuracy and 82.4% sensitivity over 260 test images in its experimental setting. Easier detection for shallow burial and at 1–2 m, with environmental/soil effects.
- **MineGuard use:** motivated thermal contrast, altitude/soil/standoff sensitivity and proper dataset split.
- **Limit:** study-specific supervised image result, **not** a validation of our heat model or operational mine clearance; data reportedly available upon request.

### L-02 — Soil heat/moisture and buried-object thermography, 2024
- **Title:** *Study on the temperature field and infrared characteristics of unsaturated soils with shallow buried objects at different depths*.
- **Journal:** International Journal of Thermal Sciences, article 109282, November 2024.
- **DOI:** https://doi.org/10.1016/j.ijthermalsci.2024.109282
- **Research:** coupled soil heat/moisture migration and ground infrared radiation model.
- **MineGuard use:** show why fixed-temperature overlays are not physical subsurface sensing and identify calibration variables.
- **Limit:** model complexity and soil property inputs; not a plug-and-play MATLAB model.

### L-03 — Aerial thermal MLP and dataset, 2021
- **Title:** *Detection of “Legbreaker” Antipersonnel Landmines by Analysis of Aerial Thermographic Images of the Soil*.
- **Venue:** Engineering Proceedings 2021, 8(1), article 25.
- **Publisher:** https://www.mdpi.com/2673-4591/8/1/25
- **Research:** multifeature MLP on thermograms across image capture heights; authors discuss strong acquisition time/weather influence and report different accuracies across altitudes. Publisher indicates a Mendeley image dataset DOI https://doi.org/10.17632/732ngnf4r3.1.
- **MineGuard use:** candidate for *independent image-analysis validation* after actual access/licence verification; not a substitute for an EM coil dataset.
- **Limit:** training conditions may not match our synthetic scenarios; copyrighted image redistribution needs verified terms.

### L-04 — Comparative UAV/ground sensing field study, 2026
- **Title:** *A Comparative Evaluation of UAV-Based Remote Sensing and Geophysical Techniques for Landmine Detection on a Seeded Minefield*.
- **Journal:** Remote Sensing 2026, 18(13), 2182.
- **Publisher:** https://www.mdpi.com/2072-4292/18/13/2182
- **Research:** evaluates UAV RGB/thermal and geophysical subsurface methods on seeded test ground. In the study, handheld metal detectors outperformed airborne subsurface methods; airborne magnetometry/GPR demanded near-ground operation and did not universally meet high detection rates.
- **MineGuard use:** physical feasibility caution for simultaneous autonomous *aerial + buried + coil* original objective, and strict separation of surface from subsurface.
- **Limit:** context-specific experiment; do not generalize study thresholds to arbitrary devices.

## Tool/vendor literature (not scientific detection papers)
### L-05 — MathWorks UAV Toolbox
https://www.mathworks.com/help/uav/ — trajectories, scenes, modelling; supports simulating vehicle, camera/lidar/GPS outputs, not a turnkey buried-mine detector.
### L-06 — MathWorks Reinforcement Learning Toolbox
https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlppoagent.html and https://www.mathworks.com/help/reinforcement-learning/ref/rl.env.rlfunctionenv.html — PPO agent and custom environment API. Availability depends on local version/toolboxes.
### L-07 — MathWorks Agentic Toolkit
https://github.com/matlab/matlab-agentic-toolkit — Claude Code/MATLAB MCP integration and security caution.

## Phase-1 literature table correction policy
The original Review-1 deck contains six entries with generic author names (e.g., “J. Smith”, “R. Kumar”, “A. Lee”). We have not independently verified corresponding publications, DOIs or precise titles. **Preserve the original slide as historical source, but DO NOT cite these entries as authenticated journal papers** in final report until each is independently traced to a real publication. Replace with actual independently verified references only in the **new literature review**, not in original immutable Phase-1 objectives.

## Research gaps (explicit)
- A validated electromagnetic-coil physics reference and parameterized calibration data for realistic drone standoff [PENDING].
- Verified terms/licences/accessible bytes for thermal datasets and any real EM dataset [PENDING].
- Physical test evidence for our new simulation [NOT RUN].
- Additional 2025–2026 reviews that resolve geographic/soil transfer limitations [PENDING].

## Citation rule for report
Cite authors and DOI exactly as publisher page identifies them once complete bibliography metadata is verified; do not invent missing author initials. Every claimed accuracy must identify the originating study, test-set size and acquisition conditions, never 'MineGuard achieved'.
