# Suggested Academic Report / Review Deck Structure
**Plan only:** actual figures/results to be inserted after code execution. This does NOT replace original title/problem/objectives.

## Report structure
1. **Title and institution details** — copy college-approved template and members, do not expose private identifiers in public GitHub beyond approved academic names.
2. **Abstract** — state simulation study, targeted UAV workflow, thermal/EM modelling, AI techniques, no field certification.
3. **Chapter 1 Introduction** — landmine threat problem, why remote survey desirable, cost-driven implementation transition, original statement.
4. **Chapter 2 Problem Statement and Objectives** — paste canonical text from [PHASE1_BASELINE.md](PHASE1_BASELINE.md) word for word.
5. **Chapter 3 Literature Review** — verified DOI-bearing publications, evidence/limits, compare sensor modalities; unverified original Phase-1 bibliography excluded from claims.
6. **Chapter 4 Research Gap and System Requirements** — aerial standoff/subsurface conflict, reproducibility need, FR/NFR requirements.
7. **Chapter 5 Proposed MATLAB Architecture** — modules, block diagram, coordinate/time/data contracts, virtual scene, autonomous grid mission.
8. **Chapter 6 Modelling and Algorithms** — soil thermal transport assumptions; EM standoff response; sensor noise; fusion/classifier; PPO formulation.
9. **Chapter 7 Implementation** — actual software/version, key screenshots, code links, model versions; do not fabricate.
10. **Chapter 8 Experimental Setup** — scenario parameters, noise/soil sweeps, data splits, baselines and metrics.
11. **Chapter 9 Results and Discussion** — *only real executed outputs* with quantitative metrics, failure cases, runtime, PPO/fusion ablations.
12. **Chapter 10 Limitations and Future Work** — simulation vs field, sensor limitations, missing real data, calibration/near-ground physical sensing.
13. **Conclusion** — what was actually demonstrated; no unverified safety promises.
14. **References** — complete publisher verified bibliography and dataset licensing.
15. **Appendices** — GitHub runbook, seed table, unit tests, samples, CI and provenance.

## Figure plan (placeholders until generated)
- F1: Model architecture block diagram — design draft may be created immediately.
- F2: Seeded synthetic 3D test area — include only actual MATLAB output once implemented.
- F3: Grid route and coverage map — based on actual run.
- F4: Thermal/EM response vs depth and altitude sweeps — executed data only.
- F5: Confusion matrix thermal-only, EM-only and fused — held-out actual results only.
- F6: PPO reward/training trajectory and baseline comparison — only trained log.
- F7: MATLAB mission-control screenshot — tested actual UI.
- F8: GitHub guide observatory screenshot — actual deployed site or local browser test explicitly labelled.
- F9: Scope/limitations evidence matrix.

## Slide deck (12–15 slides)
1. Title; 2. Problem; 3. Four original objectives; 4. Why MATLAB; 5. Literature/gap; 6. Architecture; 7. Environment/mission; 8. Sensing models; 9. Fusion/classifier; 10. PPO comparison; 11. Dashboard; 12. Tests/results; 13. Limitations; 14. Conclusions; 15. Q&A.

## Abstract writing guardrails
Use 'proposed', 'simulated', 'evaluated on synthetic scenarios', and 'suspected anomaly'. Replace generic future-tense only where tests executed. No claim of 'validated buried mine detection' or 'mine clearance'.

## Technical formatting guide
Use clear hierarchy, numbered figures and tables, standard SI units, consistent axis labels, citations to papers and versioned MATLAB code/experiment metadata. Cross-check numbers in text against actual plots/CSV before submission.
