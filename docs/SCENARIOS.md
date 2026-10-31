# Synthetic Survey Scenario Specification

## Test area
Configurable bounded virtual field with seeded target placements, negative clutter, safe exclusion geometry, variable terrain height, soil permittivity/conductivity parameters and time-of-day surface temperature. Distances in metres.

## Scenario tiers
1. **S0 sanity**: flat terrain, zero noise, one synthetic target and one negative object; basic wiring/units.
2. **S1 baseline**: repeatable 2D grid/3D display, varied standoff and heterogeneous objects, noise on.
3. **S2 stress**: uneven ground, mixed soil, weak contrasts, weather/temperature variation, GPS error, missing samples.
4. **S3 generalization**: held-out scenario seeds, sensor noise and material conditions never used in training.

All placement algorithms must avoid accidental use of target labels to drive detection. Save scenario configuration and random seed. No real-world minefield or sensitive location data required.

## Acceptance questions
- Can we reproduce the same scenario across two runs using seed?
- Does sensor response change plausibly with depth/standoff? Report if invalid.
- Can target presence/absence be independently evaluated by the metrics layer?
- Is the UI clearly labelled **simulated**, and are false alarms exposed?
