# Data Contracts and Coordinates

**Version:** draft v0.1; frozen after MG-003 acceptance. MATLAB structs or tables are acceptable when field names/units and validations stay consistent.

## Coordinate and time conventions
- Scenario internal position `x_east_m, y_north_m, z_up_m`; convert to NED only at toolbox boundary. Never mix without explicit transform.
- `t_s` is simulation seconds since mission start, monotonic.
- `lat_deg, lon_deg` may be **synthetic/reference-derived** only; DO NOT imply actual GPS fix. `gps_sigma_m` denotes assumed simulation error.
- Sensor timestamp alignment tolerance is configured, not assumed; invalid matches must be flagged.

## SimulationConfig
`schema_version, scenario_id, seed, terrain_id, soil_parameters, time_of_day, wind_mps, sensor_settings, vehicle_settings, grid_spacing_m, altitude_m, sampling_hz, model_version`.

## PoseSample
`t_s, x_east_m, y_north_m, z_up_m, roll_rad, pitch_rad, yaw_rad, lat_deg, lon_deg, gps_sigma_m, waypoint_id, mission_state`.

## SensorSample
`t_s, sensor_kind ('thermal'|'em'), sample_id, measurement_value, measurement_unit, noise_sigma, standoff_m, footprint_radius_m, validity, pose_sample_id`. The temperature unit must be K or °C explicitly. EM response may use simulated arbitrary calibrated units, clearly labelled.

## TargetTruth (restricted to scenario/evaluator)
`target_id, x_east_m, y_north_m, burial_depth_m, material_type, label ('target'|'clutter'), soil_class`. **Never consumed by classifier at inference**.

## DetectionEvent
`t_s, x_est_m, y_est_m, class_pred, score_0_1, uncertainty_m, thermal_sample_id, em_sample_id, method_name, threshold, status='SUSPECTED'`.

## ExperimentResult
`scenario_id, seed, algorithm, coverage_fraction, mission_time_s, distance_m, tp, fp, tn, fn, precision, recall, f1, false_alarm_rate, localization_error_m, model_version, matlab_release, toolbox_manifest`.

## Tests
- Validate required names, finite numbers, ranges, monotonic time, coordinate handedness.
- Missing sensor reading: explicit NaN/invalid status; no silent replacement with truth.
- If zero denominator in metrics, output NaN or documented convention.
- Reject train/test target leakage; stored seed and split IDs are mandatory.
