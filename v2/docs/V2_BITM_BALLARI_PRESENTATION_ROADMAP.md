# MineGuard Advanced V2 — BITM/Ballari campus presentation roadmap

**Created:** 2026-11-02 · **Status:** Planning only, NOT implemented or demonstrated · **Audience:** college guide, reviewers, engineering team.

This is the detailed acceptance/reference plan for **ENH-008..ENH-011**, tracked on the existing read-only [Guide Observatory](https://mineguard-guide-portal.onrender.com) through [`v2/roadmap/enhancements.json`](../roadmap/enhancements.json). These are **optional demonstration enhancements**, separate from the ten protected V2 engineering tasks and their completion count.

## Presentation concept

The lecturer recognizes Ballari and BITM, then sees a simulated flight over *geographic context*, followed by the evidence-first synthetic MATLAB digital twin. Only the background map is real-world imagery. The drone, plan, camera/LiDAR/thermal, detector events, and suspect/evaluation results remain **synthetic and unvalidated**.

### Proposed three-part sequence

1. **Orientation:** labelled Ballari overview with an explicit public source and provider credits. Identify BITM at a user-reviewed approximate place, not the operator's current location.
2. **Campus context:** optional approved BITM area map, home marker and simulated/planned mission route. This is **not** a flight made at BITM, a surveyed map or real-world detection. No mine/suspected-target markers on a real campus image.
3. **Research simulation:** transition to the existing reliable offline ENU map and UAV 3-D scene. Keep synthetic suspected events, evidence crops, uncertainty, truth-separated evaluation and false-alarm discussion on simulated-only displays.

A 2D geographic inset or cut-to-slide is an acceptable fallback if simultaneous satellite + 3-D rendering would degrade live performance.

## The four campus enhancement issues

| ID | Owner | Current planning status | Issue | Acceptance prerequisite |
|---|---|---|---|---|
| **ENH-008** Campus demo mode | Shabaz / Mac; Rahil geometry review | PLANNED | [#78](https://github.com/MdShabazS/MineGuard-MATLAB/issues/78) | #72/#75 accepted, operator-approved WGS84 anchor & bounds |
| **ENH-009** Offline imagery and rights | Shabaz source review; Rahil fallback verification | BLOCKED | [#79](https://github.com/MdShabazS/MineGuard-MATLAB/issues/79) | Written permitted use/source, appropriate offline asset or synthetic schematic |
| **ENH-010** Ballari-to-BITM intro | Shabaz / Mac | PLANNED | [#80](https://github.com/MdShabazS/MineGuard-MATLAB/issues/80) | Source location/attribution and light-weight intro plan |
| **ENH-011** 2-D/3-D linked playback | Shabaz UI; Rahil mission contracts | BLOCKED | [#81](https://github.com/MdShabazS/MineGuard-MATLAB/issues/81) | Accepted core V2-006/007 + [#76](https://github.com/MdShabazS/MineGuard-MATLAB/issues/76) performance gate |

The existing **ENH-002 satellite prototype** is not acceptance-ready. Original Mac testing on PR #72 reported 7/7 geographic tests and real imagery loading, **but absent source attribution and 1.09:1 light-theme labels**. PR #75 is a proposed correction that must pass actual MATLAB and provider-credit review. Neither PR has merged to main at this document's publication.

## Data provenance and geographic rights

- An *approximate anchor* for a campus illustration must be explicitly entered and reviewed by the project team. Never use the `[0 0 0]` virtual WGS84 placeholder or imply a manually chosen point is a surveyed real takeoff location. The original Great Pyramid point is a technical fixture, not a Ballari location.
- Treat **Esri/other live satellite basemaps as online third-party content**. A real tile loading during MATLAB tests does not grant rights to download bulk tiles, build an offline cache, redistribute an image in a public GitHub repository, or remove provider/source credits.
- Before saving any campus imagery, record provider, product/source, rights granted for local/offline use, screenshot/public presentation permission, whether redistribution is permitted, acquisition date, coordinate system, bounds and complete required attribution. If any of these are unclear, use a separately licensed static image or a **clearly labelled synthetic schematic** instead.
- Online geographic context must fail independently from the offline MATLAB mission and should visibly report unavailable basemap tiles rather than silently pretending that a grey basemap is successful imagery.
- Never place synthetic suspected-mine markers or output coordinates directly on BITM campus satellite imagery: the research has not established real georegistration or any landmine detection capacity.

## Implementation and verification gates

1. Keep all campus features in a separate documentation and feature branch; no edits to frozen V1, detector thresholds, partition files or official task-status JSON.
2. Accept the satellite preview's explicit anchor, WGS84 math, provider attribution, dark/light readability, network failure handling and Mac/Windows tests **before** deriving a campus view.
3. Define an approved BITM demo rectangle and independently test local-coordinate → WGS84 transforms on known synthetic points. Distinguish the demo's assumed altitude from measured ellipsoidal height.
4. For any optional 3-D/inset synchronization, use the **single public MissionEngine clock/pose** and consistent home/route/boundary data. Never synthesize a second hidden mission timeline.
5. Verify labels, location units, provider source links, simulated-only banners, pause/resume/reset, geometry, graceful offline behavior, GUI cleanup and repeatable screenshot captures.
6. Benchmark the primary Mac at the frozen provisional >=0.8× demo-quality simulation criterion (preferred 1×) with the optional view; if slow, default to separate orientation slides or disable the extra view without skipping simulation or sensor samples. Document Windows measurements separately.
7. Test a clean checkout and offline start. A guide demonstration must not depend on a live third-party network request.
8. After evidence review, propose any status updates via PR; **only Shabaz merges**. A passed GitHub Task Gate is not a MATLAB execution claim.

## Work visibility for the college guide

The portal lists every ENH entry with its **owner, priority, actual review state, why it is blocked, and a link to the PR/issue**. The enhancement summary is maintained in `main` and may lag PR events until a reviewed roadmap update merges. The official V2 10-task completion percentage remains separate and unchanged.

**Disclosure for viva/presentation:** “The geographic backdrop is genuine third-party imagery where permitted; every aircraft movement, survey route, sensor observation and suspected anomaly shown by MineGuard is simulated. No real-world mine detection, location accuracy or safe-land conclusion is claimed.”
