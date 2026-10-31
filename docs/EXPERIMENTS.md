# Experiment Protocol and Evaluation

**MG-008 authoritative fusion, split, metric-unit and acceptance contract:** [MG008_FUSION_DATASET_AND_METRICS.md](MG008_FUSION_DATASET_AND_METRICS.md). **Do not mix cell-unit confusion counts with object-event matching counts** in one result; real MATLAB fusion test execution belongs to MG-009.

## Experiments
E1: baseline predefined grid-path coverage, repeatability and navigation metrics.
E2: sensor physics sweeps of standoff, burial depth, soil, temperature, noise, occlusion and clutter; include negative controls.
E3: thermal-only vs EM-only vs fusion on identical held-out scenarios; fixed thresholds selected from validation set.
E4: optional supervised classifier versus mathematical threshold baseline, no train/test leakage.
E5: PPO policy vs fixed grid under same simulation budgets; include multiple seeds, variability and failure cases.

**MG-012 E5 authoritative definition:** [MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md](MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md). PPO is an optional MG-013 training task; MG-005 is the compulsory fixed-grid benchmark. Use same actual pose-level legal cell/coverage metric, initial conditions, max time/distance, sensor limits and scenario-group held-out seeds. Lock checkpoint/hyperparameters on VALIDATION only; report paired per-scenario coverage/time/distance deltas, variation, violations, budget exhaustion and PPO underperformance. P-01…P-20 are specified tests, **not executed by MG-012**.
E6: cross-platform MATLAB release/toolbox compatibility (only if verified on both systems).

## Ground-truth and metrics
Synthetic truth is for evaluation only. **Primary `ExperimentResult.tp/fp/tn/fn` uses one evaluable legal survey cell as its unit**, so true negatives are meaningful. Report cell-unit precision, recall, FPR and F1 with explicit zero-denominator NaN values, denominators, and excluded/unassessed cells. Separately report one-to-one event-to-hidden-target localization matching, object-event misses and unmatched alarms; **never combine event-level TP/FP/FN with cell-level TN**. Details and edge-case tests are fixed in the MG-008 contract. When discussing detection rates, say **on synthetic scenarios** and state distributions.

## Reproducibility
Log: Git SHA, MATLAB release, installed toolboxes, scenario ID and seed, trained checkpoint fingerprint, data source/licence, hyperparameters, duration, export names, actual tester and logs. Do not select a test scenario after viewing results or tune on the held-out test set.

## Publication rule
Do not claim an achieved percentage until an actual experiment run exists in `tasks/evidence/` or `results/`, with enough detail to reproduce it.
