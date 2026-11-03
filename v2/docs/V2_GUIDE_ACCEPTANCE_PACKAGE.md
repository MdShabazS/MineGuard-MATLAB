# MineGuard Advanced V2 — Guide acceptance package

**Date:** 2026-11-04 · **Team:** Rahil and Shabaz · **Repository:** https://github.com/MdShabazS/MineGuard-MATLAB (`main`)
**Guide approval: NOT YET GIVEN.** This package asks for it.

SIMULATION ONLY. MineGuard V2 does not detect landmines. Every marker it shows is a SUSPECTED anomaly with an uncalibrated score.

## 1. Summary

V2 is a MATLAB simulation of an autonomous survey drone. A virtual quadcopter flies a pre-programmed survey over a synthetic field. Four simulated sensors (RGB camera, thermal camera in Kelvin, LiDAR and virtual GNSS/INS) produce time-synchronised data. A frozen anomaly detector marks suspected anomalies, and a live dashboard shows it all; a finished run can be exported, verified, replayed and reproduced bit for bit. All ten V2 tasks are DONE on GitHub. The original four Phase-1 objectives are kept word for word, and only simulated contributions are claimed (`V2_FINAL_ENGINEERING_REPORT.md` §1, §4).

## 2. Architecture and sensors

| Part | What it does | Evidence |
|---|---|---|
| Mission engine | 20 Hz flight: preflight, takeoff, survey, return, landing; faults for geofence, clearance, timeout, abort | `v2/evidence/V2-002.md` |
| Scene | Seeded 3-D terrain and objects, one geometry source for every view | `V2-003.md` |
| Sensors | RGB and thermal at 5 Hz, LiDAR at 2 Hz, navigation at 10 Hz; invalid data stays invalid with a reason | `V2-004.md`, `V2-005.md` |
| Detector and map | Frozen V2-006 detector, georegistration, coverage layers, evidence records; no access to scenario truth | `V2-006.md` |
| Dashboard | Live 3-D, map, three sensor panels, telemetry, event inspector, controls | `V2-007.md` |
| Export and replay | Checksummed run packages, verification, replay, re-simulation check, fault scenarios | `V2-008.md` |

## 3. How the demonstration runs

`v2/docs/V2_FINAL_DEMO_SCRIPT.md`, about 15 minutes on Windows:
1. Launch.
2. Fly the full survey.
3. Look at the RGB, thermal and LiDAR views and the map.
4. Inspect an event.
5. Pause and resume, then let it land.
6. Export, then replay.
7. Run the timeout-fault and invalid-ray scenarios.
8. Close with the negative science result.

## 4. Verification (Windows 11, MATLAB R2026b; executed by Claude Code)

- Clean clone of `main`: **305/305** tests, static check clean, application checks 31/31 and 20/20 (`v2/audits/V2_RELEASE_READINESS_AUDIT.md`).
- Export, replay and reproduction:
  - the nominal run's package reads back bit for bit;
  - a replay reproduces all 84 recorded events;
  - a re-simulation matches all 3080 samples;
  - tampered packages are refused.
  - Sample package: `v2/evidence/V2-008/sample_package/`.
- Determinism: identical sample and pose digests in every measured mission.
- **macOS: not tested** for the final code.
- **No person has yet watched a full run.** A witnessed demonstration is planned (§7).

## 5. Science (negative results, kept on purpose)

- **V2 VALIDATION:** 0 of 4 synthetic targets found (fused 45 events, all false alarms). The target-free group still had 32 false alarms.
- **V1 sealed TEST** (earlier phase): TP 0, FP 26, TN 470, FN 4.
- **Scores:** uncalibrated, never probabilities. Map positions use the noise-free pose, so they look better than real navigation would allow.
- **Live scenes:** contain no target, so every live marker is a false alarm by construction.
- **Sealed V2 TEST:** not run.
- **Real world:** no result transfers to real sensors, terrain or mines.

## 6. Performance (Windows laptop)

- **Real time:** holds (0.96–0.997×) when the laptop is quiet and MATLAB is in front. In the background it can fall to about 0.3×.
- **Scene refresh:** 5–6.5 per second against the provisional 10 FPS target, which is **not met**.
- **Correctness:** physics and sensors never skip a step.
- **Export:** a full run's package is about 276 MB.

## 7. Decisions requested from the guide

| # | Decision | Options |
|---|---|---|
| 1 | Accept the V2 simulation and its documentation as the project's V2 outcome | approve / reject / approve with conditions |
| 2 | Accept Rahil's Windows laptop instead of a Mac as the demonstration platform (`V2_ACCEPTANCE_MATRIX_R1.1_PROPOSAL.md`; Shabaz must also sign) | approve / reject |
| 3 | Whether a team member's signed witness record of a Windows run is enough, or the guide wants to watch it live | record is enough / live required |
| 4 | Accept the unmet provisional 10 FPS display target as a documented limitation | accept / require more work |

## 8. Approval request (ready to send)

> Subject: MineGuard V2 — request for acceptance review
>
> Dear [Guide's name],
>
> MineGuard Advanced V2 is complete on GitHub: https://github.com/MdShabazS/MineGuard-MATLAB. It is a MATLAB simulation of an autonomous survey drone with simulated RGB, thermal, LiDAR and navigation sensors, a live dashboard, and run export and replay. All ten V2 tasks are done. On Windows, a clean copy passes all 305 tests.
>
> As before, the detector does not find the targets (0 of 4 on held-out data), so the project reports this negative result and makes no detection claim. The display refreshes about 5–6 times a second, below the 10 we aimed for. The final version has not been tested on a Mac.
>
> The attached package (`v2/docs/V2_GUIDE_ACCEPTANCE_PACKAGE.md`) summarises the work. We would be grateful for your decision on the four points in its section 7, especially whether the demonstration may be given on our Windows laptop instead of a Mac. We can demonstrate it live at your convenience (about 15 minutes).
>
> Thank you,
> Rahil and Shabaz

Approval is recorded only when the guide's own reply exists. The team then adds it to `v2/audits/V2_RELEASE_READINESS_AUDIT.md`, with a link or a copy of the reply.
