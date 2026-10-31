# Thermal and Electromagnetic Sensor Modelling Contract

**Status: research/design; numerical validation is PENDING.** A simulated subsurface threat is not evidence that an aircraft can sense real buried mines.

## Thermal channel
Model soil surface temperature contrast via a bounded thermal forward response with explicit time, soil thermal properties, target depth, burial material and weather conditions. Separately model sensor field-of-view/footprint, spatial sampling, pixel mixing, instrument uncertainty and noise. Use documented parameter ranges and cite the originating publication. Avoid inverse fitting on held-out targets.

**Checks:** zero-contrast case; contrast variation with depth, time and soil assumptions; performance deterioration with coarse spatial resolution; adversarial sun/shadow/debris false positives. If physical assumptions break, label the output phenomenological rather than verified physics.

## Electromagnetic/metal-detector channel
Model a plausible coil response based on target conductivity/material, coil geometry, standoff, depth and background interference. The **effective range of conventional metal-detector coils is short**; never assume a drone at several metres can detect buried metallic targets. Measure/sweep stand-off sensitivity; explicitly mark configurations with no physically plausible response. Metal-only sensing does not identify nonmetallic threats.

## Fusion
Join sensor readings by timestamp and coordinate proximity with documented tolerance; invalid/missing observations must remain missing. Compare: thermal-only, EM-only, simple threshold/weighted fusion, and optional trained classifier. Model confidence calibration and failure modes.

## Acceptance evidence
- Parameter table with units and credible scientific references (not invented papers).
- Deterministic unit tests for edge cases, negative controls and noise reproducibility.
- Plots over depth/standoff/soil/temperature with explicit limitations.
- Ablation with *same* held-out scenario splits and metrics; no claim that fusion always outperforms either modality.
