# MineGuard V2.2 — BITM satellite view

**Goal:** show the V2.1 simulated mission on a live satellite view of the BITM campus, with honest credits and an offline fallback. The route is **virtual**; this is not a real drone flight and makes no detection claim.

**Team and rules:** [docs/TEAM.md](../docs/TEAM.md). **Tracking:** [tasks/manifest.json](tasks/manifest.json) and [tasks/status.json](tasks/status.json), checked by `node scripts/v22-gate.mjs validate`. **Guide view:** the live dashboard (V22-T2).

## How a task is done

**Shortcut:** tell your Claude *"I'm <Name>, let's do V22-Tn"*. It follows [prompts/COMMON.md](prompts/COMMON.md) and `prompts/V22-Tn.md`, which carry out the steps below.

1. **Start check:** run `node scripts/v22-gate.mjs ready`. Start a task only when it is READY, meaning every dependency is DONE on `main`.
   - If a dependency is not DONE, wait. Independent READY tasks can continue.
2. **Branch:** create `task/V22-Tn-short-name` from the latest `main`.
3. **Build and test:** write `v2_2/evidence/V22-Tn.md` with these lines:
   - `Task:`, `Owner:` and `Self-review:`.
   - For BUILD and TEST tasks, also `Tester:`, `Environment:`, `Command:`, `Observed output:` and `Result: PASS`.
4. **Status:** in the same PR, set the task in `v2_2/tasks/status.json` to DONE, or to IN_PROGRESS to show a long task has started.
   - Fill in `startedBy`, `startedOn`, `completedBy`, `completedOn` and `evidence`.
5. **Merge:** the **owner self-reviews and merges** once the `task-gate` check passes. No second-person review is needed.
   - The PR says which Claude session built and merged it.

## Tasks

| Task | Owner | Depends on | Title |
|---|---|---|---|
| V22-T1 | Shabaz's Claude | — | Phase plan, task tracking, owner-merges rule and V2.2 CI gate |
| V22-T2 | Shabaz's Claude | V22-T1 | Guide live dashboard replacing the existing Render portal |
| V22-T3 | Shabaz's Claude | V22-T1 | Satellite map source, licence terms and approved BITM location and boundary |
| V22-T4 | Shabaz's Claude | V22-T3 | Clean satellite preview module rebuilt on current main |
| V22-T5 | Shabaz's Claude | V22-T4 | Virtual V2.1 mission route drawn over BITM and synced with the 3-D demo |
| V22-T9 | Shabaz's Claude | V22-T5 | Reel-style cut/fill elevation map over BITM from a simulated drone LiDAR survey |
| V22-T6 | Rahil's Claude | V22-T5, V22-T9 | Satellite tab integrated into V2.1 mission control with offline fallback |
| V22-T7 | Shabaz's Claude | V22-T6 | Mac verification of the satellite view at the final commit |
| V22-T8 | Danish's Claude | V22-T6 | Windows acceptance, guide demo script and V2.2 release record |

**Parallel work:** after T1, T2 and T3 (both Shabaz) run in parallel. T4 waits for T3, T5 for T4 and T9 for T5, and T6 for T5 and T9 (added 2026-11-19). After T6, T7 (Mac) and T8 (Windows) run in parallel.

### V22-T1 — Phase plan, task tracking, owner-merges rule and V2.2 CI gate
**Owner:** Shabaz's Claude · **Kind:** DOC · **Depends on:** nothing · **Evidence:** `v2_2/evidence/V22-T1.md`

- v2_2/tasks manifest and status with V22-T1..T8, owners and dependencies
- docs/TEAM.md and CLAUDE.md record the owner builds, self-reviews and merges rule
- scripts/v22-gate.mjs validates the plan and PR transitions and runs in CI, with tests

### V22-T2 — Guide live dashboard replacing the existing Render portal
**Owner:** Shabaz's Claude · **Kind:** BUILD · **Depends on:** V22-T1 · **Evidence:** `v2_2/evidence/V22-T2.md`

- One simple page at the existing portal URL: V2.2 tasks, owner, status, ready/blocked, dependencies
- Live work from GitHub: open PRs per task, last commit time and CI result, refreshed every minute, marked as not merged
- Earlier phases (V1, V2, V2.1) reduced to one small history link
- Portal tests updated and passing; the deployed page checked after merge

### V22-T3 — Satellite map source, licence terms and approved BITM location and boundary
**Owner:** Shabaz's Claude (moved from Danish on 2026-11-19) · **Kind:** DOC · **Depends on:** V22-T1 · **Evidence:** `v2_2/evidence/V22-T3.md`

- Decision on the satellite source (MATLAB online basemap) with exact on-screen credit text
- What may be committed to the public repository (code yes; map tiles and screenshots only if the terms allow) and what may be shown in a demo
- BITM campus centre (WGS84) and boundary from a named approved source, with the source recorded
- Builds on v2/research/ENH-008-GEOGRAPHIC-DECISION.md and issue #135

### V22-T4 — Clean satellite preview module rebuilt on current main
**Owner:** Shabaz's Claude (moved from Rahil on 2026-11-19) · **Kind:** BUILD · **Depends on:** V22-T3 · **Evidence:** `v2_2/evidence/V22-T4.md`

- Standalone module from the retired PRs #72, #75 and #100: satellite basemap centred on the T3 BITM location
- WGS84 <-> virtual ENU conversion, on-screen credits, dark and light theme
- Honest status: provider metadata and actual tile load reported separately; no network shown as unavailable
- Tests (incl. the old #100 cases) run on the owner's machine (MATLAB R2026b; Windows covered by V22-T8) with SHA and checkcode recorded; no tiles or screenshots committed unless T3 allows

### V22-T5 — Virtual V2.1 mission route drawn over BITM and synced with the 3-D demo
**Owner:** Shabaz's Claude (moved from Danish on 2026-11-19) · **Kind:** BUILD · **Depends on:** V22-T4 · **Evidence:** `v2_2/evidence/V22-T5.md`

- V2.1 boundary, planned route and live drone position drawn on the satellite view at the BITM origin
- Everything labelled VIRTUAL; no mine, target or anomaly markers over real property
- Route position stays in step with the 3-D mission clock (ENH-011)
- Tests run on the owner's machine (MATLAB R2026b; Windows covered by V22-T8)

### V22-T6 — Satellite tab integrated into V2.1 mission control with offline fallback
**Owner:** Rahil's Claude · **Kind:** BUILD · **Depends on:** V22-T5 · **Evidence:** `v2_2/evidence/V22-T6.md`

- Satellite tab in the V2.1 application, optional and separate from the offline ENU mission map
- No network: falls back to the ENH-009 offline campus schematic with a clear notice
- Offline mission, detector, sealed TEST data and V2/V2.1 behaviour unchanged; startup and frame cost measured
- Full V2 + V2.1 + V2.2 regression on Windows recorded

### V22-T7 — Mac verification of the satellite view at the final commit
**Owner:** Shabaz's Claude · **Kind:** TEST · **Depends on:** V22-T6 · **Evidence:** `v2_2/evidence/V22-T7.md`

- Short satellite tests only (no full regression) on Mac MATLAB R2026b at the final SHA
- Tile load, credits, theme and offline fallback observed on the Mac; log committed, no tiles committed unless T3 allows

### V22-T8 — Windows acceptance, guide demo script and V2.2 release record
**Owner:** Danish's Claude · **Kind:** TEST · **Depends on:** V22-T6 · **Evidence:** `v2_2/evidence/V22-T8.md`

- Full regression and a satellite acceptance run on Windows at the final SHA
- Demo script updated with the ENH-010 Ballari-to-BITM storyboard and the satellite tab
- Release record with limitations: virtual route, no detection claim, map terms

### V22-T9 — Reel-style cut/fill elevation map over BITM from a simulated drone LiDAR survey
**Owner:** Shabaz's Claude · **Kind:** BUILD · **Depends on:** V22-T5 · **Evidence:** `v2_2/evidence/V22-T9.md` · **Prompt:** [prompts/V22-T9.md](prompts/V22-T9.md)

Added 2026-11-19 after Shabaz shared a reference reel (a CutSheetRX-style cut/fill map). See the prompt for the full acceptance list.

## Limits for every task

- **No map tiles or screenshots** in the public repository unless V22-T3 records that the terms allow it.
- **No mine, target or anomaly markers** over real campus imagery. Mission geometry is labelled VIRTUAL.
- **No detection claim.** Detector, sealed TEST data, V2 and V2.1 behaviour stay unchanged.
- **Honest results.** A test that was not executed is NOT RUN. Never record a review or witness that did not happen.
