# MineGuard Advanced V2 — high-fidelity MATLAB research simulation

**Development phase:** planned. **Authoritative guide view:** [existing guide portal](https://mineguard-guide-portal.onrender.com/) (the same V1 Render static service, not another deployment). **Source of status:** `main:v2/tasks/manifest.json` and `main:v2/tasks/status.json`. The current V2 branch is only an implementation branch and is **not** counted as accepted work until merged.

## Goal and verified starting point

The aim is a high-fidelity, time-synchronized **MATLAB virtual mission** with a realistic animated UAV, 3-D terrain, takeoff, waypoint survey, return and landing, synthetic RGB/thermal/LiDAR streams, suspected-anomaly evidence, replay and operator reporting. The final demonstration must be visually credible **and** scientifically honest, with a single simulation clock and explicit provenance.

- **User-observed local Mac test (2026-11-01):** MATLAB R2026b Update 1 with UAV Toolbox 26.2; `uavScenario`, `uavPlatform`, `multirotorFlightTrajectory` functions available. A short 3-D quadrotor waypoint-interpolation trial ended with the MATLAB message `MineGuard V2 virtual flight completed.` This is an exploratory local feasibility test, **not yet committed code, a verified closed-loop flight controller, or accepted V2 task evidence**.
- Existing physical drone + QGroundControl can fly planned waypoints. **Neither QGC nor physical hardware is required for V2 simulation**. Raspberry Pi, physical RGB/thermal/LiDAR payload and actual sensor integration are deferred to separately verified future hardware work.
- V1 is a reproducible synthetic offline 2-D mission replay, **22/22 legacy tasks DONE**; its frozen once-only TEST and PPO evidence remain unchanged.
- The V1 weighted synthetic detector missed all four held-out positive cells: **TP 0, FP 26, TN 470, FN 4**. No operational mine detection, clearance, safety performance or validated buried-mine location is claimed. V2 anomaly alerts remain **SUSPECTED** and **synthetic**.

## Two-member ownership

| Member | Tool | Primary responsibility |
|---|---|---|
| Shabaz | ChatGPT | Requirements, architecture, independent verification, scientific limitations, guide material, acceptance and documentation |
| Rahil | Claude Code | MATLAB engineering, 3-D scene and flight simulation, virtual sensor integration, integrated UI, reproducible tests and code evidence |

Human team members own tasks. AI tools are assistants, not execution evidence.

## Independent V2 task plan

- V2-001: architecture and acceptance freeze (Shabaz)
- V2-002: synchronized live mission engine (Rahil)
- V2-003: high-fidelity 3-D scene and cameras (Rahil)
- V2-004: synthetic sensing and evaluation contracts (Shabaz)
- V2-005: synchronized virtual sensor streams (Rahil)
- V2-006: evidence-aware anomaly mapping (Rahil)
- V2-007: mission-control application (Rahil)
- V2-008: failure/performance testing and export (Rahil)
- V2-009: independent verification audit (Shabaz)
- V2-010: final guide demo/handover (Shabaz)

See `v2/tasks/manifest.json` for exact dependencies and evidence paths.

## Status and review protocol

1. Task entries begin **TODO**; an unmet dependency is shown **BLOCKED** in the guide portal. No V2 DONE is awarded merely for creating these records or because a local proof-of-concept ran.
2. Once prerequisites are DONE on `main`, a member may start their own task on a `task/V2-XXX-description` branch, changing only that task from TODO to IN_PROGRESS.
3. The member implements and tests the work, commits evidence to `v2/evidence/V2-XXX.md` with `Task: V2-XXX` and `Owner: Shabaz|Rahil`. BUILD tasks additionally require actual tester, environment, commands, observed output, result and research references.
4. A separate reviewed status-only PR changes IN_PROGRESS to DONE after the evidence is on `main`. A draft PR, screenshots without context or passing Node CI alone is not a verified MATLAB run.
5. The portal updates **from merged main only**, every five minutes while open or on manual refresh, preserving V1 and V2 progress as independent measures.

Run `node scripts/v2-gate.mjs validate` (and `... ready`) for local governance checks. PRs are audited with `node scripts/v2-gate.mjs pr` in GitHub CI. Do not modify V1 `tasks/manifest.json`, `tasks/status.json` or the locked TEST to create V2 progress. V2 schedule is TBD rather than inheriting V1's deadline.

## Expected acceptance criteria

- Reproducible autonomous virtual mission including true takeoff, altitude changes, survey, return and landing, with measured simulation time versus wall time.
- All visual, simulated telemetry and sensor updates share the simulation clock; invalid sensor outputs and failure cases are visible.
- Full test evidence on the actual MATLAB runtime, including performance (measured, not promised), export/replay correctness, deterministic seeds and obvious simulation-only banners.
- Hidden synthetic truth is isolated from the detector and user-facing operational data; the separate evaluator may consume it under documented rules.
- Any improved detection algorithm uses newly specified experiments and **new held-out families**, not the consumed V1 sealed TEST.
- Live guide demonstration emphasizes capabilities honestly; no claims of real-world mine identification or civilian-area clearance.

