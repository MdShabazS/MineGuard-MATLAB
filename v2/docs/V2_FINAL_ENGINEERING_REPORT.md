# MineGuard Advanced V2 — Final Engineering Report
### Autonomous Aerial Landmine Detection System: MATLAB High-Fidelity Simulation (V2)

**Document:** V2-010 engineering report · **Revision:** 1.0 · **Prepared:** 2026-11-03 (IST) by Claude Code for Rahil (owner of V2-010 under `v2/docs/V2_GOVERNANCE_DELEGATION.md`)
**Repository:** https://github.com/MdShabazS/MineGuard-MATLAB · **Baseline:** `main` at `55b9e91` (V2-001 to V2-009 DONE)
**Review state:** not reviewed by Shabaz or by the guide. **Guide approval: PENDING.**

> **Safety and scientific conclusion.** V2 is a simulation. It flies a virtual quadcopter over a synthetic field, generates RGB, thermal, LiDAR and navigation samples from that scene, runs a frozen anomaly detector and shows everything live in a MATLAB dashboard that can export and replay a run. **It does not detect buried landmines.** On held-out V2 VALIDATION the detector found **0 of 4** synthetic targets (G07), and the V1 sealed TEST result stays **TP 0, FP 26, TN 470, FN 4**. Every marker in the dashboard is a SUSPECTED anomaly with an uncalibrated score. The live scenes contain no synthetic target at all, so every live marker is a false alarm by construction. Nothing here says any ground is safe.

## 1. Original Phase-1 baseline (unchanged)

**Official title:** MineGuard — Autonomous Aerial Landmine Detection System.

**Original objectives (verbatim, from `docs/PHASE1_BASELINE.md`):**

1. To design and develop an autonomous drone system that scans suspected landmine fields by following a pre-programmed flight path without manual intervention.
2. To detect subsurface landmines accurately by integrating a metal detector coil and thermal camera with a sensor fusion algorithm that minimizes false detections.
3. To geo-tag and map every detected threat using a GPS module and display real-time detection data on a ground control station dashboard accessible from a safe distance.
4. To eliminate human exposure during landmine survey operations by replacing dangerous manual ground sweeping with a fully autonomous aerial detection system.

These are the intended objectives. They are not claimed as achieved. V2, like V1, is a guide-directed MATLAB simulation in place of physical hardware.

## 2. What V2 adds to V1

| Area | V1 (MG-xxx) | V2 (this phase) | Evidence |
|---|---|---|---|
| Flight | 2-D kinematic serpentine replay | Live 3-D quadcopter engine, 20 Hz, PREFLIGHT to COMPLETE, faults (geofence, clearance, timeout, abort) | `v2/evidence/V2-002.md` |
| Scene | Grid cells | Seeded triangulated terrain, objects, landmarks; 3-D view | `V2-003.md` |
| Sensors | Thermal and EM proxies | Contract `mg-v2-sensors/1.0`: RGB, thermal (Kelvin), LiDAR, virtual GNSS/INS with explicit invalid reasons | `V2-004.md`, `V2-005.md`, `V2-005-issue-69/` |
| Detection | Frozen fusion rules | Frozen V2-006 anomaly detector with georegistration, offline map, coverage and evidence records | `V2-006.md` |
| Dashboard | Offline 2-D playback | Live mission control: 3-D, map, RGB, thermal, LiDAR, telemetry, event inspector | `V2-007.md` |
| Export / replay | CSV export | Checksummed run package, bit-exact reproduction, playback replay, fault scenarios | `V2-008.md` |
| Audit | MG-016 | V2-009 audit of AC-001 to AC-025 | `V2-009.md` |

## 3. Results

### 3.1 Detection (the central finding, unchanged by V2-008 to V2-010)

| Set | Mode | Targets | Events | TP | FP | FN |
|---|---|---:|---:|---:|---:|---:|
| V2 VALIDATION G07 | Fused | 4 | 45 | 0 | 45 | 4 |
| V2 VALIDATION G07 | RGB-only | 4 | 19 | 0 | 19 | 4 |
| V2 VALIDATION G07 | Thermal-only | 4 | 9 | 0 | 9 | 4 |
| V2 VALIDATION G08 (target-free) | Fused / RGB / Thermal | 0 | 32 / 4 / 1 | 0 | 32 / 4 / 1 | 0 |
| V1 sealed TEST | Weighted fusion | 4 positive cells | | 0 | 26 | 4 (TN 470) |

Source: `v2/evidence/V2-006.md` §4 and `docs/FINAL_ENGINEERING_REPORT.md` §5.2. The V2 held-out TEST (G09, G10) is sealed and was **not run**; no threshold was tuned after VALIDATION.

### 3.2 Software verification (Windows only)

All on Windows 11, MATLAB R2026b Update 1, run by Claude Code for Rahil. No human watched these runs.

| Commit | Scope | Result |
|---|---|---|
| `095d7fb` | V2-007 final, 6 suites | 215/215; app check 31/31 |
| `4a7f63b` | V2-008 final, 9 suites | 305/305; app checks 31/31 and 20/20; checkcode clean |

- **Export and replay:** the nominal run's package reads back bit for bit. A replay reproduces the 84 recorded events exactly, and a re-simulation matches all 3080 samples.
- **Tampering:** changed, missing or extra files, edited samples and injected truth fields are all refused.
- **Determinism:** every paced mission gives the same sample and pose digests.
- **macOS:** NOT RUN at either final commit.

### 3.3 Performance (Windows only)

Measured on one laptop. The figures are V2-007 (`095d7fb`/`c1c1580`) and V2-008 (`bddb4c2`), with the frozen detector at its default 100-tick refresh:

- **Real time (1×):** held at 0.989–0.997× (V2-007) and 0.994×/0.959× (V2-008) when the machine was quiet and MATLAB was in front.
- **Background throttling:** in the background, Windows throttled MATLAB to about 0.3× for both versions.
- **Scene refresh:** at most 6.3–6.5 per second (V2-007) and 5.15 (V2-008). The provisional ≥ 10 target is **not met**.
- **Display only:** physics and sensors never skip a tick.

Details: `v2/evidence/V2-007.md` §3 and `v2/evidence/V2-008.md` §5.

### 3.4 Acceptance criteria

Summary of `v2/evidence/V2-009.md`: 17 of 25 criteria PASS (Windows), 4 PARTIAL (AC-005 free orbit, AC-007 noise-free georegistration, AC-009 no online map fallback, AC-011 thermal FOV not shown), 1 FAIL (AC-025, ≥ 10 FPS), 2 NOT RUN (AC-022 Shabaz's personal Mac review, AC-024 Mac run of every MUST item) and AC-023, which this report addresses (§1 and §4). **Under the acceptance matrix, V2 is not fully accepted** while AC-022 and AC-024 remain open.

## 4. Objective traceability and actual outcome

| Original objective | Supported by recorded V2 simulation evidence | Not achieved or not validated |
|---|---|---|
| **O1** pre-programmed autonomous flight | Virtual quadcopter flies takeoff, survey and landing without manual input; faults end the run visibly | Real UAV, autopilot, flight test |
| **O2** accurate subsurface detection with coil + thermal fusion | Synthetic RGB/thermal anomaly detection runs and is scored independently | **Accuracy not achieved:** 0 of 4 VALIDATION targets; no metal-detector model in V2; no buried-mine sensing |
| **O3** geo-tag and map threats, real-time GCS | Live dashboard with virtual geotags, offline map, coverage, event evidence, export and replay | Real GPS, real detector output, remote field ground station |
| **O4** eliminate human exposure | The virtual workflow illustrates stand-off aerial survey | No measured risk reduction, no clearance, no safety proof |

## 5. Limitations and risk register

See `v2/evidence/V2-009.md` §6 for the full register. The main items:
- Detection fails on held-out data; scores and uncertainties are uncalibrated.
- Georegistration uses the noise-free reference pose, so map geometry is optimistic.
- Scene refresh with the detector is 6.3–6.5 per second on Windows, below the provisional 10.
- **macOS: NOT RUN** at the final V2-007 and V2-008 commits (AC-024 not met). Shabaz's personal Mac review (AC-022) has not happened.
- No independent human reviewed the V2-008 to V2-010 work; Claude Code executed it for Rahil.
- Synthetic-to-real gap: no real sensor, terrain or target data.

## 6. Conclusions

1. **Achieved in simulation:** an integrated, deterministic, live mission simulation with four virtual sensors, a truth firewall, a frozen detector, a live dashboard, and run packages that read back, replay and reproduce bit for bit on Windows.
2. **Not achieved scientifically:** reliable anomaly detection. VALIDATION found none of the targets.
3. **Not demonstrated physically:** any part of the four objectives outside simulation.
4. **Next steps, if continued:** a new preregistered detector study with calibrated scores and a fresh held-out set; noisy-pose georegistration; a Mac run of every MUST item; display-rate work toward 10 FPS.

## 7. References

Only references already verified in this repository are used: `docs/LITERATURE_REVIEW.md` and `v2/docs/V2_SYSTEM_REQUIREMENTS.md` §9 (MathWorks R2026b documentation; Baur et al. 2026, Remote Sensing 18(13) 2182, https://doi.org/10.3390/rs18132182; Forero-Ramírez et al. 2023, https://doi.org/10.1016/j.dib.2023.109443; MineInsight, IEEE RA-L 2026, https://doi.org/10.1109/LRA.2025.3643265; IMAS 07-11, https://www.mineactionstandards.org/standards/07-11/). Their results are not MineGuard results.
