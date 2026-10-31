# End-to-End Methodology and Algorithm Contracts
**Status:** pre-implementation plan. No claim of tested detection.

## Stage 0 — Inputs and scenario
Inputs: rectangular survey boundary; 3D terrain height map; soil and thermal parameters; simulated target/clutter positions and depth; camera/coil standoff; noise and RNG seed. An `ExperimentConfig` structure records units and versions.

Output: `TargetTruth` held only in scenario generator and evaluator, and `ScenarioGeometry` safe for navigation and plotting.

## Stage 1 — Fixed autonomous grid mission (benchmark)
1. Validate scan bounds, row spacing, simulated vehicle altitude, speed and exclusion polygons.
2. Generate serpentine/lawnmower waypoints with explicit row spacing. Test inclusion and edge boundaries.
3. Advance simulated pose using documented kinematic assumptions (time step, nominal speed, turn limits).
4. Record monotonic `t_s` plus pose, altitude, synthetic GPS projection and waypoint index.
5. Report coverage: grid cells visited and time/distance. Log incomplete route and any edge collisions.

Acceptance: repeatable run with same seed/config, no illegal waypoints and sensible coverage independent of target presence.

## Stage 2 — Sensor sampling
For each pose/time:
- Resolve thermal sensor footprint projected on ground. Generate *plausible* surface-temperature response including background and noise; sample and downsample/blur as required.
- Resolve effective EM sensor interaction volume at coil position and target burial depth; apply standoff attenuation and noise. Nonmetallic targets produce no independent metal signal in this channel unless an actual metallic component is deliberately modelled.
- Store observations without target class labels. Generate missing samples from explicit dropout mechanism with reason.

Acceptance: parameter-sweep sanity checks, real units/uncertainty field, no target truth in outputs.

## Stage 3 — Association and inference
- Join thermal/EM samples by configurable time tolerance and virtual spatial proximity.
- Normalize/calibrate scores using training/validation only.
- Produce independent thermal and EM detectors and simple fusion baseline; supervised model is optional and must have train/validation/test separation.
- Generate `DetectionEvent` with `status=SUSPECTED`, confidence, estimated location and evidence sample IDs.
- Do not leak targets from scenario truth directly into detections.

Acceptance: confusion matrix built on held-out truth only; no detections when all signals invalid; negative controls produce expected failure opportunities.

## Stage 4 — Mapping
Project sensor footprint to local East/North; add positional uncertainty and time alignment error. Estimate anomaly location, then compare with withheld truth (for evaluator only). Virtual `lat_deg/lon_deg` may be derived from a clearly synthetic/referenced origin; don't call simulated values 'GPS fix'.

## Stage 5 — PPO (experimental optimisation)
Start only after fixed-route simulation works. Define RL action as *next allowable survey cell/waypoint*, not arbitrary full-flight control. Observation includes visited map, current pose, remaining budget, known obstacles, observed uncertainty. No hidden target labels. Train with seeded synthetic scenarios, compare on **unseen** seeds with identical mission constraints. Report episodes, total rewards, coverage/time/distance and failures. If PPO worse, report.

## Stage 6 — App Designer + report
Dashboard reads saved or streamed event structures with stable schema, not direct hidden truth. UI: mission controls, 3D view, live pose, sample graphs, suspected-anomaly map, comparison, exports and clear simulation warning. Export results with `GitSHA`, `ScenarioSeed`, `ToolboxInventory`, data provenance, source run log and accuracy qualifiers.

## Pseudocode (design, not executable MATLAB)
```text
config = validateExperimentConfig(input)
scenario = generateSeededScenario(config)
gridRoute = makeGridRoute(scenario.boundary, config)
for each simulated time step:
    pose = updateUAV(pose, gridRoute)
    sampleThermal = measureThermal(scenario.hiddenPhysicalState, pose, config)
    sampleEM = measureEM(scenario.hiddenPhysicalState, pose, config)
    aligned = associate(sampleThermal, sampleEM, pose)
    suspectedEvents = detector(aligned)  // NO access to truth labels
    log(pose, samples, events)
end
metrics = evaluator(suspectedEvents, scenario.truth) // separate boundary
renderUI(log, map, metrics, label="SIMULATION")
saveReproducibleRun(config, seed, codeVersion, outputs, testLog)
```

## Interfaces and error handling
Schema reference: [DATA_CONTRACTS.md](DATA_CONTRACTS.md). Invalid numeric parameters → actionable error; null sensor → explicit invalid sample; missing toolbox → explain feature disabled; resource/time budget exceeded → stop with explicit partial run; never silently fall back to fabricated values.

## Why this order
Sensor outputs rely on known pose/geometry; fusion relies on sample synchronisation; dashboard relies on stable types; PPO can be compared only after an executable deterministic baseline. This is the dependency logic that drives the DAG.
