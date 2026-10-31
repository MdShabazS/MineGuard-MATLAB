# Physics, Modelling Assumptions and Realism Gates
**Status:** research synthesis; any numerical parameter chosen later is an assumption until independently calibrated.

## 1. Scope separation
- **Visible surface objects:** RGB can image objects if spatial resolution, lighting, contrast and occlusion allow. Not the primary promised subsurface sensing method.
- **Buried shallow objects:** the thermal channel can *sometimes* produce an indirect surface-temperature contrast from disturbed soil or altered heat transport; contrast is not an object identity label.
- **Metal-containing buried objects:** a coil-based detector may respond to electromagnetic coupling at sufficiently short target/coils separation; **response is extremely standoff-dependent**. A coil several metres above soil must not be assigned arbitrary strong signals.
- **Nonmetallic buried objects:** metal detector cannot detect them on metal response alone; thermal cues may also be absent. The original objective is preserved, but real-world feasibility remains unresolved.

## 2. Thermal model — valid mathematical starting point
A simple transient ground heat equation is
```text
rho(x) * c_p(x) * dT/dt = div(k(x) grad T) + q(x,t)
```
where T is temperature (K), rho density (kg/m³), c_p heat capacity (J/kg/K), k conductivity (W/m/K), and q volumetric heat term (W/m³). A simplified 1D/2D diffusion/discretized contrast model is an acceptable *educational baseline*, provided the report names all boundary conditions and does not pretend to include moisture transport unless implemented. For real radiative surface measurements, emissivity, atmospheric attenuation, viewing geometry and sensor resolution matter.

**Parameter record:** target depth, soil type/moisture, thermal diffusivity, day/night forcing, target material, wind/radiation simplifications, camera field of view, noise, altitude and sample footprint.

### Thermal acceptance checks
1. Ground surface with no target should have no *deterministic target signature*; sensor and background noise remain.
2. Surface thermal contrast may weaken/disappear or reverse for certain depths/times/soil; never hard-code a guaranteed hot spot.
3. Reduced image spatial resolution should mix small anomalies into more surrounding pixels.
4. Uncertainty from soil moisture and time of day must be examined in parameter sweeps.
5. Compare models to relevant literature only within a similar acquisition regime; avoid transferring paper accuracy figures to the simulated system.

## 3. Electromagnetic channel — mandatory standoff test
A coil transmits/detects a field; the secondary response from a conducting or magnetic object depends on excitation frequency, object properties/orientation, coil geometry, background soil response and **separation**. At low frequencies/near field, a simple field component can scale approximately with inverse cubic distance for an idealized dipole; actual transmit–receive coupling and output signal may decay more steeply. **Do not choose an arbitrary 1/r^3 signal law as a validated mine-detector forward model without specifying which physical quantity and regime it represents.**

**Illustrative model only:** calibrated monotone falloff `A(d,material,soil,orientation)` + background clutter + zero-mean sensor noise. Use units marked 'normalized response' until a real calibration exists. Set physically invalid long-range responses to below detection threshold rather than secretly increasing gain.

**Required parameter sweep:** 0.05, 0.2, 0.5, 1, 2, 5 m standoff *as experimental design points, not performance predictions*. Document whether the long-range model is below noise. Explicitly evaluate absence of metal and conductive clutter.

## 4. Sensor fusion — no magic gain
Match readings by time and platform coordinates using stated synchronization error; separate metal vs thermal spatial footprints. Possible fusion baselines:
- OR / AND decision rule — useful to visualize recall vs false-positive trade-off.
- Weighted scores or calibrated likelihoods — weights chosen on validation data only.
- Trained classifier — only when trained on separate labelled synthetic training cases with held-out test seeds.
- Missing one modality → graceful single-modality result tagged lower-confidence or INVALID, never substitute ground-truth data.

If fused performance is worse than best single channel, report it. No algorithm can rescue missing physical sensing evidence.

## 5. Navigation/geo-localization limitations
Actual GPS is replaced by simulated position observations. A 'GPS' widget in App Designer should clearly say **virtual geotag**. Distinguish position accuracy from final estimated anomaly localization: camera/sensor footprint, altitude, attitude, sampling time and interpolation add errors.

## 6. Necessary negative experiments
- Target buried too deep or coil at excessive altitude → expected false negative.
- Nonmetallic object with EM-only → false negative.
- Hot debris / sun-heated stones without target → expected thermal false positive if detector simplistic.
- Dense/heterogeneous soil/wet conditions → uncertain contrast.
- GPS noise / timing skew → position error even if detector score correct.

## 7. Literature supporting limits
- 2024 aerial thermal study: *Detection of anti-personnel mines of the “leg breakers” type by analyzing thermographic images captured from a drone at different heights*, Infrared Physics & Technology **142**, 105567. DOI https://doi.org/10.1016/j.infrared.2024.105567. Tests at 1–5 m; reported best detectability for shallower mines and 1–2 m flights in that study.
- 2024 heat/moisture modelling study: *Study on the temperature field and infrared characteristics of unsaturated soils with shallow buried objects at different depths*, International Journal of Thermal Sciences, article 109282, DOI https://doi.org/10.1016/j.ijthermalsci.2024.109282. Highlights coupled heat/moisture modelling limitations.
- 2026 comparative field study: *A Comparative Evaluation of UAV-Based Remote Sensing and Geophysical Techniques for Landmine Detection on a Seeded Minefield*, Remote Sensing **18**(13), 2182, https://www.mdpi.com/2072-4292/18/13/2182. Reports handheld metal detectors as superior for subsurface targets in its studied conditions; UAV airborne sensors required low sensor altitude and underperformed. **These are study-specific findings, not universal guarantee.**
- 2021 thermal paper: https://www.mdpi.com/2673-4591/8/1/25 (dataset link in publication). Experimental accuracy depends on settings, altitude and dataset; not a MineGuard result.

## 8. Claims allowed in the final review
Allowed: 'We simulated a metal-detector response subject to an explicit sensing-distance constraint.' 'We measured algorithm precision on held-out *synthetic* scenarios.' 'The model does not establish real UAV subsurface detection.'
Not allowed: 'We built an operational drone that detects buried explosives.' 'The field is now safe.' 'Real detection accuracy is X%' when only synthetic results exist.
