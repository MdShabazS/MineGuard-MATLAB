# Requirements and Traceability

**Authority:** [PHASE1_BASELINE.md](PHASE1_BASELINE.md). Requirement IDs stable; acceptance tests must map to them.

| Req | Description | Testable acceptance (simulation) | Original objective |
|---|---|---|---|
| FR-01 | Configure a bounded synthetic survey scenario and seeded target placement | Same configuration and seed reproduces coordinates and labels | 1,2 |
| FR-02 | Execute predefined zig-zag survey without manual piloting | Logs waypoint coverage/position; run completes or reports a cause | 1 |
| FR-03 | Simulate thermal and coil readings with units and environment parameters | Compare fixed known states; parameter sweeps change responses as documented | 2 |
| FR-04 | Fuse two sensor modalities and classify suspected anomalies | Outputs score, threshold, confusion matrix and reproducible evaluation | 2 |
| FR-05 | Geo-associate readings with GPS-like virtual coordinates | Export has valid time/coordinate reference, uncertainty and target association | 3 |
| FR-06 | Operate interactive mission dashboard | Shows simulation status, path, readings, map and reports at defined update cadence | 3 |
| FR-07 | Compare fixed grid and PPO survey strategy | Same scenarios/seeds/resources; coverage/time and variability shown | 1 |
| FR-08 | Generate exportable experiment evidence | Configuration, seeds, versions, logs and visual artifacts retrievable | 2,3 |
| FR-09 | Demonstrate no human inside simulated field | Remote virtual mission demonstration; not real-world safety proof | 4 |

## Nonfunctional
- NFR-01 Determinism: same seed/configuration must yield reproducible stochastic test sets (subject to documented tolerance).
- NFR-02 Evidence: every build requires actual test run logs; NO fabricated execution.
- NFR-03 Portability: cross-platform baseline where toolboxes permit; feature-gate unavailable functions.
- NFR-04 Performance: profile actual runtime; do not promise specific FPS/latency without measurement.
- NFR-05 Safety: never display "mine cleared" or recommend traversing a real area.
- NFR-06 Maintainability: modular functions with typed/validated table/schema outputs; explicit failure modes.
- NFR-07 Deadline: Nov 2, 2026 full demo target; if a feature cannot be verified, mark incomplete rather than fake a pass.
