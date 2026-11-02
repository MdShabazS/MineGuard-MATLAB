# V2-008 dependency-gated implementation plan

**Status: PLAN ONLY. V2-008 has not started and may not start yet.** It depends on V2-006 and V2-007 both being DONE on `main` (`v2/tasks/manifest.json`). On 2026-11-02 both are TODO on `main`. This document changes no task state and authorizes nothing.

Owner: Rahil. Task: "Verify export, replay, fault cases and macOS simulation performance". Requirements stay in `V2_DEMO_ACCEPTANCE_MATRIX.md`, `V2_SYSTEM_REQUIREMENTS.md`, `V2_004_VERIFICATION_MATRIX.md` and `V2_004_EVALUATION_PROTOCOL.md`. `V2_INTEGRATION_ACCEPTANCE_PREFLIGHT.md` holds the evidence ledger format. If this plan conflicts with them, they win.

SIMULATION ONLY. V2-006 VALIDATION is negative (G07: 0 of 4 targets found). V2-008 must report results honestly and has no target result to reach.

## 1. Start gate (all required, checked with `node scripts/v2-gate.mjs ready`)

- [ ] V2-006 DONE on `main` through its governed status PR.
- [ ] V2-007 DONE on `main`, with a complete integrated dashboard and independent Mac acceptance. A partial bridge demonstration does not count.
- [ ] V2-008 start PR (TODO → IN_PROGRESS) merged by Shabaz.
- [ ] Decisions in §6 recorded.

## 2. Work packages

| # | Package | Criteria | Evidence | Test to write |
|---|---|---|---|---|
| A | Run package export | AC-019, SC-30, UI-12 | Manifest, telemetry, sample references, events, frame and provenance, with hashes | Export then read back gives identical data and hashes; failure never reports success; no overwrite of an existing run; private truth absent |
| B | Replay | AC-018, UI-11 | Replay from the exported package | Replay matches the original run by digest; no re-simulation and no new seed; a tampered package is refused visibly |
| C | Fault and negative cases | AC-021, UI-10, EVAL-06, EVAL-07 | Target-free, sensor dropout, invalid camera and LiDAR rays, mission fault | Each is shown as itself, with seeds; absence is never rendered as zero or as clear ground |
| D | Controls | AC-018 | Start, pause, resume, abort, replay, reset, export enabling | No duplicate callbacks, time drift, reseeding or freezing |
| E | Clock and geometry | AC-007, AC-013 | Sample and pose timing, map and 3-D agreement within 0.5 m | Tests on the integrated app; noise-free reference geometry stated |
| F | Truth firewall | AC-017, INT-03 | Detector, navigation, app and exports | Negative tests with injected fields. Issue #69 (nested `quality` keys) must be resolved or explicitly deferred first |
| G | Mac compatibility | AC-024 | Clean checkout, actual commands and logs | Every MUST item on the Mac, run by Shabaz or on the Mac host |
| H | Performance | AC-025, INT-10, INT-11, issue #76 | 3 full runs per condition, with sim/wall, p50, p95 and worst gap, event age, tick integrity | Mac is the primary gate (at least 0.8×, preferred 1×); Windows reported separately. Record skipped scene frames, which `mgv2PerfRun` does not record yet. Report calibration and window state, because Windows throttling changed results 3–8× (`v2/evidence/V2-76-performance/`) |
| I | One-time held-out TEST | EVAL-09, SC-25 | G09 and G10, once | **Separate gate, §3** |

Order: A, then B, because replay needs export. C through F can run alongside. G and H follow a stable integration SHA. I comes last.

## 3. Held-out TEST gate (never before explicit authorization)

Nothing in this plan unseals TEST. `mgv2.eval.runScenario` refuses G09 and G10 today, and removing that needs its own reviewed change. Before one execution, require everything in preflight §4: both tasks DONE, immutable integration SHA, frozen fingerprint `fnv1a64:d6d364f988f04bb4` and split manifest, run lock, named operator, overwrite protection, independent evaluator instructions.

If issue #76's detector proposal is accepted, its exact-equivalence evidence must exist first, and any detector change must be declared.

Report once, all modes, with raw TP, FP, FN and defined denominators, even if the result is poor. There is no retest.

**Decision for Shabaz (§6):** the detector has already failed VAL. Running TEST with it is still a valid honest measurement, but its purpose should be stated before it runs.

## 4. Evidence and honesty rules

- Every result records the executed SHA, separately from later evidence commits.
- Mac results are recorded as Shabaz's unless run by Rahil.
- `Result: PASS` covers software tests only and never detection.
- Failed criteria stay FAIL unless the owner records a scope decision.
- No fabricated timings, no frame rates that were not measured, no skipped physics or sensor ticks.

## 5. Risks known today

| Risk | Source |
|---|---|
| Rebuild pauses of about 0.5–0.9 s on Windows, and Mac unmeasured | Issue #76 |
| Evidence crops are 92% of detector memory, which affects export size | Issue #76 evidence |
| Evidence retention is capped per track, so export may hold only retained crops | V2-006 |
| Windows throttling can distort any benchmark or demo | Issue #76 evidence |
| Nested `quality` keys not allowlisted | Issue #69 |
| Export format and `NOT_PERSISTED` sample data not yet designed | V2-005, §6 |

## 6. Decisions needed from Shabaz before starting

1. Does export hold full frames, or references and retained crops only?
2. Is the pacing gate 0.8× or 1×, on which exact Mac configuration, and at which rebuild interval?
3. Is the held-out TEST still wanted with this detector, and what is its stated purpose?
4. Issue #69: fix before V2-008, or defer with a recorded reason?
