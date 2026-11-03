# V2 governance: delegation of V2-007 to V2-010

**Date:** 2026-11-03 IST · **Recorded by:** Claude Code, on Rahil's instruction · **Revision:** 1.0

## What changed

Rahil stated on 2026-11-03 that Shabaz has delegated operational ownership of V2-007 to V2-010 to him. This covers technical and performance decisions, implementation, testing, PR integration, documentation and the final audit, without Shabaz's routine review.

This record first rested on Rahil's statement alone.

**Confirmed by Shabaz, 2026-11-03 18:37 UTC, from his own GitHub account** ([issuecomment-6612380409](https://github.com/MdShabazS/MineGuard-MATLAB/pull/103#issuecomment-6612380409)): "I confirm that I authorized Rahil to take operational ownership of MineGuard V2-007 through V2-010, including implementation, technical decisions, MATLAB verification, PR management, merges and task completion. This delegation does not constitute approval of unperformed Mac acceptance testing or academic guide signoff."

The confirmation covers the work and the merges. In Shabaz's own words, it is **not** an approval of the Mac acceptance items (AC-022, AC-024) or of the guide's sign-off.

## Rules from now on (V2-007 to V2-010 only)

1. Rahil may merge a PR, or tell Claude Code to merge it, once the required `task-gate` check passes.
2. Nobody bypasses branch protection or required checks, approves under another person's name, or records a human review that did not happen. A PR merged without a second person's review says so in its body.
3. Task status still changes only through the V2 gate: one transition per PR on `task/V2-XXX-*`, and manifest changes only on `v2/plan-*` branches.
4. Owner transfer of a TODO task goes through a `v2/plan-*` PR. `scripts/v2-gate.mjs` allows that PR to change one field in `status.json`, the task's `owner`, to match the manifest. Nothing else in the status file may change.
5. Earlier records are not rewritten. V1 tasks, V2-001 to V2-006 and earlier evidence keep their original owners and wording.

## What the delegation does not cover

- **Guide approval.** Only the guide can give it. It stays pending until the guide does.
- **macOS tests.** They are NOT RUN unless someone runs them on a Mac. A Windows result never replaces a Mac result.
- **Matrix scope changes.** `V2_DEMO_ACCEPTANCE_MATRIX.md` §1 says a MUST item that is impossible on macOS needs a formal revision with Shabaz and the guide. Without the guide's agreement, such items are reported as NOT RUN or NOT MET, never PASS.
- **Human review.** Rahil can be the human witness of a Windows demonstration only if he watches it and records it himself. Claude Code runs do not count as human observation.
