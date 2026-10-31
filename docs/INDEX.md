# MineGuard MATLAB — A-to-Z Documentation Library

**Read first:** [PROJECT_MASTER_BRIEF.md](PROJECT_MASTER_BRIEF.md) and the [A–Z checklist](A_TO_Z_CHECKLIST.md).
**Non-negotiable:** [PHASE1_BASELINE.md](PHASE1_BASELINE.md) preserves the original title, problem statement and four objectives. Verified against the recovered Phase-1 PPTX on 2026-10-31 (see [SOURCE_VERIFICATION.md](SOURCE_VERIFICATION.md)). All MATLAB implementations are simulated and unverified until real execution evidence is committed.

## 1. Academic baseline and research
| Topic | Document |
|---|---|
| Complete project overview and change decision | [PROJECT_MASTER_BRIEF.md](PROJECT_MASTER_BRIEF.md) |
| Literal A–Z readiness checklist | [A_TO_Z_CHECKLIST.md](A_TO_Z_CHECKLIST.md) |
| Original Phase-1 title, PS and objectives | [PHASE1_BASELINE.md](PHASE1_BASELINE.md) |
| Original PPTX slide-3/4 primary-source verification and SHA-256 | [SOURCE_VERIFICATION.md](SOURCE_VERIFICATION.md) |
| Repository audit corrections | [FOUNDATION_AUDIT.md](FOUNDATION_AUDIT.md) |
| Cost transition and feasibility | [COST_AND_FEASIBILITY.md](COST_AND_FEASIBILITY.md) |
| Scope and scientific limitations | [SCOPE_AND_LIMITATIONS.md](SCOPE_AND_LIMITATIONS.md) |
| Verified published literature and open gaps | [LITERATURE_REVIEW.md](LITERATURE_REVIEW.md) |
| Objective-linked, staged academic research plan | [RESEARCH_PLAN.md](RESEARCH_PLAN.md) |
| Dataset review, licensing and synthetic splits | [DATASET_AND_LICENSING.md](DATASET_AND_LICENSING.md) |
| Sources and URLs | [SOURCES.md](SOURCES.md) |

## 2. Technical design
| Topic | Document |
|---|---|
| Functional/nonfunctional requirements | [REQUIREMENTS.md](REQUIREMENTS.md) |
| System architecture | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Algorithms and staged workflow | [ALGORITHM_AND_METHODOLOGY.md](ALGORITHM_AND_METHODOLOGY.md) |
| Design diagrams | [DIAGRAMS.md](DIAGRAMS.md) |
| MATLAB tool/version feasibility | [MATLAB_CAPABILITY_RESEARCH.md](MATLAB_CAPABILITY_RESEARCH.md) |
| Physical sensor assumptions and standoff limits | [PHYSICS_AND_FEASIBILITY.md](PHYSICS_AND_FEASIBILITY.md) |
| Sensor modelling interface | [SENSOR_MODELS.md](SENSOR_MODELS.md) |
| **MG-006 literature-checked thermal/EM physics proxies and S-01…S-14 MATLAB acceptance plan** | [MG006_SENSOR_PHYSICS_AND_TESTS.md](MG006_SENSOR_PHYSICS_AND_TESTS.md) |
| Scene and surrogate targets | [SCENARIOS.md](SCENARIOS.md) |
| Data format, units and label separation | [DATA_CONTRACTS.md](DATA_CONTRACTS.md) |
| **MG-003 frozen v1.0 MATLAB module APIs, records, tests and truth isolation** | [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md) |
| PPO and AI agents | [AI_AGENTS.md](AI_AGENTS.md) |
| **MG-012 frozen-safe PPO observation/action/reward, held-out fair grid comparison and P-01…P-20 tests** | [MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md](MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md) |
| **MG-014 preregistered 30-family train/validation/test manifest, L-01…L-24 integration acceptance, and guide demo gates** | [MG014_LOCKED_TEST_MATRIX_AND_DEMO.md](MG014_LOCKED_TEST_MATRIX_AND_DEMO.md) |
| MATLAB App Designer mission control | [DASHBOARD.md](DASHBOARD.md) |
| **MG-010 dashboard redaction, replay state machine, exports and UI-01…UI-20 tests** | [MG010_MISSION_DASHBOARD_SPEC.md](MG010_MISSION_DASHBOARD_SPEC.md) |
| Experiments and performance metrics | [EXPERIMENTS.md](EXPERIMENTS.md) |
| **MG-008 fusion policy, synthetic split firewall, cell-unit confusion metrics and F-01…F-18 acceptance tests** | [MG008_FUSION_DATASET_AND_METRICS.md](MG008_FUSION_DATASET_AND_METRICS.md) |

## 3. Engineering execution and evidence
| Topic | Document |
|---|---|
| GitHub task workflow | [WORKFLOW.md](WORKFLOW.md) |
| Protected main configuration | [BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md) |
| Two-person role policy and AI autonomy boundaries | [TEAM_EXECUTION_PROTOCOL.md](TEAM_EXECUTION_PROTOCOL.md) |
| Task ownership and dependencies | [TASK_DEPENDENCY_EXPLANATION.md](TASK_DEPENDENCY_EXPLANATION.md) |
| Environment verification | [ENVIRONMENT.md](ENVIRONMENT.md) |
| Step-by-step Rahil MATLAB/Claude troubleshooting | [RAHIL_SETUP_SUPPORT.md](RAHIL_SETUP_SUPPORT.md) |
| Reproducible implementation/test instructions | [IMPLEMENTATION_RUNBOOK.md](IMPLEMENTATION_RUNBOOK.md) |
| Objective-to-test mapping | [ACCEPTANCE_MATRIX.md](ACCEPTANCE_MATRIX.md) |
| Quality gates and definition of DONE | [QUALITY_GATES.md](QUALITY_GATES.md) |
| Evidence format and testing discipline | [TEST_AND_EVIDENCE.md](TEST_AND_EVIDENCE.md) |
| Third-party source usage | [SOURCE_REUSE_POLICY.md](SOURCE_REUSE_POLICY.md) |
| Safety, ethics and publication policy | [SECURITY_ETHICS_AND_PUBLICATION.md](SECURITY_ETHICS_AND_PUBLICATION.md) |
| Decision history | [DECISION_LOG.md](DECISION_LOG.md) |
| Risks and open questions | [OPEN_DECISIONS_AND_RISKS.md](OPEN_DECISIONS_AND_RISKS.md) |
| Claude Code technical handoff | [HANDOFF_RAHIL.md](HANDOFF_RAHIL.md) |
| ChatGPT documentation/review handoff | [HANDOFF_SHABAZ.md](HANDOFF_SHABAZ.md) |
| Foundation bootstrap status | [FOUNDATION.md](FOUNDATION.md) |

## 4. Guide and college review
| Topic | Document |
|---|---|
| Read-only Render status portal | [GUIDE_PORTAL.md](GUIDE_PORTAL.md) |
| Guide questions, demo walk-through and viva | [GUIDE_REVIEW_AND_DEMO.md](GUIDE_REVIEW_AND_DEMO.md) |
| **MG-020 Render static deployment, real URL and HTTPS first-fetch evidence** | [MG020_RENDER_DEPLOYMENT_CHECKLIST.md](MG020_RENDER_DEPLOYMENT_CHECKLIST.md) |
| Report and presentation chapters | [REPORT_BLUEPRINT.md](REPORT_BLUEPRINT.md) |
| Nov 2 delivery/release checklist | [DELIVERY.md](DELIVERY.md) |
| Portal installation and limitations | [../portal/README.md](../portal/README.md) |

## 5. Machine-readable authority
- `tasks/manifest.json` — owners and true dependencies.
- `tasks/status.json` — proposed states, authoritative only when merged to `main`.
- `tasks/updates.json` — evidence-backed plain-language guide work journal.
- `scripts/task-gate.mjs` — dependency validation.
- `.github/workflows/task-gate.yml` — GitHub CI checks task rules and portal JavaScript, **not** MATLAB.
- `matlab/mineguard_environment_check.m` — Rahil's installed-release audit; has NOT been run by ChatGPT.
- `render.yaml` and `portal/` — guide static website, not yet deployed.

**Document state:** DRAFT pending technical cross-review and PR merge. The presence of a specification never implies the engineering feature is built.
