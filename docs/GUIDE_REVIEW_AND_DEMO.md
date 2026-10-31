# Guide-Facing Project Review, Portal and Viva Preparation
**Audience:** College guide/examiners. This document defines what can be shown honestly; it is not a fake status report.

## Questions a guide will naturally ask
| Guide's question | Answer evidence location |
|---|---|
| Have problem statement/objectives changed? | [PHASE1_BASELINE.md](PHASE1_BASELINE.md) (verbatim) |
| Why did hardware change to simulation? | [PROJECT_MASTER_BRIEF.md](PROJECT_MASTER_BRIEF.md), cost/feasibility decision |
| What exactly is simulated? | [ARCHITECTURE.md](ARCHITECTURE.md), [ALGORITHM_AND_METHODOLOGY.md](ALGORITHM_AND_METHODOLOGY.md) |
| What does a metal detector at 5 m actually detect? | [PHYSICS_AND_FEASIBILITY.md](PHYSICS_AND_FEASIBILITY.md); likely limited/no useful response |
| How much work is really done? | [Guide portal](../portal/README.md), `tasks/status.json` |
| Why is a task blocked? | `tasks/manifest.json` dependencies and `tasks/evidence/` |
| Did the model really train? | PPO training logs, checkpoint, held-out test; else NOT RUN |
| Does the dashboard show real geotags? | Virtual coordinate contract and uncertainty, not physical GPS |
| Can results be reproduced? | MATLAB release/toolboxes, seed, SHA, test commands and source files |
| Is this ready for real mine detection? | No; simulation-only and no safety certification |

## Visual demonstration sequence (actual executed results only)
1. Original project title, motivation and unchanged four objectives (read out directly).
2. Explain cost >₹1 lakh hardware concept → MATLAB simulation decision with same scientific question.
3. Show model block diagram: scenario → virtual UAV → sensor signals → fusion → suspected anomaly/map.
4. Run a small deterministic fixed grid survey; show waypoint trajectory and timestamp.
5. Show thermal + EM graphs, positive case, negative clutter and a weak/failed high-standoff case.
6. Show held-out synthetic confusion matrix and how score thresholds affect false alarms.
7. Show PPO *only if training was actually executed*, including baseline comparison and a case where it fails or underperforms.
8. Show App Designer mission control and export only if the actual UI runs.
9. Show GitHub guide portal, per-owner status, blockers, code reviews, test proof, journal.
10. Explain limitations, infeasible physical configurations and future practical validation before operational use.

## Suggested answers to challenging questions
**Q: Are you detecting buried mines from a drone?**  
A: We kept the original objective, but the implementation is a simulation of relevant sensor responses. We test physically meaningful standoff limits and cannot claim real-world subsurface detection without field validation.

**Q: Why not use only thermal?**  
A: Thermal contrast is indirect and depends on soil/time/weather. The metal channel is physically constrained and complements thermal only within sensitivity range; our experiment checks whether fusion actually helps.

**Q: Isn't a neural network just learning fake labels?**  
A: Yes, synthetic models create a domain gap. We separate training and held-out seeds, report only synthetic outcomes and seek real data for future verification. We do not equate classifier score with mine probability in the field.

**Q: Is the PPO policy better than conventional grid search?**  
A: We will compare under identical conditions. If not trained or if worse, we report that. Reward maximization does not automatically improve mine detection.

**Q: Does the guide portal prove the project is done?**  
A: It shows GitHub status and evidence links. Repository tests and actual MATLAB test logs are clearly distinct; missing logs mean no claim of execution.

**Q: What does 'real-time' mean in MATLAB?**  
A: Simulation-time playback/updates of virtual sensor/telemetry events, at a measured UI update rate; not proof of RF real-time communication from a drone.

## Guide portal feature checklist
- Live merged-main status and blockers, current owners, progress and evidence links.
- Plain-language work journal: 'What happened?', 'What next?', 'Why blocked?'.
- PR/CI history and timestamp for most recent successful fetch.
- Warning when task data missing, rate limited or stale.
- Deployment via Render free Static Site, **not yet verified**.
- No private student contact details or machine credentials.

## Report narrative
The scope change is a practical **implementation** adjustment, not a silent rewrite of objectives. The strongest technical evaluation will include meaningful **failure/negative cases**, not just a high-score positive animation.

## Last-mile sign-off
Guide should be given actual URL only when live and tested. Include date of demo, Git SHA, evidence index, accepted limitations and task statuses. Never invent a review/approval from the guide.
