# Agent Architecture and Training — MG-012 Index

**MG-012 authoritative PPO observation/action/reward and fair-comparison contract:**
[MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md](MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md). Its **P-01…P-20** checks are specified for later MG-013 MATLAB execution, not reported as passed by MG-012 documentation.

## Distinguish two kinds of agents

- **Development agent:** Rahil's Claude Code connected to MATLAB through the official MathWorks MCP server. It researches, edits code, runs MATLAB tests and records execution evidence. This is not a trained survey policy.
- **Simulation PPO policy:** an optional **high-level next-legal-survey-cell** selector. It controls only a kinematic simulated route, not a physical drone or landmine sensor. The MG-005 fixed-grid route is mandatory as benchmark and remains the core demonstration baseline.

## PPO safe interface

The frozen entrypoint from MG-003 is `mineguard.rl.selectSurveyCell(observation,allowedCells,policy)`. MG-012 proposes an adapter representation (without changing `mg-contract/1.0`): normalized current position, historical visited-cell mask, current legal/reachable mask, remaining distance/time budgets and optional *observed* uncertainty with explicit validity flags. The policy/reward must **never** see `TargetTruth`, target labels, coordinates, depths, target count or evaluator-only metrics.

Actions select legal survey-cell centres. Invalid/excluded/unreachable moves are rejected with bounded penalties and logged status; trajectory samples and visited cells use MG-005's identical geometry and coverage rules. Reward values new legal coverage and penalizes travel, time, repeat visits and invalid actions. No target-hit reward.

## Training and fair comparison

Use genuinely trained PPO (not a manually programmed grid route or untrained agent) with documented observation/action dimensions, reward weights, seeds, hyperparameters, `rlFunctionEnv`/PPO training evidence and checkpoint integrity. Divide scenario groups disjointly into TRAIN/VALIDATION/TEST; never tune on the sealed test split. Compare with MG-005 under the same legal region, start, altitude, speed, motion model, coverage definition and budget. Report paired coverage, time and distance, uncertainty, policy failures and cases where PPO underperforms. Additional detection-score comparisons require the MG-008 evaluator/coverage-denominator safeguards.

**Availability:** Rahil's MG-002 evidence reports licensed Reinforcement Learning Toolbox and a basic PPO smoke test in MATLAB R2026b. This is **not** PPO training or a completed MG-013 implementation. If actual training/testing does not happen, display **NOT TRAINED / NOT RUN**, not a fabricated performance number.

## References

- [MG-012 authoritative design and test plan](MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md)
- [MG-003 data-interface freeze](MG003_INTERFACE_FREEZE.md)
- [MG-005 navigation evidence](../tasks/evidence/MG-005.md)
- https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlppoagent.html
- https://www.mathworks.com/help/reinforcement-learning/ref/rl.env.rlfunctionenv.html
- https://www.mathworks.com/help/reinforcement-learning/ug/proximal-policy-optimization-agents.html
