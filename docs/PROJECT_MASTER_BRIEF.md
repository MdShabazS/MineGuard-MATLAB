# MineGuard MATLAB — A-to-Z Project Master Brief
**Document version:** 1.0 (2026-10-31) · **Status:** RESEARCH/DESIGN BASELINE; not implementation evidence  
**GitHub:** https://github.com/MdShabazS/MineGuard-MATLAB · **Review:** 02 November 2026  
**Owners:** Shabaz (project lead, ChatGPT-led research/specifications/verification) and Rahil (MATLAB implementation using Claude Code, tests and evidence). Other teammates retain college membership; two are core software owners.

> The original Phase-1 *problem statement and four objectives must not be changed.* The canonical verbatim text is in [PHASE1_BASELINE.md](PHASE1_BASELINE.md). Do not replace it with a simulation-only problem statement.

## A — Aim and public value
MineGuard investigates whether an autonomous UAV-based survey concept can support **remote localization and mapping of suspected landmine-related anomalies**. Goal is to reduce the need for people to enter hazardous areas *in the proposed concept*. Real-world safety is not demonstrated by the simulation.

## B — Background and motivation
Conventional manual field inspection creates exposure to hazards and survey expense. Multiple sensing approaches are explored in research, but sensitivity depends strongly on soil, burial depth, standoff, clutter, temperature, sensors, and target materials. An animated UAV flying above a field **is not** proof of subsurface mine detection.

## C — College decision and scope change
Guide requested that the >₹1 lakh planned physical sensor integration be replaced with a **full MATLAB/Simulink simulation**, keeping the title/problem/objectives unchanged. No hardware purchasing is required for the simulation. The originally owned drone hardware is not a dependency for MATLAB work.

## D — Deliverables
1. Verbatim original problem statement and objectives.
2. Reproducible configurable 3D synthetic scenario, including targets/clutter and known evaluation truth.
3. Conventional autonomous grid-survey flight with logging and virtual coordinates.
4. Mathematical thermal + electromagnetic sensor response models with explicit physics/geometry limits.
5. Baseline thresholds, optional supervised classifier and calibrated sensor fusion with comparative evaluation.
6. PPO survey agent trained and compared against fixed grid **only if tested on actual MATLAB**; otherwise precisely marked incomplete.
7. MATLAB App Designer mission control and analysis, simulated geotags and exports.
8. GitHub repository with A-to-Z Markdown documentation, task DAG, QA evidence, reproducible cases, PR approvals.
9. Read-only guide progress portal deployed on Render **once connected/verified**.
10. Honest presentation/report with model limits, reproducibility and future physical validation plan.

## E — Evidence distinction
All statements should carry one of: [SOURCE VERIFIED] vendor documentation or real publication; [DESIGN] architecture under review; [PENDING] requires licence, model or test; [EXECUTED] accompanied by command/log/commit; [ESTIMATE] assumption without measurement. Do not promote a synthetic score to a measured field result.

## F — How a mission will work
Configuration → seeded field generator → autonomous grid survey → virtual pose/time → thermal/EM synthetic samples → time/location alignment → detector and fusion → suspected target map + confidence → report/export. PPO may replace *high-level survey cell selection*, not sensor truth or safety claims.

## G — Why the model may fail
- Low or zero EM signal at high coil-to-target distance; weak signals in conductive soils; metal-less objects invisible to coil.
- Thermal signatures may be absent, inverted or confounded by time of day, moisture, shade, clutter and image resolution.
- Classification trained on synthetic patterns might learn the synthetic generator rather than real mine signatures.
- GPS-like coordinates from a local virtual map do not establish real precision mine geolocation.
- RL optimization may degrade coverage; if it does, report this rather than selecting only favourable runs.

## H — Project architecture and independent work
See [ARCHITECTURE.md](ARCHITECTURE.md), [DATA_CONTRACTS.md](DATA_CONTRACTS.md) and [TASK_DEPENDENCY_EXPLANATION.md](TASK_DEPENDENCY_EXPLANATION.md). The 19-task machine-readable DAG authorizes only tasks with no unfinished prerequisites. Shabaz and Rahil can work in parallel on truly independent tasks.

## I — Scientific integrity
Synthetic objects are **surrogates**; GUI labels must state SIMULATION. Never display 'cleared', 'safe area', 'verified landmine' or fictional percentages as scientific measurement. A physically impossible sensor configuration is a valuable *negative* result.

## J — Judging completion
Engineering completion means actual software tests, verified task evidence, reproducibility and reviewed deliverables; not feature descriptions. See [QUALITY_GATES.md](QUALITY_GATES.md).

## K — Development priority
For the Nov 2 deadline: first a reproducible functioning end-to-end fixed-grid baseline; then physically reasonable sensor data and fusion; then UI and export; then PPO experiments if trained. This is a sequencing preference, **not** a change in target scope.

## L — Working documents
| Question | Source |
|---|---|
| What is unchanged? | [PHASE1_BASELINE.md](PHASE1_BASELINE.md) |
| What can MATLAB actually do? | [MATLAB_CAPABILITY_RESEARCH.md](MATLAB_CAPABILITY_RESEARCH.md) |
| Why are surface vs buried signatures different? | [PHYSICS_AND_FEASIBILITY.md](PHYSICS_AND_FEASIBILITY.md) |
| What research is real? | [LITERATURE_REVIEW.md](LITERATURE_REVIEW.md) |
| Which datasets can be used? | [DATASET_AND_LICENSING.md](DATASET_AND_LICENSING.md) |
| Who owns each task and why? | [TASK_DEPENDENCY_EXPLANATION.md](TASK_DEPENDENCY_EXPLANATION.md) |
| What is testable? | [QUALITY_GATES.md](QUALITY_GATES.md) and [ACCEPTANCE_MATRIX.md](ACCEPTANCE_MATRIX.md) |
| How to run/verify? | [IMPLEMENTATION_RUNBOOK.md](IMPLEMENTATION_RUNBOOK.md) |
| Which decisions remain uncertain? | [OPEN_DECISIONS_AND_RISKS.md](OPEN_DECISIONS_AND_RISKS.md) |
| What will the guide see? | [GUIDE_REVIEW_AND_DEMO.md](GUIDE_REVIEW_AND_DEMO.md) |

**End-of-document caveat:** All the above are deliverable specifications; they do not assert that a MATLAB simulation, training session, deployment or device test has already succeeded.
