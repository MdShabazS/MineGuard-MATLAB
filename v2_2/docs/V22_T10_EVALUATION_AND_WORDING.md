# V22-T10 — Honest evaluation and wording

**Written:** 2026-11-21 by Claude Code in Shabaz's Mac session (owner Shabaz).
**Basis:**
- [deep research report](../research/V22_RESEARCH_DRONE_LANDMINE_SURVEY.md), recommendations 1–2;
- [safety and simulation notes](../research/notes/safety_ethics_simulation.md);
- IMAS 07.11 *Land release* (Ed. 2, 2026);
- IMAS 03.40 *Test and evaluation of mine action equipment*.

**Scope:** SIMULATION ONLY. Every target is a synthetic hypothesis and every event a *suspected* anomaly. The detector is the frozen V2-006 detector.

## 1. The recorded result, with honest bounds

Source: the V2.1 application check on Windows at `ccb2f9e` (`v2_1/evidence/V21-008/v21_demo_check_ccb2f9e.txt`). That run used four complete flights over each preset's default field, with targets placed by the V2.1 placement tool. Intervals were computed in MATLAB with `mgv22.evaluation.clopperPearson` and `falseAlarmRate`, the exact 95 % binomial and Poisson intervals.

| Measure | Result | 95 % interval | Meaning |
|---|---|---|---|
| Detection, all synthetic targets | **0 of 12** | **0 – 26.5 %** | The true detection rate of this detector, on such fields, is very likely below about 1 in 4. It is *not* proven to be 0. |
| Detection, targets with a surface signature | **0 of 9** | **0 – 33.6 %** | 3 of the 12 targets had no surface signature by design. No sensor could see them, so they are excluded here. |
| False alarms, three distinct fields (1.53 ha) | 176 | **115 per ha (98.7 – 133.3)** | About one suspected anomaly every 87 m², all false. |
| False alarms, all four runs (2.01 ha) | 288 | 143 per ha (127.2 – 160.8) | Counts the TRAINING_FIELD_A field twice: *target_free* and *no_signature* flew the same field with identical results. The distinct-field figure above is the headline. |

By run:

| Run | Field | Area | Events (all false) | False alarms per ha (95 %) | Targets (no-signature) |
|---|---|---|---|---|---|
| manual_rocky | ROCKY_UPLAND | 0.35 ha | 38 | 108.6 (76.8 – 149.0) | 4 (1) |
| random_dryflats | DRY_FLATS | 0.70 ha | 26 | 37.1 (24.3 – 54.4) | 8 (1) |
| target_free | TRAINING_FIELD_A | 0.48 ha | 112 | 233.3 (192.1 – 280.8) | 0 |
| no_signature | TRAINING_FIELD_A | 0.48 ha | 112 | 233.3 (192.1 – 280.8) | 1 (1) |

**Detection curve.** The recorded logs keep counts, not per-event scores. With 0 matches at every threshold, the detection-vs-false-alarm curve is flat at 0 % detection, and false alarms fall as the threshold rises. `mgv22.evaluation.detectionCurve` computes it from event scores for future runs: V22-T11 records scores.

**What this does not say:**
- It is not a measure of real landmine detection, and not a comparison with field systems.
- With 12 targets the interval is wide. More targets (§3) narrow it.

## 2. Wording rule (all V2.2 views)

`mgv22.wording()` holds the standard strings:
- **"SIMULATION – suspected anomaly, indirect evidence only"**: the label for any detector output shown to a person.
- **"No detection here does not mean the ground is free of hazards."**: shown wherever an empty map or zero detections could be misread. This follows IMAS 07.11: decisions are "based on evidence, not the lack thereof".
- **Never** in result text: *clear, cleared, safe, mine found, mine-free, hazard-free*. The test `testV22Wording` scans every user-visible string in `v2_2/matlab` for these words.

**For V22-T6 (Rahil):** the V2.1 evaluation window text (`v2_1`, `EvaluationView`) should use `mgv22.wording().suspected` and `.no_detection` when it is integrated. T10 does not change V2 or V2.1 code.

## 3. Sealed virtual test area (design for later runs)

A pre-registered test, in the spirit of IMAS 03.40 (independent, statistically sufficient trials). It is used **once**, after any detector change, and never for tuning.

| Item | Design |
|---|---|
| **Site** | A held-out synthetic field. Its terrain seed, scene seed and placement seed are never used in development; the seeds are recorded in this document before the run. |
| **Size and targets** | At least 1 ha with **at least 30 targets with a signature** plus at least 5 without. With 30 targets, a 0-detection result bounds the rate below 11.6 %, and 15 of 30 gives about 31–69 %. |
| **Clutter** | Realistic: rocks, bushes, scrap, wet patches and disturbed-soil patches with the same distributions as targets (as in `mgv21.placement.forwardFeatures`). |
| **Conditions** | At least two lighting/thermal conditions (DAY_CLEAR and LOW_CONTRAST) and two altitudes (the T11 GSD-derived altitude and 15 m). |
| **Metrics, fixed before the run** | Detection rate with a Clopper-Pearson 95 % interval, overall and per condition and target type; false alarms per hectare with a Poisson interval; the detection-vs-false-alarm curve from event scores; the 1.0 m match radius (V2); results by surface signature. |
| **Rules** | No retuning after looking. Report negative results as they are. All outputs carry the wording above. |

## 4. Summary for the guide

> In four simulated flights over 2.0 ha (1.5 ha of distinct fields), the frozen detector matched 0 of 12 synthetic targets. That means a detection rate below about 26 % with 95 % confidence, or below about 34 % for the 9 targets that had any surface signature. It raised about 115 false alarms per hectare. MineGuard is a simulation concept demonstrator; its maps show **suspected** anomalies only, and no detection does not mean the ground is free of hazards.
