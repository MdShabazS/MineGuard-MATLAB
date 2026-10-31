# MG014-RUNLOCK-1: reviewer approval and pre-TEST integrity preflight
Task: MG-015
Owner: Rahil
Reviewer decision: Shabaz conditionally approved MG014-RUNLOCK-1 (PR #36 review), on condition that the integrity checks below pass. He also accepted the MG-009 unconfigured-channel fix, kept the frozen detector parameters and tie-break rule, and accepted the negative VALIDATION results.
Run-lock: `tasks/evidence/MG-015/MG014-RUNLOCK-1.json`, **SHA-256 (LF-normalised) `5e9f85334062d68b338c71c53592a0c04e2859adbe0da59452521a21a724a07a`**. The approved run-lock file was **not modified**; its internal `status` field still reads `PROPOSED_PENDING_REVIEW`, and this file records the approval.
Executed: 2026-10-31, MATLAB R2026b Update 1 (PCWIN64, Windows 11) through the official MATLAB MCP Server, plus git; branch `task/MG-015-integration` at HEAD `6ded0ae`. **Executed BEFORE any TEST family was generated.**

| # | Check | Command / method | Observed | Result |
|---|---|---|---|---|
| 1 | Run-lock hash | SHA-256 of LF-normalised `MG014-RUNLOCK-1.json` | `5e9f85334062d68b338c71c53592a0c04e2859adbe0da59452521a21a724a07a` | PASS |
| 2 | Sealed manifest hash | SHA-256 of LF-normalised `experiments/locked/mg014_scenario_manifest.json`, and its git blob at `f87027b` and on `origin/main` | All three `fa5a3fa5e4e35de44d4fba8bf26f5fe362f69d094746fd3a114c051279d19247`, equal to the run-lock `manifest_sha256` | PASS |
| 3 | Detector model and normalisers | Independent re-derivation: `runMG015Locked("prepare", tempname)` (TRAIN fit plus VALIDATION selection only, in a temp folder) compared with the embedded run-lock values using `isequaln` | Model equal: **1**; thresholds equal: **1**. Thermal 293.150765 / 0.100329 K, EM 0.049982 / 0.019783, τT = τE = 2; thresholds thermal_only 2, em_only 2, or 0.7, and 0.9, weighted 2 | PASS |
| 4 | Separate detector-model SHA-256 | `MG014-RUNLOCK-1-detector-model.json` = {source_runlock_sha256, detector_model, method_thresholds} copied from the run-lock, then `certutil -hashfile` | **`cb110fcedc79228758a9d71262cd9b801d1ceee249ffe5e53a4df046fc2838b1`** (file as written with LF) | RECORDED |
| 5 | Implementation unchanged since `f87027b` | `git diff --stat f87027b HEAD -- matlab experiments scripts portal` | Empty. The only files changed since `f87027b` are `tasks/evidence/MG-015.md` and `tasks/evidence/MG-015/MG014-RUNLOCK-1.json` (evidence, non-executable) | PASS |
| 6 | Working tree clean | `git status --porcelain` | 0 entries | PASS |
| 7 | No TEST outputs yet | Checked for `MG-015-test-comparison.csv`, `MG-015-test-per-group.csv` and `MG-015-stress.csv` | None present (0) | PASS |
| 8 | 30 family identities and TEST config digests | For each GF-001..GF-030: `configChecksum(mg015GroupConfig(id))`, group ID and split compared with `config_digests` in the run-lock | 30/30 match, including TEST GF-025..GF-030 | PASS |

**Preflight outcome: ALL PASS.** Authorised command (to be executed exactly once):
```matlab
runMG015Locked("heldout", fullfile('tasks','evidence','MG-015'), "5e9f85334062d68b338c71c53592a0c04e2859adbe0da59452521a21a724a07a")
```
