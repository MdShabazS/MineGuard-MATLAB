# Agent Architecture and Training

## Distinguish two kinds of agents
**Development agent**: Rahil's Claude Code connected to MATLAB through official MATLAB Agentic Toolkit. It researches, writes code, calls real test tools and commits evidence. This is not a trained drone policy.
**Simulation agent**: PPO reinforcement learning policy that chooses permitted high-level survey waypoints/cells. Fixed grid navigation is mandatory reference; low-level flight dynamics and safety constraints remain deterministic initially.

## PPO task definition (after baseline)
- Observation: current surveyed-cell mask, battery/time budget, current pose, terrain/obstacle constraints and recent sensor-uncertainty summaries, all derived from available *observations*, never hidden ground truth.
- Action: choose an allowable adjacent/nearby unvisited grid cell or bounded heading/waypoint action; reject invalid actions in environment.
- Reward: positive new area coverage, penalties for wasted motion, repeated coverage, collision/exclusion violations and budget exhaustion. **No positive reward tied to secret target locations.**
- Training: train/validation/test scenario seeds disjoint; store hyperparameters, training curves, checkpoints/seed and computational budget.
- Comparison: fixed route vs trained PPO using same scenario seeds, start, flight budget and environmental conditions. Report variance across runs. If agent is untrained or fails performance criteria, label as **experimental** and demo the fixed route.

## Release-dependent API
MathWorks has `rlPPOAgent` and UAV Toolbox simulation APIs, but installed release/toolbox status is pending. Choose APIs only after Rahil records `ver`.

## References
- https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlppoagent.html
- https://www.mathworks.com/help/reinforcement-learning/ug/proximal-policy-optimization-agents.html
- https://www.mathworks.com/products/matlab-agentic-toolkit.html
