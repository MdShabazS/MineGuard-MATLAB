# MG-012 — PPO Survey Policy, Reward and Fair Benchmark Contract

Task: MG-012
Owner: Shabaz
Date: 2026-10-31
Kind: DOCUMENTATION SPECIFICATION — not a trained agent, run or achieved PPO improvement
Dependency: MG-005 DONE on protected `main`.
Downstream: MG-013 PPO build (MG-005 and MG-012 DONE); MG-014 locked experiment plan (MG-008 and MG-012 DONE). MG-019 optional PPO integration depends on MG-013 and MG-015.

**Normative references:** [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md), [AI_AGENTS.md](AI_AGENTS.md), [MG008_FUSION_DATASET_AND_METRICS.md](MG008_FUSION_DATASET_AND_METRICS.md), [ACCEPTANCE_MATRIX.md](ACCEPTANCE_MATRIX.md), [RESEARCH_PLAN.md](RESEARCH_PLAN.md). This design preserves `mg-contract/1.0`; no frozen API signature or record field is changed. The fixed-grid/kinematic navigation baseline is already implemented in MG-005.

**Research boundary:** A PPO policy may optimize a **synthetic survey trajectory**; it does **not** detect a landmine, validate an actual air vehicle, improve real-world mine-clearing safety or prove a buried-object sensor works at height. The principal scientific comparison is **unobserved-grid-cell coverage vs travelled distance and mission time under equal budget**, not a claim of operational threat identification.

## 1. Scope, gates and go/no-go order

**Baseline is mandatory:** `mineguard.navigation.makeGridRoute(navConfig,geometry)`, `simulatePose(navConfig,geometry,route)`, and `computeCoverage(navConfig,geometry,poses)` under MG-005. PPO is an **optional research track**. Core demo integration MG-015 and first report must not wait for a trained PPO or a fictional score.

**MG-012 delivers the specification only.** Rahil's MG-013 implements/tests a real custom MATLAB environment, `selectSurveyCell`, PPO training and a paired held-out benchmark; MG-019 optionally integrates the trained agent with the complete MG-015 detector/dashboard. If no valid checkpoint or training is completed, label PPO **NOT TRAINED / NOT RUN**, report partial tests, and use the proven fixed grid for demos. Do not claim MG-013 DONE from task-gate CI alone.

**Initial stage:** flat synthetic S0 with fixed 2-D grid size and same kinematic constant-speed/altitude model as MG-005. Variable terrain, 3-D route optimization, obstacle avoidance beyond tested exclusion polygons, adaptive sensor scheduling, energy dynamics and physical UAV control are **out of scope** until separately specified and tested.

## 2. Frozen function and proposed view-only records

The only frozen PPO-facing public API is:

```matlab
action = mineguard.rl.selectSurveyCell(observation, allowedCells, policy);
```

The MATLAB file is `matlab/+mineguard/+rl/selectSurveyCell.m`. `observation`, `allowedCells` and `policy` below are **proposed MG-013 adapter representations**, not modifications to the existing `mg-contract/1.0` MATLAB tables. They must be versioned in MG-013 and validated with executable tests.

| Input/output | Proposed structure and required properties |
|---|---|
| `observation` | View-only struct: `schema_version`, `scenario_id`, normalized current ENU position (or current cell index), visited legal-cell binary mask, current allowed/reachable mask, remaining distance/time fractions, normalized elapsed time, and optional **observation-derived** thermal/EM uncertainty with explicit validity/missing mask. Fixed numeric vector layout for a given trained policy, with recorded layout/version. |
| `allowedCells` | Deterministic, **same ordered grid** as the baseline: cell ID/index `1..N`, centre ENU [m], `is_legal`, `reachable_from_current`, and `is_visited`. Excludes forbidden cells; preserves mask and all IDs across an episode. ID-to-cell-centre conversion must match MG-005 `gridCells` even when bounds are not an exact spacing multiple. |
| `policy` | A trained checkpoint or explicit safe, **untrained** test policy with version/checksum, observation layout ID, action/cell-index mapping and training split provenance. It contains no hidden truth, target coordinates or test-set labels. |
| `action` | One deterministic discrete cell index/ID referring to `allowedCells`; preserve integer type and no imaginary waypoints or aircraft-control commands. Invalid/unreachable actions cannot silently become legal actions. |

**Fixed-size first:** MATLAB PPO policy observation/action dimensions are fixed at construction. For MG-013 begin with one fixed, modest grid size (e.g. **5×5 as a test design suggestion**, not a built/trained result), and identical cell resolution for **both** PPO and grid benchmark. Changing grid dimensions requires separate policy/action specs, retraining or an explicitly tested padding/masking scheme; do not feed different cell-count vectors to a fixed network. For a fixed `N`, the action spec is a discrete finite set `1:N`, and the observation numeric spec has a declared constant length. Never claim a built-in action mask in `rlPPOAgent`; the custom environment MUST independently reject invalid actions.

**Protected truth firewall:** PPO observation, action-policy evaluation and *reward* must not access `Scenario.hidden_truth`, `TargetTruth`, `label`, `target_id`, buried depths, target counts/positions or evaluator-only split labels. An environment implementation may hold restricted simulator truth **only inside the forward sensor physics** to generate public observations; those are consumed by an allowlisted projection. The PPO training agent and reward callback must never receive this private object or labels. In particular, **no target-hit reward, shortest path to target, hidden occupancy hint or ground-truth anomaly map** is allowed. Sensor-derived uncertainty is optional and must carry missing/invalid flags; it cannot be computed from withheld truth.

The fixed route receives only `NavigationConfig` and `ScenarioGeometry` (as MG-005 already enforces). PPO is permitted the *same safe geometry* and historical observable sensor stream, not extra private state or a different navigation precision model. Uncertainty/EM observations from MG-007/MG-009 are not required for a **coverage-only** initial PPO proof; omit that feature or explicitly mark it unavailable if not implemented. Do **not** silently insert hidden labels or mark missing sensor values as zero.

## 3. Environment dynamics, legal actions and episode lifecycle

**Geometry:** `bounds_enu_m=[x_min x_max y_min y_max]`, centre-grid subdivision `nx=ceil((x_max-x_min)/grid_spacing_m)`, `ny=ceil((y_max-y_min)/grid_spacing_m)` following MG-005's floating tolerance convention. Cell-centre x/y and actual pitches are computed as in `gridCells`. A cell is legal only if its centre is outside exclusion polygons; a direct transition is legal only if the **entire straight-line leg** to the centre is within bounds and does not touch, cross or run along an exclusion polygon. This matches the exact segment/intersection semantics added to MG-005, not a sampled approximation. To avoid private MATLAB helpers, MG-013 can reuse an authorized public validator or implement a separately tested equivalent; do not bypass private helper visibility.

**Action meaning:** select the next reachable legal **survey cell centre**, at the same configured altitude. PPO controls waypoint selection ONLY, not roll/pitch/yaw, sensor truth, or low-level autopilot. Moving to an already visited legal cell is allowed but earns no new-coverage credit and incurs movement/revisit cost. Exclusion, out-of-bounds, unreachable or malformed actions are **rejected without changing position**, receive a bounded penalty/time step and produce an explicit event log. Neither the evaluator nor the GUI should silently reroute an illegal action. If none are reachable, terminate `NO_LEGAL_ACTION` with partial coverage rather than making up a route.

**Travel accounting:** for a legal leg, length `L_m=hypot(dx,dy)` at constant altitude, transit duration `Delta_t_s=L_m/speed_mps`. Integrate intermediate pose samples consistent with `dt_s`/MG-005 semantics; validate legal segments and timestamps. If direct single-leg calls to `simulatePose` reset `t_s` or `pose_sample_id`, use an orchestrator adapter to produce globally monotonic time and unique IDs instead of pretending repeated local per-leg IDs are globally unique. Unvisited cells crossed en route may count as visited **only under the same sampled-pose coverage rule as the grid baseline**; do not count waypoint intent as coverage. Record all positions and actual valid surveyed cells, not only endpoints.

**Equal budget:** establish and freeze prior to training a shared mission budget: same initial legal location/heading (heading if modeled), constant speed/altitude/step, permitted area and exclusions, maximum travel distance `D_max`, max mission duration `T_max`, and max allowed decisions/poses where applicable. A leg exceeding remaining budget is **not executed beyond the budget**: reject+terminate with `BUDGET_EXHAUSTED` or traverse only a precisely simulated legal partial leg if both methods support it with the same rule. For each episode, use a fixed advertised policy and account wall-clock and simulated time separately.

**Termination states (proposed MG-013, not a MG-003 enum change):** `COVERAGE_GOAL` when all legal evaluable cells visited, `BUDGET_EXHAUSTED`, `MAX_STEPS`, `NO_LEGAL_ACTION`, `INVALID_SCENARIO` or `FAILED` with actual cause. If RL framework needs one boolean `IsDone`, preserve a separate reason in environment log. Do not present `COMPLETE` as proof of 100% coverage without a measured `coverage_fraction`.

**Baseline caveat:** MG-005 `makeGridRoute` **rejects** routes with excluded-zone crossings; it does not reroute. Either select shared scenarios with a viable baseline, or report paired **baseline infeasibility explicitly**; do not give PPO access to an obstacle-cleared path while treating a failed fixed grid as zero performance. Preserve paired feasible-case analysis and distinct infeasible-case counts.

## 4. Observation projection and normalization

The training input should include only observable, deterministic safe state:

| Feature | Unit/range | Origin and restriction |
|---|---|---|
| Current x,y | normalized [0,1] over scenario bounds | Latest synthetic pose estimate/known survey coordinate, not target position |
| Visited-cell mask | `N×1` binary | Observed legal pose history under MG-005 cell definition, not hidden target occupancy |
| Legal/reachable action mask | `N×1` binary | Geometry and exact transition test, not hidden object locations |
| Remaining time and distance fractions | each [0,1] | Simulated resource ledger only |
| Elapsed-time fraction | [0,1] | `t_s/T_max` clamped from recorded log |
| Optional observation uncertainty | `N×1` normalized plus `N×1` availability | Only if calculated causally from prior valid sensors/detector without evaluator truth; absent modality must remain explicit |

Proposal for *coverage-only* initial vector layout: `[x_norm,y_norm; visitedMask(N); reachableMask(N); remainingTime,remainingDistance,elapsedTime]`, length `2*N+5`. If additional features are implemented, define a new layout version and retrain; do not change vector size midway. The mask and position must be consistent with the chosen action mapping and saved policy version.

Scale/normalizer, grid shape, clipping, any optional uncertainty features and dynamic action semantics must be trained or frozen on TRAIN/VALIDATION only. Do not fit normalizers on held-out TEST. Preserve deterministic tie-breaks for grid indexing and simultaneous observations; invalid or NaN inputs are rejected or represented by an explicit missing-feature mask, never silently treated as evidence of absence.

## 5. Reward — observable coverage, non-hazardous cost only

Define one fixed scalar per transition with **non-secret** inputs:

```text
DeltaC  = (newly_visited_legal_cells) / N_legal
DeltaL  = valid_transit_distance_m / D_max
DeltaT  = valid_transit_time_s / T_max

r_t = + w_cov    * DeltaC
      - w_dist   * DeltaL
      - w_time   * DeltaT
      - w_visit  * I(chose_already_visited_cell)
      - w_bad    * I(action_invalid_or_unreachable)
      - w_step   * I(each_decision)
      - w_end    * I(terminated_by_invalid_or_budget_failure)
```

All weights must be **nonnegative, finite and versioned**; reward itself must be finite. A permissive illustrative unit-test choice (not validated for training): `w_cov=1`, `w_dist=0.1`, `w_time=0.1`, `w_visit=0.02`, `w_bad=0.1`, `w_step=0.001`, `w_end=0.05`; verify the relative scales of total episode terms and tune only against TRAIN/VALIDATION. These are educational parameters, **not empirically fitted physical utility weights**. Reward depends on **actual new coverage**, not route length alone, and is positive only for new valid legal cells visited under a shared coverage definition. Penalties on invalid actions must still advance an explicit decision/time budget (or count max steps) so an RL loop cannot exploit free infinite retries.

**No target-reward shortcut.** No label, withheld truth, object proximity, true detection, or test-set localization error can appear in reward; target count/placement also cannot influence mission-budget constraints. Optional reward shaping must be a potential based solely on public visited/budget state, with logged formula and ablation; do not reverse-engineer hidden truth by using evaluator information.

**Policy value vs scientific objective:** coverage, simulated distance and time are primary endpoints. Fusion detection metrics can be evaluated on held-out routes *after* observations are generated, but cannot be used for reward unless a future, independently reviewed observation-only reward amendment exists. Avoid comparing detection sensitivity when visit distributions or observed-cell denominators differ without explicitly reporting those denominators.

## 6. MATLAB R2026b implementation handoff (MG-013, NOT executed here)

**Licensed capability evidence:** Rahil's [MG-002 evidence](../tasks/evidence/MG-002.md) records installation and smoke tests of Reinforcement Learning Toolbox, Simulink and UAV Toolbox in R2026b. It does **not** establish a trained policy, valid drone controller or measured training cost.

**Use documented APIs with actual tests:**
- `rlNumericSpec([2*N+5 1])` for fixed observation size and `rlFiniteSetSpec(1:N)` for discrete cell actions (proposed).
- `rlFunctionEnv(obsInfo,actInfo,stepFcn,resetFcn)`, with reset returning `[InitialObservation,EnvData]` and step returning `[NextObservation,Reward,IsDone,EnvData]`. MATLAB validates custom environments at creation; also execute `validateEnvironment` and separate impossible-action tests.
- `rlPPOAgent(obsInfo,actInfo)` or explicit `rlPPOAgentOptions` and actor/critic configuration. The discrete action spec **does not remove responsibility** for per-state legality checks. Use `rlTrainingOptions` for actual episodes/steps, a saved checkpoint and training statistics.
- For deterministic **evaluation**, use a documented fixed action-selection mode (e.g. `UseExplorationPolicy=false`) if applicable to the tested R2026b agent and save that setting; for stochastic evaluation record policy sampling seeds and repetitions. Training still uses exploration.
- A recorded feature layout/version, reward weights, model hyperparameters (learning rate, discount, clip factor, mini-batch/experience horizon, actor/critic specs), optimizer/training seeds and checkpoint checksum are mandatory.

**Implementation stages:**
1. No-RL deterministic `reset`/`step` with legal-cell selection, timed transitions, exclusion tests, reward decomposition and termination reasons. Run standalone tests before training.
2. Core PPO environment with `validateEnvironment`, a very small dry-run, observed actual gradient/training episodes and saved model; do not confuse a constructed agent with a trained one.
3. Controlled train/validation/held-out scenarios, fixed checkpoint selection by VALIDATION only, and paired route benchmark against MG-005.
4. Optional independent MG-019 integration only after MG-015 real end-to-end baseline exists.

Official R2026b references checked 2026-10-31:
- MathWorks PPO Agent (discrete/continuous agent, stochastic training, evaluation policy): https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlppoagent.html
- PPO training algorithm: https://www.mathworks.com/help/reinforcement-learning/ug/proximal-policy-optimization-agents.html
- `rlFunctionEnv` and step/reset signatures: https://www.mathworks.com/help/reinforcement-learning/ref/rl.env.rlfunctionenv.html
- RL training options: https://www.mathworks.com/help/reinforcement-learning/ug/train-reinforcement-learning-agents.html

These documentation sources are support for API selection, **not executed MG-013 test evidence**.

## 7. Fair paired experiment protocol — E5, MG-013 and MG-014 handoff

**Sample/split unit:** use **scenario-group-disjoint** TRAIN, VALIDATION and sealed TEST, consistent with MG-008 §4. Group by all shared underlying target layout/world seed/derivative noise seeds, not by frames or individual trajectories. Do not generate new test worlds conditioned on a promising PPO result. Archive signed/hashed split manifest *before* test. Candidate `60/20/20` scenario-group fraction is a proposal from MG-008, not an achieved dataset.

**Paired fixed-grid/PPO conditions** must be identical per scenario group:
1. Exact same legal region, cell size/order and same exclusion polygons; same start/terminal conditions and fixed feasible baseline definition.
2. Same constant-speed, altitude, `dt_s`, no-fly rule, footprint/coverage accounting, sensor model versions, environmental settings and scene seed.
3. Identical **maximum** time/distance/decision budget, with no unfair extra movement for either method. If the fixed-grid route must be budget-truncated, truncate it under the same precise motion rule.
4. Same synthetic noise distribution and pairing schedule. A common scenario seed alone does NOT guarantee identical realized sample noise when trajectories have different pose counts/times: either use a documented location/time-keyed common-random-number design or report that channel noise streams differ by path; use paired scenarios/repetitions and confidence intervals instead of asserting identical sensor realizations.
5. Same validation-frozen detector thresholds for any downstream fusion comparison. PPO cannot use test truth or a detector model selectively retrained on the test worlds.
6. Same split IDs, result/evidence schema, code SHA/checkpoint identity, and identical rejection criteria for non-comparable cases.

**Evaluation per held-out scenario and policy seed:** coverage fraction `C`, legal cells visited/`N_legal`, simulated flight time [s], distance [m], normalized budget use, number of invalid actions, illegal polygon crossings (expected 0), repeated-cell visits, terminal reason, route feasibility and number of episodes. Compute **paired** `DeltaCoverage = C_PPO - C_GRID`, `DeltaDistance = D_PPO - D_GRID`, and `DeltaTime = T_PPO - T_GRID` with sign conventions stated. Do not claim "PPO better" from one lucky episode; report per-case table, sample size, mean/median and dispersion (e.g. bootstrap intervals over **scenario groups**, not individual frames), negative results and missed coverage. Include simple **random legal-cell** policy as a sanity reference if resources permit, identified as an optional additional baseline.

**Primary decision criterion:** specify ahead of held-out TEST how to compare coverage under identical budget and what overhead matters; do not invent a minimum real-world detection percentage. Proposed logical acceptance: no constraint violations, a completed trained policy that actually runs, and complete honest paired results; **superiority is not required to mark a valid research task DONE**, but unsupported superiority claims are prohibited. If coverage is worse or budget consumed sooner, say so and keep the fixed grid as release baseline.

**Detection caveat:** if measured synthetic F1/FPR changes with route, report coverage/observability differences, evaluable-cell denominators and per-condition sensor validity. Do not compare detector cell-level TN over different assessed populations without a coverage-adjusted view; any event-to-object localization statistics remain separate from cell TP/FP/TN/FN (MG-008).

## 8. Evidence, tests and failure handling (specified now, NOT executed)

MG-013 implementation must include executable `matlab.unittest` tests (e.g. `matlab/tests/testMG013PPO.m`) with actual R2026b run logs and these **P-01…P-20 acceptance cases**:

| ID | Controlled input / condition | Expected evidence or invariant |
|---|---|---|
| P-01 | Construct fixed S0 grid / baseline config | Same legal-cell centres, indices, pitch and exclusion geometry as MG-005 |
| P-02 | Observation vector/shape | Consistent `2*N+5` layout, type, finite normalization and documented policy layout ID |
| P-03 | Attempt injected `TargetTruth`/target count/depth/label into observation/policy | Reject recursively; no hidden data reachable by policy or reward, including nested struct/cell/table |
| P-04 | Action reaches known legal adjacent/unvisited cell | Position follows legal leg; actual visited count increases; no teleport |
| P-05 | Boundary crossing, exclusion polygon edge/touch or narrow obstacle | Illegal action rejected, position unchanged, reason recorded, polygon violations never silently accepted |
| P-06 | Reachable already-visited cell | Permissible transit, no duplicate coverage credit; revisit/distance/time penalties applied |
| P-07 | Out-of-set, NaN, noninteger or unreachable action | Explicit bounded penalty, resource/step accounting and actionable status; no infinite retry |
| P-08 | Known route length/speed/dt and turn | Pose times globally monotonic, IDs globally unique, travelled distance and duration accurate |
| P-09 | Max time/distance budget just below next leg cost | Never exceed cap or secretly give one policy an extra step; precise terminal reason |
| P-10 | All legal cells visited / no reachable cells / max steps | Correct distinct terminal conditions; coverage from observed poses |
| P-11 | Reward hand calculation for new cell vs repeat/invalid | Exact decomposition within documented numerical tolerance; weights finite; no truth signal |
| P-12 | Repeat reset/step with same seeds, input geometry and actions | Deterministic observations/rewards/poses, global RNG preserved or scoped and restored |
| P-13 | MATLAB `rlFunctionEnv` and `validateEnvironment` | Actual R2026b environment instantiates; action/observation spec matches executable step/reset |
| P-14 | Construct PPO, train genuine small episodes | Recorded episode count, training curve/statistics, learning algorithm, checkpoint and SHA; agent is genuinely trained |
| P-15 | Scenario-group split leakage probe | Overlapping scenario/seed/layout families rejected; test data not used for scaling or checkpoint selection |
| P-16 | Paired grid/PPO held-out budget with feasible route | Same start, restrictions, budgets and metric definitions, numeric paired delta outputs |
| P-17 | Exclusion polygon makes MG-005 grid infeasible | Honest baseline failure; no unfair PPO-only win claim or silent reroute |
| P-18 | Stochastic policy evaluation and different route noise-length | Deterministic eval setting logged or repeated seeded policy rollouts; no fabricated identical noise masks |
| P-19 | Optional sensor/uncertainty features unavailable or NaN | Explicit missing-feature/feature gate; no target-label leakage, no imputed false negative |
| P-20 | Model/results evidence and rollback | Checkpoint reload, SHA, MATLAB/toolboxes, seeds, hyperparameters, per-case metrics, incomplete/failure cases and NOT TRAINED label where necessary |

**Additional regression:** re-run MG-004, MG-005 (19/19 reported baseline combined), MG-007 and any relevant MG-009 tests using actual MATLAB. Execute `checkcode`; record any issue. No "P-01…P-20 PASS" until Rahil runs the exact suite. For a partial build, report failures accurately.

**Evidence record** for MG-013 must include: actual `runtests` commands/results, environment and MATLAB release, numerical fixture, run SHA, train/val/test manifest, policy selection code and checkpoint, reward weights, action IDs and masks, step/reset logs, trial/episode counts, wall-clock training time, fair grid comparison, paired summary, mean/std/intervals and negative scenarios. Save references under `tasks/evidence/MG-013.md`; avoid committing large binary model files if repository policy excludes them—record stable secure artifact location/checksum without inventing one. MG-019 is separately required for optional full-system integration.

## 9. Scientific risk and task boundary review

The preliminary PPO test should be tractable and safe for an academic deadline: choose a small fixed grid and coverage-only reward first. A PPO agent can trivially learn to exploit sparse rewards, invalid-action penalties or simulator artifacts; test adversarial invalid actions and compare with trivial random legal policy as a sanity check. A policy selecting a cell is **not a physical flight controller**. If `makeGridRoute` refuses an excluded scenario, exclude it from the like-for-like feasible subset and report it separately. Rerunning until PPO wins or fitting to held-out test invalidates conclusions.

Task completion criteria for **MG-012 DOC only**: this scope, observation/action mapping, reward formula, MATLAB handoff, fair split/budget design and P-01…P-20 tests are reviewed and merged on protected main with evidence. No MATLAB training, checkpoint, numerical performance score or "improved detection" is claimed in MG-012. No change to original four Phase-1 objectives is authorized here.
