function s = sampleLidar(sc, cfg, mission, pose, seq)
%SAMPLELIDAR LIDAR_TERRAIN scan from the shared scene at one immutable pose (V2-005, V2-004 §2.6).
%   s = mgv2.sensors.sampleLidar(sc, cfg, mission, pose, seq)
%   Ray layout (declared): sensor frame FRD (x forward, y right, z down); azimuth az_limits step az_res,
%   elevation el_limits step el_res, +elevation DOWN; direction [cos el cos az, cos el sin az, sin el].
%   Organized as [n_el x n_az]. Geometry: mgv2.sensors.castRays on the shared terrain + objects (exact first
%   hit, occlusion). Measurement: r_meas = r_true + b + N(0, sigma^2) (assumed b, sigma). Invalid rays are
%   NaN with a code: 1 SENSOR_DROPOUT (per-ray probability), 2 OUT_OF_RANGE (beyond max or inside the
%   0.3 m blind zone that guards against self-intersection), 3 NO_INTERSECTION. Implementation: base-MATLAB
%   ray caster (deterministic, no toolbox); cross-checked against UAV Toolbox uavLidarPointCloudGenerator.
prm = cfg.params; m = cfg.mount;
rs = mgv2.sensors.sensorStream(mission.seed, mission.scenario_id, cfg.sensor_id, double(seq) + 1);
az = m.az_limits_deg(1):m.az_res_deg:(m.az_limits_deg(2) - m.az_res_deg);
el = m.el_limits_deg(1):m.el_res_deg:m.el_limits_deg(2);
[AZ, EL] = meshgrid(az, el); n = numel(AZ);
ds = [cosd(EL(:)) .* cosd(AZ(:)), cosd(EL(:)) .* sind(AZ(:)), sind(EL(:))];
reason = "NONE"; T_ws = nan(4); codes = zeros(n, 1, 'uint8'); r = nan(n, 1);
p = pose.position_enu_m; q = pose.orientation_quat;
if ~(all(isfinite(p)) && all(isfinite(q)) && abs(norm(q) - 1) < 1e-6)
    reason = "INVALID_POSE"; codes(:) = 0;
else
    T_ws = mgv2.scene.sensorPose(pose, m);
    dm = cfg.dropout_model; u = rand(rs);
    if any(pose.t_s >= dm.intervals_s(:,1) & pose.t_s <= dm.intervals_s(:,2)) || u < dm.frame_probability
        reason = "SENSOR_DROPOUT"; codes(:) = 1;
    else
        D = ds * T_ws(1:3,1:3)'; O = repmat(T_ws(1:3,4)', n, 1);
        hit = mgv2.sensors.castRays(sc, O, D, m.max_range_m);
        noise = prm.range_bias_m + prm.range_sigma_m * randn(rs, n, 1);
        drop = rand(rs, n, 1) < dm.ray_probability;
        r = hit.t + noise;
        codes(hit.reason == "NO_INTERSECTION") = 3;
        codes(hit.reason == "OUT_OF_RANGE" | (isfinite(hit.t) & hit.t < m.min_range_m)) = 2;
        codes(drop & codes == 0) = 1;
        r(codes ~= 0) = NaN;
    end
end
valid = codes == 0 & isfinite(r);
Ps = r .* ds; Ps(~valid, :) = NaN;
Pw = nan(n, 3);
if all(isfinite(T_ws), 'all'), Pw(valid, :) = Ps(valid, :) * T_ws(1:3,1:3)' + T_ws(1:3,4)'; end
fp = zeros(0, 2); agl = NaN; th = NaN;
if nnz(valid) >= 3
    xy = Pw(valid, 1:2);
    try
        kh = convhull(xy(:,1), xy(:,2)); fp = xy(kh, :);
    catch
        fp = zeros(0, 2);   % collinear returns: no area footprint
    end
    nad = valid & EL(:) >= 85;
    if any(nad), th = median(Pw(nad, 3)); agl = T_ws(3,4) - th; end
end
if reason == "NONE" && mean(valid) < prm.min_valid_fraction      % dominant per-ray cause names the frame
    cnt = accumarray(double(codes(codes > 0)), 1, [3 1]); [~, dom] = max(cnt);
    book = ["SENSOR_DROPOUT","OUT_OF_RANGE","NO_INTERSECTION"]; reason = book(dom);
end
qual = struct('valid_ray_fraction', mean(valid), 'dropout_rays', nnz(codes == 1), 'out_of_range_rays', nnz(codes == 2), ...
    'no_intersection_rays', nnz(codes == 3), 'agl_from_returns_available', isfinite(agl), 'stats_available', true);
s = mgv2.sensors.makeEnvelope(mission, cfg, pose, seq, reason == "NONE", reason, "sensor", fp, qual);
s.points_sensor_m = Ps; s.points_enu_m = Pw; s.ranges_m = r; s.ray_unit_vectors_sensor = ds; s.valid_ray_mask = valid;
s.ray_invalid_code = codes; s.ray_invalid_codebook = ["NONE","SENSOR_DROPOUT","OUT_OF_RANGE","NO_INTERSECTION"];
s.return_count = nnz(valid); s.range_bias_m = prm.range_bias_m; s.range_sigma_m = prm.range_sigma_m;
s.max_range_m = m.max_range_m; s.min_range_m = m.min_range_m; s.scan_azimuth_deg = AZ; s.scan_elevation_deg = EL;
s.organized_shape = size(AZ); s.T_body_sensor = m.T_body_sensor; s.T_world_sensor = T_ws;
s.terrain_height_m = th; s.altitude_agl_m = agl; s.implementation = "BASE_MATLAB_RAYCAST_V1";
end
