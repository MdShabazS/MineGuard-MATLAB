function cfg = defaultSensorConfig()
%DEFAULTSENSORCONFIG SensorConfig for the four V2-005 channels (V2-004 §2.3), config_origin ASSUMED.
%   cfg = mgv2.sensors.defaultSensorConfig()   struct with fields RGB_NADIR, THERMAL_LWIR, LIDAR_TERRAIN,
%   VIRTUAL_GNSS_INS. Common fields per channel: schema_version, sensor_id, enabled, rate_hz, mount
%   (from mgv2.scene.sensorRig, or [] for navigation), model_version, rng_stream_id, parameter_hash,
%   dropout_model (frame_probability, intervals_s [t0 t1; ...], ray_probability), valid_range_m, units,
%   config_origin, plus model parameters. All numbers are documented ASSUMPTIONS, not device specs.
%   valid_range_m = [min max] metres is the ONLY effective measurement range (LiDAR default [0.3 100] from
%   the V2-003 rig: 0.3 m blind zone, V2-004 100 m maximum). Overriding: edit fields, then pass the struct to
%   SensorSystem (or validateSensorConfig); parameter_hash is recomputed from the effective values.
rig = mgv2.scene.sensorRig();
% mount = sensor GEOMETRY only; the effective measurement range lives ONLY in valid_range_m (one source of truth)
byId = @(id) rmfield(rig([rig.sensor_id] == id), {'max_range_m','min_range_m'});
rng0 = @(id) [rig([rig.sensor_id] == id).min_range_m rig([rig.sensor_id] == id).max_range_m];
drop = @(p, q) struct('frame_probability', p, 'intervals_s', zeros(0, 2), 'ray_probability', q);
base = @(id, rate, mount, ver, rng, rngm, units) struct('schema_version', "mg-v2-sensors/1.0", 'sensor_id', id, 'enabled', true, ...
    'rate_hz', rate, 'mount', mount, 'model_version', ver, 'rng_stream_id', id + "/rng-v1", 'parameter_hash', "", ...
    'dropout_model', drop(rngm(1), rngm(2)), 'valid_range_m', rng, 'units', units, 'config_origin', "ASSUMED", 'params', struct());
cfg.RGB_NADIR = base("RGB_NADIR", 5, byId("RGB_NADIR"), "rgb-raster-lambert-v1", [0.05 200], [0 0], ...
    struct('image', "uint8 DN [0,255] sRGB-like proxy", 'geometry', "m, ENU"));
cfg.RGB_NADIR.params = struct('exposure_proxy', 1.0, 'ambient_fraction', 0.32, 'read_noise_dn', 1.5, 'shot_gain_dn', 0.04, ...
    'min_valid_fraction', 0.5);
cfg.THERMAL_LWIR = base("THERMAL_LWIR", 5, byId("THERMAL_LWIR"), "thermal-sb-proxy-v1", [0.05 200], [0 0], ...
    struct('temperature', "K (apparent)", 'geometry', "m, ENU"));
cfg.THERMAL_LWIR.params = struct('netd_K', 0.05, 'psf_sigma_px', 0.6, 'min_valid_fraction', 0.5, 'palette_id', "IRONBOW");
cfg.LIDAR_TERRAIN = base("LIDAR_TERRAIN", 2, byId("LIDAR_TERRAIN"), "lidar-raycast-v1", rng0("LIDAR_TERRAIN"), [0 0.01], ...
    struct('range', "m", 'points', "m (sensor FRD frame and ENU)", 'angles', "deg"));
cfg.LIDAR_TERRAIN.params = struct('range_bias_m', 0.01, 'range_sigma_m', 0.02, 'min_valid_fraction', 0.1);
cfg.VIRTUAL_GNSS_INS = base("VIRTUAL_GNSS_INS", 10, [], "nav-bias-drift-noise-v1", [0 inf], [0 0], ...
    struct('position', "m, ENU", 'velocity', "m/s, ENU", 'attitude', "quaternion wxyz FLU->ENU; deg", 'geodetic', "deg, deg, m (VIRTUAL)"));
cfg.VIRTUAL_GNSS_INS.params = struct('position_bias_sigma_m', [0.8 0.8 1.5], 'position_noise_sigma_m', [0.35 0.35 0.6], ...
    'drift_amplitude_m', 0.3, 'velocity_noise_sigma_mps', 0.05, 'attitude_noise_sigma_deg', [0.3 0.3 0.8], ...
    'yaw_bias_sigma_deg', 0.5);
cfg = mgv2.sensors.validateSensorConfig(cfg);    % fills each channel's parameter_hash (fingerprint)
end
