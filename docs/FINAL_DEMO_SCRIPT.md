# MineGuard — Final Presentation and Live Demo Script
**Task:** MG-018 · **Prepared:** 2026-11-01 IST · **Target length:** 10–12 minutes plus viva  
**Audience:** Academic guide and project reviewers · **Software:** MATLAB R2026b desktop  
**Version basis:** MG-017 release candidate on merged main (tag `v1.0.0-rc.1` still **uncreated**)

> **Presenter rule:** Say **simulation**, **virtual**, **synthetic** and **SUSPECTED** consistently. The S0 dashboard is an attractive **display fixture**; use the **negative sealed held-out results** for scientific conclusions. The app is a **2-D offline replay**, not a 3-D real-time drone GCS. Do not rerun sealed TEST, retune thresholds or present a map as cleared land.

## A. Before the guide arrives (operator checklist)

- Confirm a **clean GitHub checkout** of the reviewed release-candidate source; record `git rev-parse HEAD`. Do not claim a release tag exists until separately authorized.
- Have MATLAB R2026b open with the repository root as Current Folder and a usable display. Core S0 requires base MATLAB; **PPO needs RL and Deep Learning Toolboxes**.
- Confirm the path and demo function without touching experimental TEST:

  ~~~matlab
  addpath('matlab');
  which mineguardDemo -all
  ~~~

- Keep [final engineering report](FINAL_ENGINEERING_REPORT.md), [MG-017 release notes](RELEASE_NOTES_v1.0.0-rc.1.md), [MG-016 evaluation audit](../tasks/evidence/MG-016.md) and [MG-019 PPO evidence](../tasks/evidence/MG-019.md) available.
- Pre-open the recorded [S0 completed dashboard screenshot](../tasks/evidence/MG-017/MG-017-03-demo-S0-complete.png) and [PPO comparison screenshot](../tasks/evidence/MG-017/MG-017-04-ppo-comparison-7307.png) **as labelled backups**, not fabricated live sessions.
- Keep the negative held-out table visible on a page or slide. Do not ask MATLAB to recalculate it.
- If presenting from a Mac without PPO dependencies, **skip the PPO live command** and show the archived Windows benchmark evidence instead. Do not claim macOS full regression passed.
- Prepare an export destination with write permissions; do not overwrite any frozen evidence folder. Keep sensitive student names/licence details off projected screens.

## B. Timed presentation: exactly what to say and show

### 0:00–0:50 — Opening and problem

**Say:**  
“Good morning. Our project is *MineGuard — Autonomous Aerial Landmine Detection System*. The original purpose was to investigate whether an autonomous UAV could survey a suspected hazardous field while reducing human exposure. The key challenge is that *scanning a field is not the same as accurately identifying a buried mine*. Our guide-directed implementation is a MATLAB research simulation; the original four objectives are retained, and we will be clear about which parts are validated only virtually.”

**Show:** Official title, problem statement and **verbatim** objectives in [PHASE1_BASELINE](PHASE1_BASELINE.md). Do not alter the wording to make unachieved objectives appear achieved.

### 0:50–1:50 — Objectives and architecture

**Say:**  
“We organized the software into a seeded synthetic scene, a fixed-grid survey planner, virtual UAV poses, two simplified sensor models—thermal and electromagnetic—anomaly-detection and fusion algorithms, a separate scoring system, and a MATLAB mission-replay dashboard. Ground-truth target labels are reserved for the physics generator and evaluator; the detector and public dashboard do not get the hidden labels.”

**Show:** This exact block diagram. Point left-to-right:

~~~text
Synthetic scene -> fixed grid -> virtual poses -> thermal + EM observations
                                                     |
                                              frozen detector
                                                     |
                                            SUSPECTED anomalies
                                                     |
                           2-D offline MATLAB replay + redacted export
                                 (truth -> separate evaluator)
~~~

**Transition:** “I will demonstrate the navigation and visualization first. Then I will show the actual held-out scientific results, including failures.”

### 1:50–4:30 — S0 software demonstration (display fixture)

**Command from repository root in MATLAB Command Window:**

~~~matlab
addpath('matlab');
mineguardDemo
~~~

**Say while launching:**  
“This S0 scenario is a synthetic **display fixture**, not the final test. It runs a smaller-cell, low-altitude example chosen so the audience can see the mission and sensor graphs. The software produces a complete virtual mission and opens the actual MATLAB UI.”

**Point to the dashboard:**
1. **Mission/route view:** “This is the serpentine grid. The recorded fixture has 400/400 covered cells. It demonstrates survey coverage, not mine-detection accuracy.”
2. **Pose/telemetry panel:** “These are *virtual* positions and times. They are not GNSS readings from a physical aircraft.”
3. **Thermal and EM graphs:** “Thermal is an assumed forward model in kelvin; EM is a normalized proxy, not a physical coil measurement.”
4. **Events table/map:** “Every candidate is labelled **SUSPECTED**, not confirmed.”
5. **Evaluation panel:** Point to the line “DISPLAY FIXTURE … NOT held-out performance” and the separate line “Locked held-out TEST ... NEGATIVE.”

**Operate:**
- Press **Play Simulation**; show a few seconds at 20×.
- Press **Pause**, use **Step**, and **Seek** to approximately 50 seconds.
- Resume playback or seek to the final pose; point to **COMPLETE**.
- Optional: click **Export run data** into a new writable folder; explain the seven redacted artifacts (`poses.csv`, `thermal_samples.csv`, `em_samples.csv`, `events.csv`, `summary.json`, `run_bundle_redacted.mat`, `snapshot.png`).
- If running live from a fresh clone takes too long, use the committed screenshots and state that they are **earlier recorded execution evidence**.

**Do not say:** “We detected five mines”, “our detector is 100% accurate”, “real-time drone data”, “3-D twin” or “this area is safe.”

### 4:30–6:25 — Scientific result: demonstrate rigorous, negative evidence

**Show:** The [MG-016 reconciled table](../tasks/evidence/MG-016.md), **not** an invented positive scenario.

**Say:**  
“We predeclared 30 scenario families: 18 TRAIN, six VALIDATION and six sealed TEST. We executed the sealed TEST exactly once. Under the prespecified common cell mask, 500 cells were assessable: four positive and 496 negative. The main **weighted fusion** method gave **zero true positives, 26 false positives, 470 true negatives and four false negatives**. Therefore, its recall and precision are zero on this locked test. The OR method detected all four positive cells but generated **439 false-positive cells**, so high recall came at an unacceptable false-alarm burden.”

**Point to this small comparison:**

| Prespecified TEST method | TP | FP | TN | FN |
|---|---:|---:|---:|---:|
| Weighted / single_valid (primary) | **0** | **26** | **470** | **4** |
| Thermal-only | 3 | 179 | 317 | 1 |
| EM-only | 0 | 116 | 380 | 4 |
| OR | 4 | 439 | 57 | 0 |
| AND | 0 | 16 | 480 | 4 |

**Say:**  
“The 5 m weak-standoff test profile did not contribute assessable cells to this common-mask comparison because the EM model was out of its permitted domain. That is missing/invalid evidence, not a negative sensor reading. Under triple noise, the weighted method's false-positive rate reached approximately 94%; with shifted soil/background, 100%. These results tell us that our locked simulated sensing configuration is **not reliable**. This is the central research conclusion.”

**Optional one-sentence viva definition:** “Precision is TP divided by all predicted positives; recall is TP divided by all actual positives; FPR is FP divided by all actual negatives.”

### 6:25–7:40 — Reinforcement learning comparison (optional)

**Only if Reinforcement Learning and Deep Learning Toolboxes are installed and the frozen checkpoint is present:**

~~~matlab
mineguardPPODemo(7307)
~~~

**Say:**  
“We also trained and froze a PPO survey-cell policy. We compared it with the conventional grid route on fresh preregistered scenarios. Of 20 evaluation scenarios, only eight had a feasible fixed-grid route, making those eight the valid paired comparison. The grid covered all target legal cells; PPO averaged **93.8%**, lost all eight paired comparisons, and completed **zero of the 20 PPO evaluation missions**. We therefore kept fixed-grid as the default and clearly marked PPO experimental.”

**Show:** [Recorded PPO comparison](../tasks/evidence/MG-017/MG-017-04-ppo-comparison-7307.png) if PPO isn't available on the current host. Explain that it is a **recorded Windows run** and not a fresh benchmark. On the 7307 case, grid coverage = 1.000 and PPO = 0.960.

**Do not claim:** “PPO optimized mine detection”, “reinforcement learning outperformed the baseline”, or “all 20 scenarios are matched comparisons.”

### 7:40–8:45 — Engineering reproducibility and evidence

**Say:**  
“Reproducibility was part of the project. The team retained code, pinned experiment configuration and model files, seed information, separate training/validation/test splits, an approval record for the sealed TEST, MATLAB screenshots, exports and regression logs. The owner-recorded clean Windows R2026b test run passed **153 out of 153 tests**, while GitHub CI separately checks governance and the guide portal; GitHub CI **does not run MATLAB**.”

**Show:** [Rahil's clean-clone log](../tasks/evidence/MG-017/regression-clean-clone-f65af49.txt), [export/screenshot evidence](../tasks/evidence/MG-017.md) and the authoritative GitHub task status. Do not claim you personally ran the 153 tests unless you actually did.

### 8:45–10:00 — Objective grading, limitations and conclusion

**Say:**  
“Objective one is demonstrated as a virtual autonomous grid survey, not physical flight. Objective two is implemented as an experimental pipeline, but **accurate detection was not achieved** on the locked synthetic TEST. Objective three is demonstrated as virtual mapping and **offline replay**, not physical GPS or live remote telemetry. Objective four is a future safety motivation illustrated by the simulation, not a measured personnel-safety benefit.”

**Say:**  
“We did not implement the advanced 3-D drone view, real camera/coil/RGB/LiDAR hardware, Raspberry Pi data collection or live ground control station in this release. A next-stage study would require realistic geometry, calibrated sensing, a **new preregistered holdout**, more credible drone dynamics and physical safety validation. We will not treat the consumed TEST as a tuning set. The main contribution is a reproducible engineering pipeline that honestly identifies why the current simulated mine-sensing approach fails.”

**Close:**  
“Thank you. We welcome questions on the navigation contract, sensor limitations, evaluation split, false positives, PPO performance and requirements for real-world validation.”

## C. Viva: short, defensible answers

| Question | Answer in one or two sentences |
|---|---|
| Does MineGuard really detect buried landmines? | **No.** It currently models synthetic target-related signals and reports suspected anomalies; its held-out detection performance was negative. |
| What is the real achievement? | An integrated seeded virtual survey, synthetic sensing, truth-separated detector/evaluator, dashboard, export, and reproducibility evidence. |
| Why use MATLAB instead of hardware? | It enables controlled experiments and feasibility analysis within the guide-directed scope and budget, without making premature field-safety claims. |
| What are the two sensors? | A modeled thermal surface-response channel in kelvin and a normalized electromagnetic/metal-coil-response proxy, **not actual hardware measurements**. |
| Why is EM invalid at 5 m? | The assumed proxy sensitivity/standoff domain is exceeded; the software correctly marks readings `MODEL_OUT_OF_DOMAIN` instead of inventing a usable signal. |
| What is sensor fusion? | Combining permitted sensor observations under frozen rules: thermal-only, EM-only, OR, AND and weighted scoring. No rule succeeded usefully in the locked TEST. |
| If coverage is 100%, why is the detector unsuccessful? | Coverage is how much virtual ground the path visits. Detection measures correctly identifying positives without excessive false alarms—two different objectives. |
| Is the confusion matrix measured from the S0 demo? | **No.** The report's TP 0/FP 26/TN 470/FN 4 is from the separately sealed and once-executed synthetic TEST. |
| Why not change the threshold now? | The held-out TEST has been consumed. Any retuning would require a new preregistered experiment and genuinely fresh held-out data. |
| Is OR better because recall is 100%? | No. It issued 439 false positives on 496 negative cells; precision was about 0.9%, so the apparent recall comes with many false alarms. |
| What happened to GF-030? | It was unassessable under the common five-method mask because EM readings were outside the model domain; these cells are excluded, not counted as true negatives. |
| Did reinforcement learning train? | Yes, the separately recorded PPO checkpoint and MATLAB inference were tested. But PPO lost all eight matched feasible comparisons. |
| Does PPO choose flight motor commands? | No. It selects a high-level survey cell under a limited 5×5 action contract; low-level aircraft control is outside the implementation. |
| Is the dashboard real time? | It animates saved virtual mission data in MATLAB; it is **offline replay**, not a live UAV-to-ground-station stream. |
| Are the map coordinates GPS? | They are virtual local/georeferenced coordinates, not measurements from a physical GNSS device. |
| What happens if there is no useful sensor response? | The sensor is marked invalid (with NaN and an explicit reason), and the detector must not silently treat missing observations as a measured zero. |
| Are the 153 tests proof of landmine accuracy? | No. They are recorded software-regression tests; the locked accuracy evaluation is separate and negative. |
| Why is a 3-D simulation not shown? | 3-D replay is **not implemented in this release**. The current verified UI is 2-D and must be described accurately. |
| What would be necessary before real operation? | Controlled sensor calibration, representative data, a new independent held-out study, UAV and telemetry validation, operational safety assessment and relevant approvals. |
| What is the strongest conclusion? | We engineered a repeatable end-to-end synthetic research platform and identified the limitations of the tested thermal/EM geometry rather than hiding negative results. |

## D. Demonstration recovery and no-false-claim fallbacks

| Problem on presentation day | What to do safely |
|---|---|
| `mineguardDemo` not found | Set Current Folder to repository root; run `addpath('matlab')`, then `which mineguardDemo -all`. |
| App/graphics won't open | Show the archived screenshot labelled “recorded Windows MATLAB execution” and the console/evidence; never imply live execution occurred. |
| Missing PPO toolboxes or checkpoint | Do not run PPO. Show [MG-019](../tasks/evidence/MG-019.md) and its recorded comparison screenshot; mark optional feature unavailable on this host. |
| Export destination isn't writable | Choose an existing writable output folder outside the repository; don't write to `tasks/evidence/MG-015`. |
| Asked to rerun sealed TEST | Refuse. Show the precommitted held-out CSV and once-only approval/evidence; explain a fresh study is required. |
| Asked to show actual mines or cleared ground | State explicitly that the system uses synthetic targets, suspected events and **cannot declare any ground safe**. |
| Asked for live 3-D drone view or RF telemetry | Explain honestly that those are future scope, not implemented in the current release. |

## E. Guide handover / acceptance matrix

Use the [final report](FINAL_ENGINEERING_REPORT.md) and [MG-018 task evidence](../tasks/evidence/MG-018.md) to hand over the unchanged objectives, source/commit, README/release notes, MATLAB demo steps, source-backed quantitative comparisons, screenshot evidence, explicit gaps and proposed next experiment.

**Presentation readiness checks (documentation, not newly executed MATLAB tests):**
- [x] Original objectives and problem statement preserved verbatim.
- [x] Live-demo command and safe fallback specified.
- [x] Actual held-out negative data shown apart from the display fixture.
- [x] PPO status and matched-pair denominator disclosed.
- [x] 2-D/offline status, portability and missing hardware declared.
- [x] Sealed TEST never rerun as a demo.
- [x] Evidence links and viva questions prepared.
- [ ] Guide presentation delivered and independently accepted — **PENDING; never assert an approval before it occurs**.
