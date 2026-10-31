# Main-Branch Ruleset — Required Administrator Setup

**Status:** PENDING configuration. GitHub API at audit time returned **no rulesets**. A green GitHub Actions run does NOT prevent users with write permissions from bypassing checks by pushing directly to main.

## Manual admin steps on GitHub
1. Open https://github.com/MdShabazS/MineGuard-MATLAB/settings/rules and create a **new branch ruleset** for branch `main`.
2. Set ruleset **Active**. Target includes exact `main` branch.
3. Require a pull request before merging, with at least **1 independent approving review**. Dismiss stale approvals after new commits if available; do not allow author self-review.
4. Require status check `task-gate` from the official GitHub Actions workflow (select source appropriately). Ruleset may need a recent workflow run to list the check.
5. Block force pushes and branch deletion, and avoid broad bypass permissions (including admin bypass if practical).
6. Save ruleset. Verify https://api.github.com/repos/MdShabazS/MineGuard-MATLAB/rulesets now shows an active matching rule and inspect the branch protection UI.
7. Do not merge PR #1 until the required check is green and Rahil has reviewed it.

Official docs: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets and https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets.

## Required CI / limitations
- `task-gate` statically audits DAG/status/evidence and executes PR transition tests.
- `pr-gate` compares against target `main` snapshot. It must reject status changes with unmerged prerequisites; governance manifest edits cannot coincide with state transitions.
- A malicious user with direct push rights can bypass these only until the ruleset is active.
- GitHub Actions CI is **not** MATLAB execution. A real MATLAB build requires local logs and review.

## Screenshot/evidence
Once activated, store sanitized branch-rule and GitHub Actions confirmation in a PR comment or `docs/FOUNDATION.md`. No ruleset has been created automatically by this document.
