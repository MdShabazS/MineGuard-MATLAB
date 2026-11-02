# MineGuard Advanced V2 — Integration acceptance preflight and evidence ledger

**Status:** PREPARATORY REVIEW PACKET — **not** execution evidence, a completion claim, or a substitute for V2-008/V2-009.  
**Prepared for:** Shabaz (project lead), Rahil (V2-007/V2-008 implementation owner), Mac and Windows MATLAB testers.  
**Snapshot:** 2026-11-02 IST. Re-check every PR head, MATLAB log and issue before executing this plan.  
**Scope:** Synthetic MATLAB simulation only; offline virtual mission and observable-only SUSPECTED anomalies. **No physical mine detection or land-clearance validation.**

## 1. Why this packet exists independently of ongoing development

The V2 task DAG has **no unstarted, dependency-free official task**: V2-006/007 are under implementation, V2-008 depends on both, V2-009 on V2-008, and V2-010 on V2-009. Designing the cross-platform acceptance process and recording the independent review baseline can proceed without touching either implementation branch. This document **does not change any task state**, run the held-out TEST, start V2-008, or sign off V2-009.

The authoritative requirements remain:
- [V2 system requirements](V2_SYSTEM_REQUIREMENTS.md) (UI-01…UI-14),
- [V2 demonstration acceptance matrix](V2_DEMO_ACCEPTANCE_MATRIX.md) (AC-series and measurable targets),
- [V2 evaluation protocol](V2_004_EVALUATION_PROTOCOL.md) (EVAL-01…EVAL-14),
- [V2 sensor contracts](V2_004_SENSOR_CONTRACTS.md) (observable-only public data and truth isolation), and
- [V2 task manifest](../tasks/manifest.json) and [status](../tasks/status.json) (sole task authority).

This is an **execution-oriented supplement**: it converts known integration seams and review findings into reproducible test cases and evidence requirements. It does not replace or silently revise any frozen acceptance criterion.

## 2. Dated evidence baseline — do not roll these into one success count

| Item | Evidence at this snapshot | What it does **not** prove |
|---|---|---|
| Official V2 on `main` | V2-001…005 DONE; V2-006…010 TODO (5/10) | Unmerged implementations are not DONE |
| [PR #66](https://github.com/MdShabazS/MineGuard-MATLAB/pull/66), V2-006, `684665c` | Windows 99/99 and independent Mac 99/99 software regressions reported PASS; Mac numerical demo/provenance checks passed | Mac demo **legibility failed** under dark theme; full UI untested |
| [PR #67](https://github.com/MdShabazS/MineGuard-MATLAB/pull/67), UI Stage 1–2, `57363dc` (tested source `fb22740`) | Mac 107/107 V2-002/003/005/007 regression PASS; Stage-2 scene refreshes 9.02–9.66/s at paced 1× | Not screen FPS, not a consistent 10/s pass, **no detector integrated**, Windows UI not tested |
| [Issue #68](https://github.com/MdShabazS/MineGuard-MATLAB/issues/68) | Rahil assigned isolated Windows detector↔UI bridge, baseline Stage-2 UI `57363dc` | Prototype work is not a merged or accepted full application |
| [Issue #69](https://github.com/MdShabazS/MineGuard-MATLAB/issues/69) | Nested `quality` metadata allowlist hardening proposed | No observed leak in checked detector outputs; no fix accepted yet |

**Scientific evidence, separate from software quality:** the *frozen V2-006 VALIDATION* (G07) found **0/4 targets** with fused/RGB-only/thermal-only modes; fused G07 had 45 false alarms, target-free G08 had 32 fused false alarms. The deliberately strong **DEMO FIXTURE** had 1 matched feature out of 78 reported events (77 false alarms). None of these may be described as successful field detection. The V1 sealed weighted-fusion TEST remains TP 0, FP 26, TN 470, FN 4, a separate historical synthetic baseline.

## 3. Integration handoff: specific checks that should fail if the bridge is wrong

Use **PASS / FAIL / NOT RUN / NOT APPLICABLE** per case; never fill future results optimistically.

| Case | Observable pass criterion | Evidence to retain | Baseline reference |
|---|---|---|---|
| INT-01 — one world/mission | Adapter and `MissionSession` use the **same public** `World`, `MissionConfig`, `run_id`, simulation time base; no duplicated private scenario/fixture | Constructor wiring check and first/last accepted sample IDs | UI-01, EVAL-02 |
| INT-02 — pose propagation | The V2-006 `MissionMap.addPose` sees executed poses **once**; actual route and TRAVERSED cells update, not just UI-drawn route | Pose tick/route counts, map snapshot and screenshot | UI-04, AC-007/008 |
| INT-03 — public-only ingestion | V2-005 samples undergo validation, wrong-run/stale samples rejected; detector, map, UI, exports receive no hidden truth | Negative injection tests; no `mgv2.eval` dependency from operational path | AC-017, EVAL-02/05 |
| INT-04 — event conversion | `det.events()` maps explicitly to UI's `t_s`, `confidence_kind`, `modality_flags` and all required fields; every displayed status is `SUSPECTED` | Validator output, selected event ID, full score-kind wording | UI-09, AC-016 |
| INT-05 — offline coverage | Coverage raster coordinates and alpha align with local ENU; `UNOBSERVED` is transparent; validity means **sensor evidence acquired**, never cleared land | Cell-state counts, layered screenshots, offline launch | UI-04/05, AC-008/009 |
| INT-06 — provenance click-through | Clicking an event uses its exact retained RGB/thermal evidence refs, run/tick/pose/time/checksum; missing or altered evidence produces a visible error, never substitute imagery | Click recording, reference comparison and tamper test | UI-09, AC-016 |
| INT-07 — reset/pause | Pausing advances no simulation time or frames; reset clears old source/map/events, avoids duplicate callbacks and reproduces initial seed | Two-run deterministic checksums, event counts, callback count | UI-11, AC-018 |
| INT-08 — absence/missing data | Thermal dropout, invalid LiDAR/camera returns, no-hit rays and sensor errors are distinguished from zero and healthy samples | Scenario IDs, invalid reasons and UI screenshots | UI-08/10, EVAL-07 |
| INT-09 — display readability | Mac **dark and light MATLAB desktop themes** both keep SIMULATION/SUSPECTED, Kelvin legends and inspector labels visibly legible; exported PNG text also readable | Side-by-side screenshots and foreground/background contrast evidence | UI-07/09/13, PR #66 blocker |
| INT-10 — UI & detector performance | Instrument `SensorSystem`, `det.ingest`, event/cache update, map snapshot, panel presentation, `drawnow`, startup and resize **separately**; no skipped *simulation ticks* | Three full missions on specified host, per-run raw timings, dropped scene frame count, p50/p95/max and worst gap | AC-003, UI-01…03 |
| INT-11 — bounded view cost | `MissionSession.view()` does not reconstruct every event/track/raster on each display tick; cached data has explicit age/revision and selection handles changed IDs | 400-tick and full-mission timing, stale/revision tests, memory growth | #68; 110.5 ms Mac `det.events()` reference |
| INT-12 — complete operation | A single app runs START → survey → return → landing → COMPLETE with all live panels synchronized; failure/abort accurately indicated, no visual-only replay substituted for simulation | Unedited full-run log and capture, actual run ID and seed, Mac/Windows versions | UI-01…14, AC-001…022 |

**Timing interpretation:** Stage-2 `scene refreshes/s` is not measured monitor FPS. Baseline was 9.02–9.66/s at paced 1× **without the detector**, with 49–139 intentionally skipped scene-only frames and a worst observed transient lag of 1.133 s. Any claimed improvement must report the *combined* application, unchanged conditions and per-run variability. Do not inflate counts by counting engine ticks, UI panel calls or repeated still images as rendered frames.

## 4. Evidence needed for the eventual V2-008 verification (not authorized to execute yet)

The governing evaluation protocol says to preserve frozen settings and execute held-out studies **only at the appropriate authorized gate**. A checklist is not permission to unseal or rerun TEST. Before a one-time run, require:

1. Both V2-006 and V2-007 officially DONE through task-gated merges, not just passing CI.
2. An approved, immutable integration SHA and the exact frozen detector fingerprint, split manifest/hash and no post-VAL tuning. Any scientific design flaw discovered is disclosed rather than patched covertly.
3. An agreed run-lock and responsible operator, destination paths, checksum/overwrite safeguards, full parameter and seed manifest, and independent evaluator instructions. No already-consumed V1 TEST reuse.
4. Frozen counts and denominator definitions (event-level TP/FP/FN; undefined TN and recall in zero-target groups when appropriate). Do not substitute coverage percentages or the demo fixture for detection metrics.
5. After authorization, record **one actual execution** with explicit negative and failure cases, preserve the outputs and report all modes honestly. No repeated TEST attempts for a better score.

Export/replay for V2-008 must additionally demonstrate byte/hash or documented numeric equivalence, no leaked private truth, missing-evidence errors, clear run/version metadata and no overwrite of an existing run. These are future tests, not results here.

## 5. Cross-platform operator evidence ledger (copy one row for every case)

| Field | Mandatory record |
|---|---|
| Case ID and result | e.g. `INT-06 / NOT RUN` until actually tested; include justification for N/A |
| Source integrity | Git SHA of **executed** code, `main` base SHA and relevant PR SHA; note evidence-only later commits |
| Host | macOS or Windows version, CPU architecture, MATLAB exact update, toolbox list, theme and desktop/headless state |
| Scenario | Scenario/seed, `run_id`, frozen configuration hash, sensor rates, mission duration |
| Invocation | Full exact MATLAB command, argument values, output exit/errors and count of tests/pass/fail/incomplete |
| Physical metrics | Simulated seconds, wall seconds, refresh **definition**, CPU/resource assumptions if measured, p50/p95/max gap; no estimated FPS |
| Evidence | Relative repository path, log/screenshot/capture filename, checksum, timestamp, provenance and test operator |
| Limitations | Any known defect, scientific failure, not-run feature, cross-platform divergence and next action |

Suggested immutable relative evidence tree **after** implementation is approved: `v2/evidence/V2-008/integration/<host>/<case-id>/`. This is a convention proposal only; do not overwrite existing V2-006 screenshots/CSV or export private truth.

## 6. Explicit stop/go rules for the guide-facing demo

**STOP / do not mark integration complete** if: the source/mission/time bases diverge; a hidden-truth field reaches operational inference; suspected output is called confirmed/cleared; event clicks show mismatched frames; the offline map implies released land; sensor dropout is replaced with invented zeros; Mac demo text is unreadable; the app cannot finish a real simulated mission; or test evidence lacks an actual execution SHA. Display-only success cannot overrule these.

**Record as measured limitations, not false passes:** below-target refresh frequency, startup/reset delay, nonuniform cadence, uncalibrated uncertainty, false positives and zero recall in frozen VAL, unmodelled battery, synthetic-only terrain and known noise-free reference geometry. A target miss is not erased by a benchmark PASS. If a MUST-level criterion cannot be met, the owner must obtain an explicit documented scope decision instead of silently reclassifying it as optional.

**Final signoff is gated:** V2-008 verification → V2-009 evidence/scientific audit → V2-010 handover and actual guide demonstration; Shabaz alone merges/accepts the task transitions. This packet can be reviewed or merged independently as **documentation preparation only**, without changing the DAG.
