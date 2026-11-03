# MineGuard Advanced V2 — Final demonstration script (Windows)

**Revision:** 1.0 · 2026-11-03 · V2-010 · Owner: Rahil
**Platform:** Windows 11, MATLAB R2026b with UAV Toolbox and Navigation Toolbox. **macOS: NOT RUN** (AC-024).
**Time:** about 15 minutes, of which the nominal flight is about 2.5 minutes at 1×.

SIMULATION ONLY. Say this first, and leave the red banner visible throughout: every marker is a SUSPECTED anomaly with an uncalibrated score, the live scene contains no synthetic target, and nothing shown means any ground is safe.

## 0. Before the guide arrives

1. Close Chrome and other heavy programs; plug in the laptop. Refresh rate drops under load (V2-007 evidence).
2. From a clean checkout of `main`, in MATLAB:
   ```matlab
   cd <repo>; addpath('v2/evidence/V2-010'); rec = demo_record();   % opens the dashboard and records commit, versions and log
   ```
   During the run, `rec.shot("05_event_inspector")` saves a screenshot. At the end, `rec.finish()` saves the log. Without recording: `addpath('v2/matlab'); app = mgv2MissionControl;`
3. Check the window opens at tick 0 with the banner, the map and all six panels.

## 1. Script

| # | Action | Point out | Do not say |
|---|---|---|---|
| 1 | Read the banner and the scenario/seed line | Run id, seed 2002, "As launched" | "live drone", "real sensor" |
| 2 | Press **START SIMULATION** | PREFLIGHT, TAKEOFF, CLIMB; clock and AGL rise | |
| 3 | During SURVEY, expand RGB, then thermal, then LiDAR (each panel's **Expand** button fills the window; press it again to restore) | One scene seen by three simulated sensors at their own rates; thermal is in Kelvin | "thermal camera footage" |
| 4 | Watch the map | Flown route, footprint, coverage layers; "no overlay = unobserved" | "cleared", "safe" |
| 5 | Click an event in the list | Time, sensors, **uncalibrated** score, crops, estimated position; the evidence is checked against the run log | "a mine", "detected" |
| 6 | **PAUSE**, wait, **RESUME** | The clock stops and continues with no jump | |
| 7 | Let it land: phase COMPLETE | | |
| 8 | Press **EXPORT** | Folder name on the control bar; package of every pose, sample and event with SHA-256 checksums | |
| 9 | Press **REPLAY**, then **START** | Readout says "REPLAY (recorded, not simulated)"; at the end "N replayed events equal the N recorded events" | "re-simulated" |
| 10 | **RESET**, choose **Mission fault (timeout)**, START | The run ends FAILED with TIMEOUT in flight, shown in telemetry | |
| 11 | RESET, choose **Invalid rays**, START, look at LiDAR and RGB | Invalid rays and pixels are marked invalid, not drawn as ground | |
| 12 | Close with the science slide: V2 VALIDATION 0 of 4 targets; V1 TP 0, FP 26, TN 470, FN 4 | The negative result is the honest finding | "works", "accurate" |

## 2. Recording the run (only if Rahil personally watches it)

Rahil fills in `v2/evidence/V2-010/windows_demo_witness.md` himself:
- date, time, machine, MATLAB `version`, git SHA (`git rev-parse HEAD`), `git status --short` output;
- each step above: seen / not seen / problem, in his own words;
- the export folder name and the replay result line;
- his name as witness. Claude Code must not fill in or sign this file.

If nobody watches, the record says "No human witnessed the demonstration".

## 3. If something fails

Stop, take a screenshot, and write down exactly what happened. Do not rerun until it passes and report only the passing run.
