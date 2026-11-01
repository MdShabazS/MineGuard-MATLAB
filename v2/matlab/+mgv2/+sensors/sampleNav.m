function s = sampleNav(cfg, mission, pose, seq, origin)
%SAMPLENAV VIRTUAL_GNSS_INS measurement at one immutable pose (V2-005, V2-004 §2.7). SIMULATED.
%   s = mgv2.sensors.sampleNav(cfg, mission, pose, seq, origin)     origin = [lat0 lon0 alt0] VIRTUAL
%   reported = reference (engine PoseSample) + static bias + slow drift(t) + white noise:
%     bias  ~ N(0, position_bias_sigma_m) and yaw bias ~ N(0, yaw_bias_sigma_deg), drawn ONCE per run
%           from the sensor stream's reserved substream 2^30;
%     drift = sum_k a_k sin(2 pi f_k t + phi_k), 3 seeded terms per axis (f 1/300..1/60 Hz): a smooth,
%           order-independent stand-in for INS/GNSS wander;
%     noise = per-sample white noise from substream seq+1 (position, velocity, roll/pitch/yaw).
%   Virtual geodetic coordinates use a local tangent-plane approximation on the WGS84 ellipsoid
%   (mgv2.sensors.enuToVirtualLla); they are NOT real GNSS fixes. The reference pose is never copied
%   into the sample: it is referenced by pose_id only.
prm = cfg.params;
st = mgv2.sensors.sensorStream(mission.seed, mission.scenario_id, cfg.sensor_id, 2^30);
bias = prm.position_bias_sigma_m .* randn(st, 1, 3); yawBias = prm.yaw_bias_sigma_deg * randn(st);
fq = 1/300 + (1/60 - 1/300) * rand(st, 3, 3); ph = 2 * pi * rand(st, 3, 3); amp = prm.drift_amplitude_m * (0.5 + rand(st, 3, 3));
rs = mgv2.sensors.sensorStream(mission.seed, mission.scenario_id, cfg.sensor_id, double(seq) + 1);
reason = "NONE"; p = pose.position_enu_m; q = pose.orientation_quat;
dm = cfg.dropout_model; u = rand(rs);
if ~(all(isfinite(p)) && all(isfinite(q)) && abs(norm(q) - 1) < 1e-6)
    reason = "INVALID_POSE";
elseif any(pose.t_s >= dm.intervals_s(:,1) & pose.t_s <= dm.intervals_s(:,2)) || u < dm.frame_probability
    reason = "SENSOR_DROPOUT";
end
pos = nan(1, 3); vel = nan(1, 3); qr = nan(1, 4); hd = NaN; lla = nan(1, 3);
if reason == "NONE"
    drift = sum(amp .* sin(2 * pi * fq * pose.t_s + ph), 1);
    pos = p + bias + drift + prm.position_noise_sigma_m .* randn(rs, 1, 3);
    vel = pose.velocity_enu_mps + prm.velocity_noise_sigma_mps * randn(rs, 1, 3);
    [y, pt, rl] = mgv2.frames.yawPitchRollFromQuat(q);
    a = deg2rad(prm.attitude_noise_sigma_deg) .* randn(rs, 1, 3);
    y = y + deg2rad(yawBias) + a(3);
    qr = mgv2.frames.quatFromYawPitchRoll(y, pt + a(2), rl + a(1));
    hd = mgv2.frames.headingDegFromYaw(y);
    lla = mgv2.sensors.enuToVirtualLla(pos, origin);
end
qual = struct('horizontal_sigma_m', hypot(prm.position_noise_sigma_m(1), prm.position_bias_sigma_m(1)), ...
    'vertical_sigma_m', hypot(prm.position_noise_sigma_m(3), prm.position_bias_sigma_m(3)), ...
    'sigma_kind', "MODEL_ASSUMPTION", 'stats_available', reason == "NONE");
s = mgv2.sensors.makeEnvelope(mission, cfg, pose, seq, reason == "NONE", reason, "ENU", zeros(0, 2), qual);
s.measurement_kind = "REPORTED_VIRTUAL"; s.reported_position_enu_m = pos; s.reported_velocity_enu_mps = vel;
s.reported_orientation_quat = qr; s.reported_heading_deg = hd;
s.virtual_lat_deg = lla(1); s.virtual_lon_deg = lla(2); s.virtual_alt_m = lla(3); s.virtual_origin_lla = origin;
s.position_sigma_m = prm.position_noise_sigma_m; s.velocity_sigma_mps = prm.velocity_noise_sigma_mps;
s.attitude_sigma_deg = prm.attitude_noise_sigma_deg; s.fix_type = "VIRTUAL_3D";
if reason ~= "NONE", s.fix_type = "NO_FIX"; end
end
