function validateSample(s)
%VALIDATESAMPLE Producer-to-consumer check of one public sample (mg-v2-sensors/1.0). Throws on violation.
%   mgv2.sensors.validateSample(s)
%   mgv2:InvalidSample - wrong schema, missing/unknown fields (exact allowlist: envelope + modality
%                        fields), bad types, valid/reason inconsistency, numeric invalid data not NaN,
%                        quality outside its exact per-sensor schema or disagreeing with the sample's own data
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
checkQuality(s, c, id);
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

function checkQuality(s, c, id)
%CHECKQUALITY Exact quality schema. Any field outside it is refused whatever its name. Values must be real doubles,
%   logicals or the listed string. A camera's stats are required with stats_available, and may be NaN or empty only
%   when no pixel is valid, because then there is nothing to compute them from. No value is repaired here.
q = s.quality; sid = s.sensor_id;
if ~isstruct(q) || ~isscalar(q), error(id, 'quality must be a scalar struct.'); end
spec = c.quality_fields.(char(sid)); have = string(fieldnames(q))';
if ~islogical(requireField(q, 'stats_available', id)) || ~isscalar(q.stats_available), error(id, 'quality.stats_available must be a logical scalar.'); end
want = spec.always; if q.stats_available, want = [want, spec.stats]; end
if ~isempty(setxor(have, want))
    error(id, 'quality fields must be exactly the contract fields for %s (unknown: %s; missing: %s).', sid, strjoin(setdiff(have, want), ','), strjoin(setdiff(want, have), ','));
end
switch sid
    case {"RGB_NADIR","THERMAL_LWIR"}
        checkFraction(q.valid_pixel_fraction, 'valid_pixel_fraction', id); checkFraction(q.object_pixel_fraction, 'object_pixel_fraction', id);
        if abs(q.valid_pixel_fraction - mean(s.valid_pixel_mask(:))) > 1e-12, error(id, 'quality.valid_pixel_fraction disagrees with valid_pixel_mask.'); end
        if s.valid && ~q.stats_available, error(id, 'A valid camera sample must have stats.'); end
        if q.stats_available, checkCameraStats(q, sid, id); end
    case "LIDAR_TERRAIN"
        checkFraction(q.valid_ray_fraction, 'valid_ray_fraction', id);
        if abs(q.valid_ray_fraction - mean(s.valid_ray_mask(:))) > 1e-12, error(id, 'quality.valid_ray_fraction disagrees with valid_ray_mask.'); end
        names = ["dropout_rays","out_of_range_rays","no_intersection_rays"];
        for k = 1:3
            n = q.(names(k));
            if ~(isa(n, 'double') && isscalar(n) && isreal(n) && n == nnz(s.ray_invalid_code == k)), error(id, 'quality.%s disagrees with ray_invalid_code.', names(k)); end
        end
        a = q.agl_from_returns_available;
        if ~(islogical(a) && isscalar(a) && a == isfinite(s.altitude_agl_m)), error(id, 'quality.agl_from_returns_available disagrees with altitude_agl_m.'); end
    case "VIRTUAL_GNSS_INS"
        for f = ["horizontal_sigma_m","vertical_sigma_m"]
            v = q.(f);
            if ~(isa(v, 'double') && isscalar(v) && isreal(v) && isfinite(v) && v >= 0), error(id, 'quality.%s must be a finite non-negative double in metres.', f); end
        end
        if ~(isstring(q.sigma_kind) && isscalar(q.sigma_kind) && q.sigma_kind == "MODEL_ASSUMPTION"), error(id, 'quality.sigma_kind must be "MODEL_ASSUMPTION".'); end
        if q.stats_available ~= s.valid, error(id, 'quality.stats_available must match valid for navigation.'); end
end
end

function v = requireField(q, name, id)
if ~isfield(q, name), error(id, 'quality.%s is missing.', name); end
v = q.(name);
end

function checkFraction(v, name, id)
if ~(isa(v, 'double') && isscalar(v) && isreal(v) && isfinite(v) && v >= 0 && v <= 1), error(id, 'quality.%s must be a finite double in [0, 1].', name); end
end

function checkCameraStats(q, sid, id)
noPixels = q.valid_pixel_fraction == 0;
for f = statsOf(sid)
    v = q.(f);
    if ~(isa(v, 'double') && isreal(v)), error(id, 'quality.%s must be a real double.', f); end
    if noPixels && (isempty(v) || (isscalar(v) && isnan(v))), continue; end
    if ~(isscalar(v) && isfinite(v)), error(id, 'quality.%s must be a finite scalar when pixels are valid.', f); end
    if noPixels, error(id, 'quality.%s must be unavailable when no pixel is valid.', f); end
end
if noPixels, return; end
if sid == "RGB_NADIR"
    checkFraction(q.saturated_fraction, 'saturated_fraction', id);
    if q.mean_dn < 0 || q.mean_dn > 255, error(id, 'quality.mean_dn must be in [0, 255] DN.'); end
elseif ~(q.min_K > 0 && q.min_K <= q.mean_K && q.mean_K <= q.max_K)
    error(id, 'quality temperatures must satisfy 0 < min_K <= mean_K <= max_K.');
end
end

function f = statsOf(sid)
f = mgv2.sensors.contract().quality_fields.(char(sid)).stats;
end
