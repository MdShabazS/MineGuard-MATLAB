# Risk Register, Open Decisions and Mitigations
**Review date:** 2026-10-31 · **Owner:** Shabaz · **Status:** planned controls only.

| Risk ID | Risk / uncertainty | Impact | Evidence needed | Mitigation / disposition |
|---|---|---|---|---|
| R-01 | Airborne coil standoff makes buried detection implausible | Critical scientific validity | Published range physics, parameter sweeps | Explicit signal threshold and negative feasibility finding; never claim actual mine detection |
| R-02 | Thermal signature heavily varies with soil, depth, moisture, illumination | High false positives/negatives | Real literature and noise/soil stress tests | Time-dependent model; honest uncertainty; compare thermal-only |
| R-03 | Original O2 promises accuracy, but simulated classifier unvalidated externally | Critical academic honesty | Held-out synthetic tests, dataset provenance | Preserve objective verbatim; report simulation-only metrics |
| R-04 | MATLAB product/toolbox not licensed on Rahil PC | Critical schedule | `ver`, entitlement, function and licence tests | Use licensed tools only; MATLAB-core fallback where requirements allow |
| R-05 | Claude Code MCP connection incompatible with installed MATLAB release | High | Live `2+3` tool execution log, toolkit version | Install matching official toolkit; troubleshoot stepwise; no fake integration |
| R-06 | PPO training slow/unstable or shows no improvement | High deadline | Training logs/checkpoints and same-budget comparison | Begin with deterministic route baseline; reduce environment complexity; label PPO experimental |
| R-07 | Unreal-based animation doesn't run on Mac | Medium | Vendor docs and dual-machine test | Portable cuboid/mesh MATLAB display; Windows-only Unreal optional |
| R-08 | Sensor labels leak into features or RL reward | Critical validity | Code review, split tests | Separate truth from observations; held-out scenario seeds |
| R-09 | Fake accuracy from unrepresentative/small dataset | High | Sample counts, splits, confidence bands | Controlled experiments, separate synthetic and real claims |
| R-10 | GitHub unprotected main admits accidental bypass | High process integrity | Ruleset API/config and merge audit | Enable required PR, review, unique status check, block force push |
| R-11 | Render portal falsely shows stale/draft progress | Medium | Real URL, main status fetch, offline test | Read only merged main; last-checked timestamp and explicit API error |
| R-12 | Public repo exposes credentials/data | Critical privacy/IP | Secret scan, PR review and .gitignore | No licences/student IDs/API keys; verify dataset terms |
| R-13 | Two-day full feature scope unrealistic | Critical schedule | Actual task throughput and test logs | Prioritize verified baseline; don't manufacture progress |
| R-14 | Multiple task branches edit shared `status.json` causing conflicts | Medium | PR diffs, commit audits | Rebase on main, conflict resolution with non-overwriting task transitions |
| R-15 | Source papers from Phase-1 slide unverified | Medium scholarly credibility | DOI/publisher matching | Use real literature list for final report; preserve original slide as history |
| R-16 | MATLAB model scales poorly with grid size or rendering | Medium | CPU/memory profiling, dropped event counts | Profile small deterministic scene then scale, redraw throttling |
| R-17 | Synthetic geotag confused with GPS fix | High correctness | UI review/export fields | Label virtual GPS and include uncertainty |
| R-18 | Guide's status portal not deployed despite code available | Medium communication | Render live URL and browser test | Deploy after PR merged and verify live data |
| R-19 | Unexpected research/example licence | Medium legal/reuse | SPDX/licence details for each imported file | Prefer official examples by link; obtain license before copy |
| R-20 | No reviewer available for urgent PR | High schedule | Review request/history | Small PR scope, clear handoff, still no self-approval |

## Open decisions (no silent defaults)
- D-01: Rahil actual MATLAB version and licensed products [PENDING].
- D-02: Exact numerical sensor model constants and their provenance [PENDING].
- D-03: Acceptable synthetic scenario geometry, height, speed and sensor sampling rate [PENDING; design proposals allowed].
- D-04: Use thermal research dataset only if licence/access confirmed [PENDING].
- D-05: Choose model/classifier based on actual data shape and toolbox availability [PENDING].
- D-06: PPO discretized action/observation size after functional baseline [PENDING].
- D-07: Branch ruleset enabled and reviewer approval [PENDING].
- D-08: Render public URL, verified deploy and audience sharing [PENDING].
- D-09: Guide-approved answer to physical feasibility limits [PENDING; original Phase-1 wording MUST remain].
- D-10: Report submission format/presentation duration [PENDING].

## Escalation rules
A scientific blocker cannot be waived by pushing code; a licence blocker cannot be 'fixed' by a pirated toolbox; a failed CI check must be corrected; and a missing real MATLAB run cannot be treated as a pass.
