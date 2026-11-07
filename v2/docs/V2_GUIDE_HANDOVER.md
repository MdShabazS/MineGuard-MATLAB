# MineGuard Advanced V2 — Guide handover package

**Revision:** 1.0 · 2026-11-03 · V2-010 · Prepared by Claude Code for Rahil (owner of V2-010)
**Guide approval: PENDING.** Nothing in this package records an approval, review or sign-off by the guide or by Shabaz.

SIMULATION ONLY. Every marker is a SUSPECTED anomaly with an uncalibrated score. The live scenes contain no synthetic target. V2 VALIDATION found 0 of 4 targets; the V1 sealed TEST stays TP 0, FP 26, TN 470, FN 4. Nothing here says any ground is safe.

## 1. Read first (about 20 minutes)

| Order | Document | Why |
|---|---|---|
| 1 | `v2/docs/V2_FINAL_ENGINEERING_REPORT.md` | What V2 is, what it achieved, and what it did not |
| 2 | `v2/evidence/V2-009.md` | Audit of all 25 acceptance criteria and the risk register |
| 3 | `docs/PHASE1_BASELINE.md` | The four original objectives, unchanged |
| 4 | `v2/docs/V2_FINAL_DEMO_SCRIPT.md` | What the live demonstration shows, step by step |

Supporting records: `v2/evidence/V2-001.md` to `V2-008.md`, and `v2/docs/V2_GOVERNANCE_DELEGATION.md`, which explains why Rahil owned V2-007 to V2-010.

## 2. Run it (Windows, MATLAB R2026b with UAV and Navigation Toolboxes)

```matlab
cd <clone of github.com/MdShabazS/MineGuard-MATLAB>
addpath('v2/matlab')
app = mgv2MissionControl;          % press START SIMULATION; about 2.5 min at 1x
runtests('v2/matlab/tests')        % full V2 suite; about an hour on the development laptop
```

Keep the MATLAB window in front and close heavy programs. In the background, Windows can slow the simulation to about 0.3× (`v2/evidence/V2-008.md` §5).

**macOS: NOT RUN** for the final code. A Mac demonstration is untested.

## 3. Sample export

`v2/evidence/V2-008/sample_package/V2RUN-NOMINAL-0001_g1_20261103T151722Z/` is a real exported run: the nominal mission stopped by the operator at 10 simulated seconds, 224 samples, 1 SUSPECTED event on target-free ground. Open `manifest.json` to read it. To check it in MATLAB:

```matlab
pkg = mgv2.run.verifyPackage('v2/evidence/V2-008/sample_package/V2RUN-NOMINAL-0001_g1_20261103T151722Z');
r = mgv2.run.reproduce(pkg)       % r.match is true when the simulation reproduces it bit for bit
```

A full mission package is about 276 MB. Press EXPORT after a run to make one.

## 4. Open items

| Item | State |
|---|---|
| Guide review and approval | **PENDING**: not obtained |
| AC-022: Shabaz's personal review of a full run on a Mac | **NOT RUN** |
| AC-024: every MUST item run on a Mac, clean checkout | **NOT RUN** |
| AC-025: ≥ 10 FPS scene refresh | **FAIL** (best 6.3–6.5/s) |
| Human-witnessed Windows demonstration | Only if Rahil watches a run himself and records it in `v2/evidence/V2-010/windows_demo_witness.md` (template in that folder) |
| Detector usable for detection | **No** (VALIDATION 0 of 4); the sealed TEST was not run |
| Partial criteria AC-005, 007, 009, 011 | Recorded in `V2-009.md` |
