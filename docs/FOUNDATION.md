# MG-000 — Foundation Establishment Record

Task: MG-000
Owner: Shabaz
Status: IN_PROGRESS (proposed documentation branch, not merged)
Date: 2026-10-31

## Scope
New public GitHub repository verified; old repo untouched. This branch proposes immutable Phase-1 transcription, A-to-Z docs, dependency DAG, Node-based gate, GitHub Actions CI, **read-only guide progress portal and MATLAB environment diagnostic script**, with no MATLAB implementation claims.

## Acceptance remaining
- CI executes dependency-gate and guide portal unit tests successfully; inspect real logs.
- Rahil reviews initial foundation PR after collaborator access.
- Merge approved foundation into main, confirm links to files and test results.
- Only then mark MG-000 DONE with evidence on main.
- Portal deployment to Render is a separate manual integration milestone; no URL is claimed now.

## Research
Official MathWorks, GitHub and Render sources catalogued in SOURCES.md, GUIDE_PORTAL.md and RAHIL_SETUP_SUPPORT.md. Student MATLAB environment and scientific model parameters remain pending.

## Re-audit improvements included in this foundation PR
- PR base-branch transition enforcement and negative tests; bootstrap exempt only while establishing MG-000.
- Core simulation path decoupled from experimental PPO, optional PPO task MG-019 introduced.
- Render deployment and browser QA explicitly tracked as MG-020 and MG-021.
- Original Phase-1 slide source must be supplied/verified; no unsupported 'independently verified verbatim' claim.
- DRC Zenodo dataset documented as optional pending licence and modality alignment.
- Research and repository corrections are proposed, not merged or locally MATLAB-tested.
