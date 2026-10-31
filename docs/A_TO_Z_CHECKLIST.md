# MineGuard A–Z Documentation and Readiness Checklist
**Meaning of 'complete' here:** design document exists and is reviewable; it **does NOT** mean the MATLAB feature is implemented or the guide approved it.

| Letter | Project area | Primary document | Document state | Implementation state |
|---|---|---|---|---|
| A | Aim and scope | [PROJECT_MASTER_BRIEF](PROJECT_MASTER_BRIEF.md) | DRAFT FOR REVIEW | Pending |
| B | Background and problem | [PHASE1_BASELINE](PHASE1_BASELINE.md) | VERBATIM PRESERVED | Not affected |
| C | Cost-driven implementation change | [COST_AND_FEASIBILITY](COST_AND_FEASIBILITY.md) | DRAFT FOR REVIEW | MATLAB selected |
| D | Deliverables | [DELIVERY](DELIVERY.md) | DRAFT FOR REVIEW | Pending |
| E | Evidence and ethics | [SECURITY_ETHICS_AND_PUBLICATION](SECURITY_ETHICS_AND_PUBLICATION.md) | DRAFT FOR REVIEW | Execution pending |
| F | Flight and mapping | [ALGORITHM_AND_METHODOLOGY](ALGORITHM_AND_METHODOLOGY.md) | DRAFT FOR REVIEW | Pending |
| G | GPS-like geotag / GCS | [DATA_CONTRACTS](DATA_CONTRACTS.md) | DRAFT FOR REVIEW | Pending |
| H | Hardware vs simulation | [SCOPE_AND_LIMITATIONS](SCOPE_AND_LIMITATIONS.md) | DRAFT FOR REVIEW | Physical integration deferred |
| I | Integration system design | [ARCHITECTURE](ARCHITECTURE.md) | DRAFT FOR REVIEW | Pending |
| J | Journal and guide oversight | [GUIDE_PORTAL](GUIDE_PORTAL.md) | DRAFT FOR REVIEW | Render pending |
| K | Knowledge-base / literature | [LITERATURE_REVIEW](LITERATURE_REVIEW.md) | SOURCE RESEARCH COMPLETE TO DATE | More research pending |
| L | Licensing, third-party reuse | [SOURCE_REUSE_POLICY](SOURCE_REUSE_POLICY.md) | DRAFT FOR REVIEW | No reuse approved |
| M | MATLAB tools and computer requirements | [MATLAB_CAPABILITY_RESEARCH](MATLAB_CAPABILITY_RESEARCH.md) | SOURCE VERIFIED | Local release unverified |
| N | Navigation baseline | [ALGORITHM_AND_METHODOLOGY](ALGORITHM_AND_METHODOLOGY.md) | DRAFT FOR REVIEW | Pending |
| O | Original objectives | [PHASE1_BASELINE](PHASE1_BASELINE.md) | IMMUTABLE | Simulation coverage pending |
| P | Physics, EM and thermal sensing | [PHYSICS_AND_FEASIBILITY](PHYSICS_AND_FEASIBILITY.md) | SOURCE RESEARCH COMPLETE TO DATE | Numerical model pending |
| Q | Quality gates and tests | [QUALITY_GATES](QUALITY_GATES.md) | DRAFT FOR REVIEW | MATLAB tests pending |
| R | Roles, approvals and dependencies | [TASK_DEPENDENCY_EXPLANATION](TASK_DEPENDENCY_EXPLANATION.md) | DRAFT FOR REVIEW | Task gate CI tested |
| S | Scenarios, targets and datasets | [SCENARIOS](SCENARIOS.md), [DATASET_AND_LICENSING](DATASET_AND_LICENSING.md) | DRAFT FOR REVIEW | Pending |
| T | Training PPO / detection models | [AI_AGENTS](AI_AGENTS.md) | DRAFT FOR REVIEW | No training yet |
| U | User dashboard and UX | [DASHBOARD](DASHBOARD.md) | DRAFT FOR REVIEW | Pending |
| V | Validation and comparison | [ACCEPTANCE_MATRIX](ACCEPTANCE_MATRIX.md) | DRAFT FOR REVIEW | No MATLAB runs yet |
| W | Workflow and GitHub-first | [WORKFLOW](WORKFLOW.md) | DRAFT FOR REVIEW | CI verified, main not merged |
| X | Cross-platform compatibility | [ENVIRONMENT](ENVIRONMENT.md), [MATLAB_CAPABILITY_RESEARCH](MATLAB_CAPABILITY_RESEARCH.md) | SOURCE RESEARCH COMPLETE TO DATE | Windows/Mac runtime pending |
| Y | Year-end/final college review | [GUIDE_REVIEW_AND_DEMO](GUIDE_REVIEW_AND_DEMO.md) | DRAFT FOR REVIEW | Deadline Nov 2 |
| Z | Zero fabricated findings | [TEST_AND_EVIDENCE](TEST_AND_EVIDENCE.md) | POLICY WRITTEN | Human/AI compliance required |

## Reading order for the guide
Master brief → Exact Phase-1 objectives → Methodology and technical constraints → Project status portal → Evidence matrix → Future work.

## Reading order for Rahil/Claude Code
Workflow + manifest/status → Environment → Module specs → Data contracts → Acceptance matrix → One READY task → Evidence/PR.

## Reading order for Shabaz/ChatGPT
Phase-1 immutable baseline → Literature and dataset rights → Architecture/quality gates → Current GitHub status → Review each Rahil PR and actual MATLAB evidence.

## Audit rules
- 'Documentation complete' means reviewed and merged, not merely drafted.
- Keep this index current via reviewed PRs when new docs or deliverables are added.
- Missing MATLAB output must be explicitly PENDING/NOT RUN; do not invent figures or accuracy.
