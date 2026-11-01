function validateSample(s)
%VALIDATESAMPLE Producer-to-consumer check of one public sample (mg-v2-sensors/1.0). Throws on violation.
%   mgv2.sensors.validateSample(s)
%   mgv2:InvalidSample - wrong schema, missing/unknown fields (exact allowlist: envelope + modality
%                        fields), bad types, valid/reason inconsistency, numeric invalid data not NaN
%   mgv2:TruthLeak     - a forbidden truth name anywhere in the record (mgv2.sensors.assertPublic)
c = mgv2.sensors.contract(); id = 'mgv2:InvalidSample';
if ~isstruct(s) || ~isscalar(s), error(id, 'Sample must be a scalar struct.'); end
mgv2.sensors.assertPublic(s, "sample");
if ~isfield(s, 'sensor_id') || ~ismember(s.sensor_id, c.sensor_ids), error(id, 'Unknown sensor_id.'); end
want = [c.envelope, c.modality_fields.(char(s.sensor_id))];
have = string(fieldnames(s))';
if ~isequal(have, want)
    extra = setdiff(have, want); miss = setdiff(want, have);
    error(id, 'Sample fields must be exactly the contract fields (unknown: %s; missing: %s).', strjoin(extra, ','), strjoin(miss, ','));
end
if s.schema_version ~= c.schema_version, error(id, 'schema_version must be %s.', c.schema_version); end
if ~isa(s.sample_seq, 'uint64') || ~isa(s.pose_id, 'uint64') || ~isa(s.tick_id, 'uint64'), error(id, 'sample_seq/pose_id/tick_id must be uint64.'); end
if ~(isscalar(s.t_s) && isfinite(s.t_s)), error(id, 't_s must be finite.'); end
if s.simulated ~= true, error(id, 'simulated must be true.'); end
if ~ismember(s.invalid_reason, c.invalid_reasons) || s.valid ~= (s.invalid_reason == "NONE"), error(id, 'valid/invalid_reason inconsistent.'); end
if ~ismember(s.calibration_kind, c.calibration_kinds), error(id, 'calibration_kind invalid.'); end
if size(s.footprint_enu_m, 2) ~= 2, error(id, 'footprint_enu_m must be N-by-2.'); end
switch s.sensor_id
    case "RGB_NADIR"
        if ~isa(s.image_rgb_uint8, 'uint8') || ~isequal(size(s.image_rgb_uint8), [s.image_height s.image_width 3]), error(id, 'RGB image shape/type.'); end
        if ~islogical(s.valid_pixel_mask) || ~isequal(size(s.valid_pixel_mask), [s.image_height s.image_width]), error(id, 'RGB mask.'); end
    case "THERMAL_LWIR"
        T = s.temperature_K; M = s.valid_pixel_mask;
        if ~isa(T, 'double') || ~isequal(size(T), [s.image_height s.image_width]), error(id, 'Thermal raster shape/type.'); end
        if any(~isnan(T(~M))) || any(~(isfinite(T(M)) & T(M) > 0)), error(id, 'Thermal: invalid pixels must be NaN, valid finite > 0 K.'); end
        if s.temperature_kind ~= "APPARENT", error(id, 'temperature_kind must be APPARENT.'); end
    case "LIDAR_TERRAIN"
        v = s.valid_ray_mask;
        if any(isfinite(s.ranges_m(~v))) || any(~isfinite(s.ranges_m(v))), error(id, 'LiDAR: invalid rays must be NaN, valid finite.'); end
        if any(s.ranges_m(v) > s.max_range_m + 5 * s.range_sigma_m + abs(s.range_bias_m)), error(id, 'LiDAR range beyond max.'); end
    case "VIRTUAL_GNSS_INS"
        if s.valid ~= all(isfinite(s.reported_position_enu_m)), error(id, 'Nav: validity must match finite measurements.'); end
end
end
