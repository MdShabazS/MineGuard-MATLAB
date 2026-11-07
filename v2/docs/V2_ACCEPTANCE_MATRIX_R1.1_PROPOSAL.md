# V2 Demonstration Acceptance Matrix — Revision 1.1 PROPOSAL (platform change)

**Status: PROPOSED. NOT APPROVED.** It takes effect only when Shabaz **and** the academic guide sign §5. Until then, Revision 1.0 (`V2_DEMO_ACCEPTANCE_MATRIX.md`) is the only valid matrix, and AC-022 and AC-024 remain NOT RUN.
**Proposed by:** Rahil (V2-007 to V2-010 owner), drafted by Claude Code · **Date:** 2026-11-04
**Authority:** `V2_DEMO_ACCEPTANCE_MATRIX.md` §1: "If impossible on macOS, document failing evidence and formally revise scope with Shabaz and guide; do not silently mark PASS." The Windows delegation (`V2_GOVERNANCE_DELEGATION.md`) explicitly does not cover this change.

Revision 1.0 is not edited. This file is the proposed change and its reasons; if it is signed, Revision 1.0 stays in the repository as history.

## 1. Proposed changes

| AC | Revision 1.0 (unchanged until signed) | Proposed Revision 1.1 |
|---|---|---|
| AC-022 | "Shabaz personally reviews full simulation from start through report with all three sensor windows and map visible on user's Mac; signoff recorded" | A named human witness (Rahil, or Shabaz) personally watches a full run on **Rahil's Windows laptop** from start through export and replay, with all three sensor windows and the map visible, and signs `v2/evidence/V2-010/windows_demo_witness.md`. Shabaz signs this revision. |
| AC-024 | "All MUST tasks execute on user's MATLAB R2026b+UAV Toolbox Mac, including a rebooted/clean checkout, with actual command/log evidence" | All MUST tasks execute on **Windows** MATLAB R2026b with UAV Toolbox from a clean checkout, with actual command and log evidence. **macOS is recorded as NOT RUN / unsupported for the final release**, not as passed. |

Nothing else changes. In particular, §3's provisional targets stay as they are; the ≥ 10 FPS target stays NOT MET.

## 2. Reason

- **Who has done the work:** since 2026-11-03, V2-007 to V2-010 have been built, tested and demonstrated only on Rahil's Windows laptop, under the recorded delegation.
- **The last Mac runs are old:** V2-005 at `ae237ee`, V2-006 at `bb52c0f`, and V2-007 UI at `92f2c26`/`ef09959`. None covers the final V2-007 (`095d7fb`) or V2-008 (`4a7f63b`) code.
- **The demonstration machine:** the guide demonstration is planned on the Windows laptop (`V2_FINAL_DEMO_SCRIPT.md`).

## 3. Windows evidence the revision would rely on

- **Clean clone of `main` (`2d734e9`):** 305/305 MATLAB tests, checkcode clean, app checks 31/31 and 20/20 (`v2/audits/V2_RELEASE_READINESS_AUDIT.md`).
- **Sample package:** verifies and reproduces bit for bit from a clone of `f64508e`.
- **Smoke check on `main` `eec8250`:** launch with the real detector bridge, a 900-tick mission, evidence inspection, export, verification, replay with 36 of 36 events matching, and tampering refused.
- **Determinism:** identical sample and pose digests across all paced missions.
- **Not yet done:** a human-witnessed Windows run. The revised AC-022 would need it.

## 4. Known limits and risks if accepted

- **No Mac support claim:** the release would make no claim to run on a Mac. A guide or examiner using a Mac may find problems that were never tested.
- **Real-time pacing:** on this laptop 1× holds only when it is quiet and MATLAB is in front. 2 of 6 and 5 of 6 detector missions fell below 0.8× in two plans (`V2-008.md` §5). The scene refreshes at 5–6.5/s against the provisional 10.
- **Single machine:** one laptop is the whole platform evidence; there is no second Windows machine.
- **No independent review:** nothing in V2-007 to V2-010 was reviewed by a second person.
- **Science is unaffected:** VALIDATION found 0 of 4 targets, and every event is SUSPECTED and uncalibrated.

## 5. Signatures (blank until genuinely signed)

| Role | Name | Decision (approve / reject / approve with changes) | Date | How given (GitHub comment link, signed letter, e-mail) |
|---|---|---|---|---|
| Original V2 lead | Shabaz | | | |
| Academic guide | | | | |

Rules: a signature counts only if the person gives it themselves (their own GitHub comment, or a signed or e-mailed statement kept by the team). Claude Code never fills this table.
