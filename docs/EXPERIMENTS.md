# Experiment Protocol and Evaluation

## Experiments
E1: baseline predefined grid-path coverage, repeatability and navigation metrics.
E2: sensor physics sweeps of standoff, burial depth, soil, temperature, noise, occlusion and clutter; include negative controls.
E3: thermal-only vs EM-only vs fusion on identical held-out scenarios; fixed thresholds selected from validation set.
E4: optional supervised classifier versus mathematical threshold baseline, no train/test leakage.
E5: PPO policy vs fixed grid under same simulation budgets; include multiple seeds, variability and failure cases.
E6: cross-platform MATLAB release/toolbox compatibility (only if verified on both systems).

## Ground-truth and metrics
Synthetic truth is for evaluation only. Report TP, FP, TN, FN, precision, recall (TPR), specificity, FPR, F1, time/distance/coverage and location error; undefined denominators represented explicitly. When discussing detection rates, say **on synthetic scenarios** and state distributions.

## Reproducibility
Log: Git SHA, MATLAB release, installed toolboxes, scenario ID and seed, trained checkpoint fingerprint, data source/licence, hyperparameters, duration, export names, actual tester and logs. Do not select a test scenario after viewing results or tune on the held-out test set.

## Publication rule
Do not claim an achieved percentage until an actual experiment run exists in `tasks/evidence/` or `results/`, with enough detail to reproduce it.
