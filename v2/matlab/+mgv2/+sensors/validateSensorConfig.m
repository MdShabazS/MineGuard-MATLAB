function cfg = validateSensorConfig(cfg)
%VALIDATESENSORCONFIG Exact-allowlist validation of a V2-005 SensorConfig (V2-004 §2.3).
%   cfg = mgv2.sensors.validateSensorConfig(cfg)    throws mgv2:InvalidSensorConfig or mgv2:TruthLeak
%   Top level: exactly the four controlled sensor ids. Per channel: exactly the common SensorConfig fields;
%   unknown fields (e.g. TargetTruth) are rejected so private scenario data cannot ride along.
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
            || size(d.intervals_s, 2) ~= 2
        error(id, '%s: dropout_model invalid.', sid);
    end
    if numel(s.valid_range_m) ~= 2 || s.valid_range_m(1) < 0 || s.valid_range_m(2) <= s.valid_range_m(1), error(id, '%s: valid_range_m invalid.', sid); end
end
end
