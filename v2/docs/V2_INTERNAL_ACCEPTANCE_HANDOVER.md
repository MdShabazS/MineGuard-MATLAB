# V2 internal acceptance and handover (project lead)

**Date:** 2026-11-04 IST · **Revision:** 1.0.1 · **Baseline:** GitHub `main` at `7c9f97b`
**1.0.1 (Rahil's Windows session):** AC-025 wording corrected to the authoritative classification in audit §6 (PASS on Windows; provisional 10 FPS target NOT MET). Nothing else changed.
**Recorded by:** Claude Code (Shabaz's Mac session), on Shabaz's explicit instruction in that session. Shabaz wrote the decisions in §1. Claude Code wrote this file.
**This file is not a signature.** It is not Shabaz's handwritten signature, and it is not a new personal GitHub confirmation. It does not fill, and does not stand in for, the signature table of `V2_ACCEPTANCE_MATRIX_R1.1_PROPOSAL.md` §5.

SIMULATION ONLY. Every event is a SUSPECTED anomaly with an uncalibrated score. V2 VALIDATION found 0 of 4 targets, and the sealed TEST was not run.

## 1. Shabaz's internal decisions (as instructed)

1. **Accepted for internal handover:** the completed implementation of MineGuard Advanced V2, V2-001 to V2-010.
2. **Basis for internal software completion:** the existing Windows MATLAB verification evidence.
3. **Primary demonstration platform:** Rahil's Windows laptop.
4. **Accepted known limitations for internal handover:**
   - The provisional ≥ 10 FPS target is not met. AC-025 itself is PASS on Windows: performance was recorded and checked (`V2_RELEASE_READINESS_AUDIT.md` §6). The 10 FPS target remains NOT MET.
   - Simulation performance depends on laptop load.
   - Some acceptance criteria are PARTIAL.
   - Final Mac compatibility testing has not been done.
   - The detector has not shown reliable detection of synthetic targets.
   - The software is a research simulation, not a validated physical landmine detector.
5. **Delegated to Rahil:** running the final Windows demonstration, personally completing the witness record, managing evidence PRs and finalizing the internal handover documentation (§3).
6. **Guide approval:** this internal closure does not seek academic guide approval or sign-off.
7. **Not authorized:** fabricated test results, human signatures, witness statements, guide approval, or unsupported scientific claims.
8. **Not claimed:** Shabaz did not personally run the final Mac acceptance tests, and did not witness Rahil's demonstration.

## 2. What is and is not established

| Item | State | Source |
|---|---|---|
| All 10 V2 tasks | DONE on `main` | `v2/tasks/status.json` |
| Delegation of V2-007 to V2-010 to Rahil | Confirmed by Shabaz from his own GitHub account, 2026-11-03 18:37 UTC | [#103 comment 6612380409](https://github.com/MdShabazS/MineGuard-MATLAB/pull/103#issuecomment-6612380409), quoted in `V2_GOVERNANCE_DELEGATION.md` |
| **Internal software acceptance by Shabaz** | **Given for internal handover** (this record, §1) | This file |
| Windows verification already run | Done by Claude Code on Rahil's laptop. Clean clone `2d734e9`: 305/305 tests, checkcode clean, app checks 31/31 and 20/20. Sample package verifies and reproduces on `f64508e`. Smoke check on `eec8250`. | `v2/audits/V2_RELEASE_READINESS_AUDIT.md`, `V2_ACCEPTANCE_MATRIX_R1.1_PROPOSAL.md` §3 |
| **Human-witnessed Windows demonstration** | **NOT YET DONE.** Rahil has not yet witnessed a run, and `v2/evidence/V2-010/windows_demo_witness.md` does not exist. | `V2_FINAL_DEMO_SCRIPT.md` |
| **Formal acceptance under matrix Revision 1.0** | **NOT PASSED.** It is not changed by this record. | `V2_DEMO_ACCEPTANCE_MATRIX.md`, `v2/evidence/V2-009.md` |
| Matrix Revision 1.1 | PROPOSED, unsigned, **not effective** | `V2_ACCEPTANCE_MATRIX_R1.1_PROPOSAL.md` §5 |

Internal acceptance is a project decision about handover. It does not turn any NOT RUN, PARTIAL or FAIL result into PASS.

## 3. Responsibilities transferred to Rahil

1. **Run the full Windows demonstration** on his laptop, following `v2/docs/V2_FINAL_DEMO_SCRIPT.md` from a clean checkout of `main`.
2. **Record it with `demo_record()`** (`v2/evidence/V2-010/demo_record.m`): use `rec.shot(...)` for screenshots at the script's steps and `rec.finish()` for the log.
3. **Witness it and sign it himself.** Rahil watches the run himself, then completes and signs `v2/evidence/V2-010/windows_demo_witness.md` from the template. Claude Code must not fill in or sign this file. If nobody watches, the record says "No human witnessed the demonstration".
4. **Commit the actual evidence:** the screenshots, the log and the witness record, through an evidence PR under the existing gate rules.
5. **Final verification of the internal handover:**
   - Check that the release audit and handover documents match `main`.
   - Merge the evidence PRs and this record's PR.
   - Close the internal handover.

No further routine development reviews or approvals by Shabaz are required for this internal closure.

## 4. What still needs Shabaz personally

- **Nothing for internal handover.**
- **Only for formal acceptance**, if the team pursues it later:
  - Shabaz signs Revision 1.1 §5 himself, through his own GitHub comment or a signed statement.
  - Or Shabaz performs the Mac review (AC-022) and the Mac run (AC-024) himself.
- Guide approval is outside this workflow.

## 5. Formal acceptance exceptions that remain open

- **AC-022** (Shabaz's personal review on his Mac): NOT RUN.
- **AC-024** (all MUST tasks on Mac): NOT RUN.
- **AC-025:** PASS on Windows (audit §6). The **provisional ≥ 10 FPS target remains NOT MET**: measured 5–6.5 refreshes/s, and 1× pacing holds only on a quiet host. This is a recorded limitation, not an open criterion.
- **4 criteria PARTIAL**, as listed in `v2/evidence/V2-009.md`.
- **Revision 1.1:** unsigned by Shabaz and the guide, so not effective.
- **Guide approval:** not sought in this workflow, so formal acceptance stays PENDING.
- **Human-witnessed demonstration:** not yet done.
- **Detection:** not achieved. VALIDATION found 0 of 4 targets, and the sealed TEST was not run.
