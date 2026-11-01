function cfg = validateSensorConfig(cfg)
%VALIDATESENSORCONFIG Exact-allowlist validation of a V2-005 SensorConfig (V2-004 §2.3).
%   cfg = mgv2.sensors.validateSensorConfig(cfg)    throws mgv2:InvalidSensorConfig or mgv2:TruthLeak
%   Top level: exactly the four controlled sensor ids. Per channel: exactly the common SensorConfig fields;
%   unknown fields (e.g. TargetTruth) are rejected so private scenario data cannot ride along.
%   Range: valid_range_m = [min max] is the single effective measurement range; a mount carrying its own
%   range fields is rejected (no second, contradictory source).
%   Returns cfg with every channel's parameter_hash RECOMPUTED as mgv2.sensors.configFingerprint of that
%   channel's effective fields, so the accepted hash always matches the parameters actually used (an edited
%   or stale supplied hash is replaced) and changing one channel never changes another channel's hash.
id = 'mgv2:InvalidSensorConfig'; c = mgv2.sensors.contract();
mgv2.sensors.assertPublic(cfg, "sensorConfig");
if ~isstruct(cfg) || ~isempty(setxor(string(fieldnames(cfg))', c.sensor_ids))
    error(id, 'SensorConfig must have exactly the fields %s.', strjoin(c.sensor_ids, ', '));
end
need = ["schema_version","sensor_id","enabled","rate_hz","mount","model_version","rng_stream_id","parameter_hash", ...
    "dropout_model","valid_range_m","units","config_origin","params"];
for sid = c.sensor_ids
    s = cfg.(sid);
    if ~isempty(setxor(string(fieldnames(s))', need)), error(id, '%s: fields must be exactly %s.', sid, strjoin(need, ', ')); end
    if s.schema_version ~= c.schema_version || s.sensor_id ~= sid, error(id, '%s: schema/sensor_id mismatch.', sid); end
    if ~(isscalar(s.rate_hz) && isfinite(s.rate_hz) && s.rate_hz > 0), error(id, '%s: rate_hz must be positive.', sid); end
    if ~ismember(s.config_origin, ["ASSUMED","CHARACTERIZED","MEASURED"]), error(id, '%s: config_origin invalid.', sid); end
    d = s.dropout_model;
    if ~isstruct(d) || ~isempty(setxor(string(fieldnames(d))', ["frame_probability","intervals_s","ray_probability"])) ...
            || ~(d.frame_probability >= 0 && d.frame_probability <= 1 && d.ray_probability >= 0 && d.ray_probability <= 1) ...
            || size(d.intervals_s, 2) ~= 2 || ~all(isfinite(d.intervals_s), 'all') || any(d.intervals_s(:,2) < d.intervals_s(:,1))
        error(id, '%s: dropout_model invalid.', sid);
    end
    v = s.valid_range_m;
    if ~(isnumeric(v) && numel(v) == 2 && isfinite(v(1)) && ~isnan(v(2)) && v(1) >= 0 && v(2) > v(1)), error(id, '%s: valid_range_m must be [min max] with finite 0 <= min < max (max may be Inf only where no range applies).', sid); end
    if sid ~= "VIRTUAL_GNSS_INS" && ~isfinite(v(2)), error(id, '%s: valid_range_m(2) must be finite.', sid); end
    if isstruct(s.mount) && any(isfield(s.mount, {'max_range_m','min_range_m'}))
        error(id, '%s: the mount must not carry range fields; set the effective range in valid_range_m only.', sid);
    end
    if sid == "LIDAR_TERRAIN" && v(1) <= 0, error(id, 'LIDAR_TERRAIN: valid_range_m(1) must be > 0 (blind zone guards self-intersection).'); end
    if ~isstruct(s.params), error(id, '%s: params must be a struct.', sid); end
    cfg.(sid).parameter_hash = mgv2.sensors.configFingerprint(s);
end
end
