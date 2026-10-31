# Proposed MATLAB Architecture (design only)

```
Seeded synthetic scenario (terrain, soil, surface temperature, buried target truth)
          |
          v
Baseline grid planner ---> UAV simulation ---> timestamped UAV pose/GPS-like stream
          |                                  |
          |                                  +--> Sensor sampling footprint
          v                                               |
Optional PPO waypoint-selection policy                     +--> Thermal forward model
(same environment, bounded actions)                        +--> EM/metal-coil forward model
                                                             |
                                                             v
                                       Detection baselines -> calibrated score fusion
                                                             |
                                                             v
                                  Location association + uncertainty + event log
                                                             |
                                                             v
                        MATLAB App Designer mission control and experiment exports
```

## Logical layers
1. **Scenario**: generates named parameters, target ground truth and clutter/negative examples; deterministic `rng(seed)`.
2. **Navigation**: local ENU/NED position and time; grid baseline; optional PPO chooses high-level grid-cell targets. Low-level UAV control is outside PPO responsibility initially.
3. **Sensing**: thermal and EM forward models expose physical parameters and measurement noise separately from ground truth. No label leakage.
4. **Detection**: baseline thresholding, optional classifier trained solely on training splits, fusion of aligned signals.
5. **Mapping**: distinguish estimated location from ground-truth location and include error statistics.
6. **App**: mission configuration, play/pause, visualization, experiments and export.

## Integration contract
Use the v1.0 frozen module signatures and typed records in [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md), indexed by [DATA_CONTRACTS.md](DATA_CONTRACTS.md). The scenario generator returns a restricted ground-truth record; the orchestrator creates narrow navigation/detection config views, and only the forward physics and evaluator may receive truth. No module may directly import hidden ground-truth labels into inference. Batch pipeline first; live animation only after data contract passes. App uses event replay or callbacks with rate limiting to avoid UI blocking.

## MATLAB selection
- Standard MATLAB scripts/functions as first executable baseline; use Simulink/Stateflow/UAV Toolbox features only if installed.
- UAV Toolbox supports mesh/cuboid scenarios; Simulink Unreal rendering is not macOS portable.
- PPO is a trained adaptive *survey policy*, not a magically accurate mine detector.
- All runtime inputs/outputs and random seeds are stored in GitHub-approved test artifacts.
