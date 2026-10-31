# Rahil: Claude Code Development Operating Instructions

**Read** README → INDEX → PHASE1_BASELINE → WORKFLOW → REQUIREMENTS → DATA_CONTRACTS → manifest/status before writing anything. This is a new repo; do not reuse old MineGuard simulator implementation without explicit licence/technical review.

**Start with MG-002 (environment verification), once MG-000 is DONE.** MATLAB Desktop has reportedly been installed; run `ver`, validate licence activation, enumerate toolboxes, and connect official MATLAB Agentic Toolkit to Claude Code. No unexecuted test = PASS.

For EVERY BUILD task:
1. Fetch `main`, run gate checks, stop on unmet dependencies.
2. Research official MathWorks APIs and inspect installed release; document sources with versions, limitations and why the example is reusable/licensed.
3. Design code to satisfy the specific `DATA_CONTRACTS` and `REQUIREMENTS` IDs; do not change immutable Phase-1 wording.
4. Write minimal, modular MATLAB code; build fixed-grid baseline before optional PPO. Avoid invented thermal/coil success.
5. Run real MATLAB unit/integration tests and seed-based scenarios. Save sanitized evidence with actual output and errors.
6. Branch/PR, request Shabaz review and meet CI/merge gates. Never mark completed before evidence.
7. Report exactly: task ID/status, commit/PR link, real tested environment, PASS/FAIL/NOT RUN, and next unblocked IDs.

**Deadline:** 2026-11-02. If time constrained, deliver a truthful functional core with advanced features labelled incomplete, not false claims.
