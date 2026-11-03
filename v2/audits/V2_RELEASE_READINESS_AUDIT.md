# MineGuard Advanced V2 — Release-readiness audit (clean checkout)

**Date:** 2026-11-03 (IST) · **Auditor:** Claude Code (Opus 5.5) for Rahil · **No independent human reviewed this audit.**
**Audited:** fresh clone of GitHub `main` at `2d734e9` (all ten V2 tasks DONE), then `f64508e` after the one fix below.
**Host:** Windows 11 Pro (build 26300), MATLAB R2026b Update 1 (26.2.0.3433840), desktop session. **macOS: NOT RUN.**

SIMULATION ONLY. Every event is a SUSPECTED anomaly with an uncalibrated score; V2 VALIDATION found 0 of 4 targets; V1 sealed TEST TP 0, FP 26, TN 470, FN 4.

## 1. Result

| Check | Result |
|---|---|
| Clone clean (`git status --short` empty) | PASS |
| `task-gate.mjs validate`, `v2-gate.mjs validate` | PASS; 10 V2 tasks DONE, none READY |
| Node governance and portal tests | 37/37 |
| MATLAB, 9 suites on the clone (`2d734e9`) | **305/305** (V2-002 22, V2-003 22, V2-005 28 + 35 + 34, V2-006 28, V2-007 bridge 42, UI 73, V2-008 21) |
| `checkcode` on `+ui`, `+bridge`, `+run`, `+replay` | no messages |
| V2-007 application check | 31/31 |
| V2-008 application check (export, replay, reproduce, fault, invalid rays, tampering) | 20/20 |
| Committed sample package on `2d734e9` | **FAIL**: its 8 MAT-files were missing (`*.mat` in `.gitignore`); `verifyPackage` refused it |
| Same package on `f64508e`, after #114 | **PASS**: `verifyPackage` passes; `reproduce` matches poses, 224/224 samples, end state and world |

The fix (#114) changed no code: `git diff --stat 2d734e9 f64508e` shows only the 8 MAT-files, `.gitignore` and a correction note in `V2-008.md`.

## 2. Acceptance (from `v2/evidence/V2-009.md`)

17 PASS (Windows), 4 PARTIAL, 1 FAIL (AC-025 ≥ 10 FPS), 2 NOT RUN (AC-022 Shabaz's Mac review, AC-024 Mac run), and AC-023 addressed by the V2-010 report. **V2 is not fully accepted under matrix Revision 1.0.**

## 3. Not done or not verified

- **Guide approval: PENDING.**
- **macOS: NOT RUN** at the final commits (AC-024); Shabaz's personal Mac review not done (AC-022).
- **No human-witnessed Windows demonstration.** All runs were executed by Claude Code. The demonstration is verified by automated GUI checks only.
- **≥ 10 FPS scene refresh: FAIL.** 1× pacing holds only on a quiet host with MATLAB in front.
- **Detection: not achieved** (VALIDATION 0 of 4); the sealed TEST was not run.

## 4. Open pull requests (disposition)

| PR | Disposition | Reason |
|---|---|---|
| #91, #85 | **Closed as incorporated** (2026-11-03, at Rahil's request) | Their heads are ancestors of `main` (through #101); branches kept, reopenable |
| #86 | Deferred: needs science review | Detector read-path proposal; changes no result, but touches the frozen detector |
| #93 | Deferred: research | V2-006 successor proposal; no detector change in this release |
| #72, #75, #90, #100 | Deferred: optional | Satellite map preview (ENH-002); excluded from the release by instruction |
| #95, #98, #99 | Deferred: optional | ENH-008/009/010 orientation material; not release content |
| #97 | Deferred | Portal status refresh from 2 Nov; superseded by `main`'s status |

Closed in this work: #87 (superseded plan), #91 and #85 (incorporated). Issues #68 (V2-007 bridge, delivered in #101) and #69 (nested metadata, fixed by #92/#96) are resolved in `main` but still open on GitHub; closing them is recommended. Merged: #92 and #96 (issue #69), and #101 to #114 (V2-007 to V2-010, governance, this audit's fix).

## 5. Statement

MineGuard Advanced V2 — **10/10 tasks DONE on `main`**. Clean-checkout software audit on Windows: **PASS after one fix** (sample package MAT-files, #114). **The release-readiness audit is NOT PASSED as a whole**, because AC-022 and AC-024 (Mac) are NOT RUN, AC-025 FAILS, and guide approval is pending. **The Windows demonstration is verified by automated checks only, not by a human witness.**


## 6. Acceptance closure review (2026-11-03, later the same day)

Basis: the exact text of `V2_DEMO_ACCEPTANCE_MATRIX.md` Revision 1.0, which is unchanged, and committed evidence. No benchmark was rerun and no threshold was changed.

**AC-025 (performance observation): PASS (Windows); the provisional ≥ 10 FPS target is NOT MET.**
- **Criterion:** the AC-025 pass criterion reads "Actual wall time, simulation time, 3-D refresh and RGB/thermal/LiDAR update rates recorded; target usability checked, not assumed".
- **Recorded:**
  - wall and simulation time per mission (`V2-007.md` §3, `V2-008.md` §5);
  - 3-D refresh rate (6.3–6.5/s at V2-007, at most 5.15/s at V2-008);
  - sensor update rates of RGB and thermal 5 Hz, LiDAR 2 Hz and navigation 10 Hz. The 3080 samples over ticks 0–2799 equal exactly 700 + 700 + 280 + 1400 (`V2-008/app_check.txt`).
- **Usability checked:** 1× holds only on a quiet host with MATLAB in front; 2 of 6 detector missions in plan A and 5 of 6 in plan C fell below 0.8×.
- **Why 10 FPS is not the gate:** it appears only in matrix §3 as a "Provisional target … aim ≥ 10 FPS", and §3 says these are "engineering design targets, not passed benchmarks".
- **Correction:** V2-009 scored AC-025 FAIL by treating the provisional target as the criterion; this corrects that. The unmet target stays recorded. §3 also asks for scene-refresh statistics on a Mac; that is part of AC-024 and NOT RUN.

**AC-023 (academic objective trace): PASS (document check).** The four objectives in `V2_FINAL_ENGINEERING_REPORT.md` are character-identical to `docs/PHASE1_BASELINE.md` (script check, `V2-010.md` §2). Report §4 claims only simulated contributions and names the unachieved goals. The check was done by Claude Code, not by a human reviewer.

**AC-022 and AC-024 (Mac): NOT RUN. The Windows delegation does not supersede them.**
- **AC-022** requires that "Shabaz personally reviews full simulation … on user's Mac; signoff recorded".
- **AC-024** requires all MUST tasks on the user's Mac from a clean checkout.
- **Matrix §1:** a MUST item impossible on macOS must be "formally revise[d] … with Shabaz and guide". The delegation record (§"What the delegation does not cover") excludes matrix scope changes, and Shabaz has not confirmed the delegation in the repository.
- **Requirements kept:** both original requirements are kept as written, and neither is marked PASS.
- **Closing them needs one of:**
  - Shabaz runs every MUST item on his Mac from a clean checkout, then reviews and signs off a full run (AC-024, then AC-022); or
  - Shabaz **and** the guide sign a formal matrix revision accepting a Windows demonstration in place of the Mac items. The revision would be a new matrix revision; Revision 1.0 stays as history.

**Revised tally:** 19 PASS, 4 PARTIAL (AC-005, 007, 009, 011), 0 FAIL, 2 NOT RUN (AC-022, AC-024).

**Overall release acceptance: PENDING.** It waits on:
- AC-022 and AC-024, or a signed scope revision;
- guide approval;
- a human-witnessed Windows demonstration (`v2/evidence/V2-010/windows_demo_witness_TEMPLATE.md`), if the guide wants one.

Issues #68 and #69 were closed on 2026-11-03 with references to their merged fixes.
