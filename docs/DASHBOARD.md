# Mission Control App — Acceptance Specification

**Technology:** MATLAB App Designer (or source-generated uifigure where supported). Interface is a virtual GCS, not a live drone GCS.

## Required screens
- **Mission**: scenario seed/selection, grid settings, sensor on/off toggles, start/pause/reset simulated run, clear status and elapsed simulation time.
- **Navigation**: 2D/3D mesh view with vehicle marker, waypoints, surveyed/unsurveyed cells and altitude; clearly label synthetic coordinates.
- **Sensor data**: thermal and EM sample curves, units, validity, thresholds and alignment status.
- **Detection map**: suspected anomalies only, score, estimated coordinates/uncertainty; distinct ground-truth overlays only in evaluation mode, hidden during normal inference.
- **Comparison**: grid vs PPO coverage/time/distance and thermal-only/EM-only/fused precision/recall/FPR, with number of runs and uncertainty.
- **Export**: CSV/MAT/PNG and human-readable summary with configuration, seed, version and limitations.

## UX and tests
UI must never freeze during playback (throttle redraws); missing signals show 'unavailable'. State progression IDLE > RUNNING > PAUSED > COMPLETE/FAILED. Test empty scenario, all-negative scenario, invalid input, missing toolboxes and export permissions.

## Scientific warning
Every primary view: 'SIMULATION — not validated for real mine detection or clearance'. Do not display 'safe zone', 'cleared area' or imply a real-world risk score.
