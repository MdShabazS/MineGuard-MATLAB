# Decisions, Assumptions and Open Issues (as of 2026-10-31)

## Confirmed by user/guide
- Preserve **exact** original Phase-1 title, problem statement and four objectives. Only implementation becomes MATLAB/Simulink.
- Research-grade advanced virtual environment, thermal + metal-response simulation, hybrid mathematical+AI fusion, fixed-grid flight vs PPO, App Designer GCS.
- Full project final demonstration target **2026-11-02**. No skipped QA or false claims for schedule.
- Public new GitHub `MdShabazS/MineGuard-MATLAB`; old MineGuard repo unchanged.
- Shabaz owns ChatGPT-led research, documentation, project coordination and independent testing if available.
- Rahil owns Claude Code programming, MATLAB local execution and reproducible tests.
- PR review by other member, GitHub Actions task validation and dependency DAG. Independent work allowed when truly unblocked.
- Guide portal: Render Static Site, read-only GitHub task/evidence dashboard with owner progress, blockers, work journal and PR/CI.
- Rahil reports MATLAB Desktop installed on Windows; student licence available through college; exact version/toolboxes/activation not verified.

## Independently checked in connected GitHub
- New public repository exists and `MdRahilA` has **write** permission.
- Foundation PR #1 open on `setup/mg-000-foundation`, review requested from Rahil.
- PR GitHub Actions checks previously passed for DAG and four guide-portal tests; **not MATLAB**.
- Public repo ruleset not configured at last check; no authenticated Render deployment verified.

## Critical uncertainty
The Phase-1 objective says 'accurate subsurface detection' from airborne metal-coil+thermal. Physics imposes severe coil standoff and environmental limits. **Keep wording but explicitly explain unvalidated feasibility.**

## Unresolved decisions
See [OPEN_DECISIONS_AND_RISKS.md](OPEN_DECISIONS_AND_RISKS.md) for detailed risk log and required evidence. Changes to plan must go through reviewed PR, never silently alter Phase-1 baseline.

## Next milestone
Review/merge PR #1 after docs QA. Then record approved MG-000 completion and enable dependent tasks. Rahil may independently inspect MATLAB even while the PR is pending, but must submit real `ver`/MCP evidence before claiming MG-002 DONE.

## 2026-10-31 foundation audit follow-up
- Corrected critical weakness where task prerequisites were checked against a PR's proposed statuses rather than authoritative target-branch statuses; added PR comparison CI and negative tests.
- PPO MG-013 no longer blocks core MG-015, and optional PPO integration MG-019 is separately tracked.
- Guide portal Render deployment MG-020 and real browser QA MG-021 are explicit tasks; no live site is claimed.
- Primary original slide deck is absent from new repository, so original-wording verification remains PENDING. Wording itself has not been changed.
- Zenodo DRC 2026 candidate added as research only, **licence not established** and no data downloaded.
- Read-only guide portal Task Gate CI presentation will filter to actual `main` runs.

## 2026-11-15 — Team change: Claude-only, three sessions

- **Decision (Shabaz):** MineGuard is a MATLAB-only project worked on by three Claude Code sessions:
  - **Shabaz's Claude** (Mac): project lead and decision maker.
  - **Rahil's Claude** (Windows).
  - **Danish's Claude**.
- **ChatGPT and Codex are no longer used.**
- **Work split:** the split for the next phase will be defined later in [TEAM.md](TEAM.md).
- **Earlier entries in this log** and all earlier evidence keep their original wording.

## 2026-11-21 — V2.2 follow-up from the deep research; marks on BITM imagery

- **Research:** `v2_2/research/V22_RESEARCH_DRONE_LANDMINE_SURVEY.md`, with cited notes in `v2_2/research/notes/`. Drones gather evidence of suspicion, not proof. IMAS 07.11 allows only *suspected* hazardous areas from indirect evidence. LiDAR finds conflict features, not mines.
- **Decision (Shabaz):** new tasks, all owned by Shabaz:
  - V22-T10: honest evaluation and wording;
  - V22-T11: draw any field, simulated drone survey, suspected-anomaly map;
  - V22-T12: relief-anomaly layer.
  V22-T6 (Rahil) waits for T11 and T12, so the integration happens once.
- **Rule change:** suspected-anomaly marks may appear on BITM imagery **only in the V22-T11 view**, under these conditions:
  - as hollow symbols labelled "SUSPECTED anomaly (SIMULATION)";
  - with a persistent "SIMULATION — NOT A HAZARD MAP" watermark and a coverage-quality layer;
  - synthetic targets only behind an evaluation toggle;
  - coordinates never exported as findings.
  All other views keep the V22-T3 rule of no hazard markers on real imagery.

## 2026-11-25 — V22-T11 survey parameters (deliberate deviations, recorded)

- **Altitude 6.8 m, not the research's 10–12 m.** The simulated RGB camera is 320×240 px with a 70° field of view, far coarser than the research cameras (0.2–0.4 cm/px). The planner picks the highest altitude that keeps at least 5 pixels on the smallest detector target (0.15 m): 6.8 m, 2.98 cm/px. This follows the research's pixels-on-target rule.
- **Side overlap 75 %,** as in the research. Line spacing is clamped to V2.1's 2 m minimum.
- **False alarms are counted inside the drawn field only.** The four corner-marker poles that the simulated world places at the field corners are flagged by the detector and counted as clutter. The panel says so.


## 2026-11-26 — V22-T6 moved from Rahil to Shabaz

Shabaz asked his Claude to complete V22-T6 (Satellite tab in V2.1 mission control). The task was TODO and not started, so its owner moves to Shabaz through a plan PR (the gate allows owner transfer of a TODO task, as for V22-T3). Rahil's Claude stays available for Windows verification; the full Windows regression remains in V22-T8.
