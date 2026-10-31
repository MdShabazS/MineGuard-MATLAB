# MineGuard-MATLAB Foundation Re-audit — 2026-10-31
**Status:** Proposed corrections on PR #1, pending peer review and merge. GitHub static CI is not MATLAB validation.

## Defects discovered and remediation
| ID | Finding | Remediation | Verification |
|---|---|---|---|
| A01 | `main` lacks documentation until PR merged | Leave changes on PR #1; invite Rahil review; no direct main push | Check GitHub PR merge state |
| A02 | No main branch ruleset | Admin must configure PR review, required Task Gate, no force-push/deletion | Check API rulesets and PR branch protection |
| A03 | Gate permits a PR to mark prerequisites DONE in same change | Add `scripts/pr-gate.mjs` comparing base-branch statuses and negative tests | GitHub Actions test suite + real base ref |
| A04 | PPO blocks all core integration | Remove MG-013 prerequisite from MG-015, use optional MG-019 | Manifest DAG CI |
| A05 | Guide deployment/QA lacks task coverage | MG-020 and MG-021 added with proper evidence | Manifest and CI |
| A06 | Original Phase-1 PPTX not in new repository | Primary-file checklist + pending verification, freeze transcription | Actual presentation comparison PENDING |
| A07 | Important multimodal research candidate missing | Verified DRC 2026 Zenodo DOI in dataset plan, licence still unknown | Publisher record + no dataset redistribution |
| A08 | Duplicated workflow heading and visible Markdown typo | Fix sections and stray literal newline | Markdown spot audit |
| A09 | Portal 4 unit tests lack failure-mode breadth | Added CI filter negative test and portal contract test | GitHub Actions JS test results |
| A10 | Portal CI might show PR checks as main status | Only select check runs with `head_branch==='main'` | Unit test |
| A11 | Core engineering MATLAB not tested | Require MG-002 real `ver`/toolbox/Claude MCP evidence, later MATLAB tests | PENDING by design |

## Remaining manual prerequisites
- Rahil review of PR #1 and comparison with original Phase-1 slides.
- Configure branch ruleset (not active until verified by API).
- MATLAB installation, licences/toolboxes/MCP validated on Rahil's Windows PC.
- Deploy Render and run desktop/mobile browser QA; no URL exists yet.
- Run MATLAB model tests and collect actual experiment evidence.

## No-go conditions
Do not mark any MATLAB task DONE for code syntax only, or claim detector field accuracy for synthetic data. Do not merge without the agreed peer review.

## Second integrity pass
A manifest-edit bypass was identified while strengthening PR checks. The updated PR gate now compares the proposed task manifest to the **actual target-branch manifest**, rejecting simultaneous manifest and task-status changes. Added negative test to lock this behaviour.
