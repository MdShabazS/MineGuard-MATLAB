# Testing and Evidence Policy

## Three independent layers
**(1) Static structural checks:** `node scripts/task-gate.mjs validate`, syntax check and GitHub Actions CI. These verify workflow files and dependency integrity, **not MATLAB correctness**.
**(2) MATLAB automated tests:** `matlab.unittest` unit tests and scripted end-to-end runs on a licensed MATLAB host. Required for functions and integration. Save log summary with MATLAB release and seed.
**(3) Human independent testing:** Shabaz may run sample simulations on Mac (after environment confirmation), inspect dashboard, and record deviations. If impossible, say NOT RUN.

## Build-task evidence template
```markdown
# MG-XXX verification
Task: MG-XXX
Owner: Rahil
Tester: <actual person/CI runner and OS>
Result: PASS   <!-- only if actually passed -->
Research: <official references and version>
Implementation: <paths, commit SHA and feature>
Command: <exact executed command>
Environment: <MATLAB release, toolboxes, OS>
Observed output: <real numeric results, log links>
Inputs/seeds: <identifiers>
Known limitations: <explicit>
```

## Definition of DONE
Prerequisites are DONE on **main**, owner is correct, approved PR is merged, expected artifact exists, actual runs produce real evidence, independent reviewer has examined the results, and authoritative task status is updated on main. A branch's `status.json` is a *proposal* until merged. No mock evidence, screenshots without source, or manufactured training curves.

## Failure semantics
If a test fails or isn't run, use BLOCKED/IN_PROGRESS and log the reason. CI on GitHub-hosted runners generally cannot validate MATLAB unless proper MathWorks action/licence is configured; never claim otherwise.
