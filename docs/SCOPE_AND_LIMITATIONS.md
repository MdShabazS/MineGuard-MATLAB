# Scope, Boundaries and Scientific Honesty

## Included
- UAV mission planning and autonomous scan demonstration within a simulated field; reference algorithm is deterministic grid coverage.
- Simulated thermal contrast, metallic-target electromagnetic responses, non-target clutter, terrain/soil/temperature variations and measurement noise.
- Mathematical baseline + trained classifier (only if reproducibly trained), late/score fusion with calibration and ablation experiments.
- Virtual GPS/geotag and ground-control views; timestamped exportable experiment logs.
- Optional PPO-based adaptive survey policy compared fairly with a fixed-route reference.

## Excluded / not asserted
- Actual landmine clearance, identification of explosive material, safe-field certification, real minefield operation, or human-safety outcomes beyond virtual design intent.
- Guaranteed airborne detection of subsurface mines: coil sensitivity decays with distance; physically meaningful standoff and soil constraints are mandatory. If modelling implies unrealistic performance, state this as a negative feasibility finding.
- Detection of buried nonmetallic targets with a metal-only sensor.
- Laboratory or field validation not yet performed; any real thermal and EM dataset must be licensed and its collection context documented.

## Scientific rule
`simulated target present` is ground truth *inside the model* only. A visual "mine" marker is a synthetic surrogate. Use terms **suspected target** / **simulated anomaly** in runtime UI. Report estimated detection probability, false positives/negatives and uncertainty; never report "safe to enter" or "cleared".

## Student project constraints
- MATLAB Desktop available on Rahil Windows, release/toolboxes/licence activation **PENDING**; Mac installation and common-toolbox support **PENDING**.
- Use cuboid/mesh visualization as portable baseline. Unreal high-fidelity simulator is Windows/Linux only; cannot be required for Mac demonstration.
- No secrets/private student data in public GitHub; no permanent local-only authoritative project state.
