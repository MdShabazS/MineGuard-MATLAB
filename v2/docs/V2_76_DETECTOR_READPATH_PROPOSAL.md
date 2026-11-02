# Proposal: read-path optimization of `AnomalyDetector` (issue #76)

**Status: PROPOSAL for Shabaz's science review. Not accepted and not for merge yet.** PR #66 and the published bridge are untouched by it. Measurements are in `v2/evidence/V2-76-performance/README.md`.

SIMULATION ONLY. VALIDATION remains negative. This changes speed only. It is not a detector improvement and must not be described as one.

## Decision requested

Should these changes enter V2-006's detector, after PR #66 merges, as their own reviewed PR? Rejecting them is reasonable: on Windows the bridge fix alone already passes 0.8× at 100 ticks (0.943 paced). What the proposal adds is shorter pauses and an affordable 20-tick interval.

## What changes (one file, `+mgv2/+detect/AnomalyDetector.m`, 35 lines added, 10 removed)

| # | Change | Why outputs should not change |
|---|---|---|
| 1 | `events()` computes LiDAR context only for tracks selected as events | `selectEvents` never reads LiDAR columns. `trackTable()` with no arguments still returns every column |
| 2 | `lidarContext` scans only the grid window around each point | Same cells in the same column-major order, with the same formulas |
| 3 | Footprint loop prefilters tracks by bounding box before `inpolygon` | A point outside the box cannot be inside the polygon |
| 4 | Observations grouped once by a stable sort, not `find` per track | The same ascending indices per track |

**Not changed:** configuration, thresholds, fingerprint, ingest, association, merging, selection, scoring, evidence retention, schema.

**Rejected on purpose:**
- Incremental look counts: track positions move, so old footprints would need re-testing, or results would change.
- Dropping evidence for non-event tracks: a track can become an event later.
- Avoiding the repeat checksum in ingest: useful, but it needs its own review.

## Evidence

| Check | Result |
|---|---|
| Equivalence harness `mgv2DetectorEquivalence` on `053c6ac` against golden from unmodified detector `ed1ed8b` | **Equal: 5 fixtures, 25 checkpoints, 0 differences** |
| Fixtures | TRAIN G01, G03, G05, G06 and the DEMO FIXTURE, including N1 clutter, N2 low contrast and N3 dropout. Golden counts agree with committed TRAIN results, for example G01 573 tracks and 65 fused events |
| What is compared, at full `%.17g` precision | Every track column and its order; every event field in all three score modes; every evidence record and crop; ingest outcomes and candidate counts; sample checksums; a stale and an invalid sample injected |
| Negative control | A 1e-12 relative change to LiDAR height in a scratch copy: counts unchanged, and **0 of 5 checkpoints matched**, so the harness detects it |
| Fingerprint | `fnv1a64:d6d364f988f04bb4`, unchanged |
| Full regression at `053c6ac` | 154/154, Windows |
| Default-scene runs | Same sample, pose and event digests as the unmodified detector in every run |

**Limits of this evidence.**
- Run once, on Windows only. The Mac must repeat it (see below).
- It covers these fixtures and configurations only. VAL and TEST were not run and must not be run for this, so no such claim is made for them. `mgv2DetectorEquivalence` refuses any non-TRAIN or non-demo group.
- Changing sensor configurations beyond these environments and the thermal dropout were not exercised.
- `mergeNear`, `pruneEvidence` and `updateTrack` are unchanged, and merges occur in these runs, but merges were not counted separately.

## Measured gain (Windows, high QoS, not Mac)

| | Bridge fix alone | With proposal |
|---|---:|---:|
| Single rebuild, median / max at 20 ticks | 229 / 432 ms | 110 / 251 ms |
| App, unpaced, 20 ticks | 0.76× | 0.81–0.82× |
| App, paced, 20 ticks (one run) | 0.792× | 0.851× |
| App, paced, 100 ticks (one run) | 0.943× | 0.968× |
| Worst app pause, unpaced, 20 ticks | 650 ms | 489 ms |

## Required before acceptance

1. Shabaz's science review of this document and the one-file diff.
2. PR #66 merged, then this rebased onto the accepted detector and the harness rerun there.
3. Mac: rerun the golden from the unmodified detector, then the proposal, on the same host. Compare Mac to Mac; floating-point results were not shown to match across platforms.
4. Mac benchmarks with `mgv2PerfRun`, against the primary gate.
5. Its own PR and review. V2-006 task status is unaffected until the governed workflow says so.
