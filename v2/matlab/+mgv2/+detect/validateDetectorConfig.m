function cfg = validateDetectorConfig(cfg)
%VALIDATEDETECTORCONFIG Check a detector configuration and recompute its fingerprint (mgv2:InvalidDetectorConfig).
%   cfg = mgv2.detect.validateDetectorConfig(cfg)
%   Exact top-level field set; no truth names or objects (mgv2.sensors.assertPublic); numeric ranges;
%   score_mode in FUSED | RGB_ONLY | THERMAL_ONLY. parameter_hash = mgv2.sensors.configFingerprint(cfg)
%   (the hash field itself excluded), so an edited configuration can never keep a stale fingerprint.
id = 'mgv2:InvalidDetectorConfig';
want = ["schema_version","detector_id","detector_version","score_mode","rgb","thermal","size","lidar","association", ...
    "event","timing","evidence","landmark_exclusion_m","parameter_hash"];
if ~isstruct(cfg) || ~isscalar(cfg), error(id, 'Detector config must be a scalar struct.'); end
try
    mgv2.sensors.assertPublic(cfg, "detectorConfig");
catch err
    error(id, '%s', err.message);
end
if ~isequal(sort(string(fieldnames(cfg)))', sort(want)), error(id, 'Detector config fields must be exactly: %s.', strjoin(want, ', ')); end
if cfg.schema_version ~= mgv2.detect.contract().schema_version, error(id, 'schema_version must be %s.', mgv2.detect.contract().schema_version); end
if ~ismember(cfg.score_mode, ["FUSED","RGB_ONLY","THERMAL_ONLY"]), error(id, 'score_mode must be FUSED, RGB_ONLY or THERMAL_ONLY.'); end
pos = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0;
odd = @(x) pos(x) && mod(x, 2) == 1 && x >= 3;
ok = odd(cfg.rgb.window_px) && odd(cfg.thermal.window_px) && pos(cfg.rgb.z_threshold) && cfg.rgb.z_reference > cfg.rgb.z_threshold ...
    && pos(cfg.thermal.dT_threshold_K) && cfg.thermal.dT_reference_K > cfg.thermal.dT_threshold_K ...
    && pos(cfg.rgb.min_support_fraction) && pos(cfg.thermal.min_support_fraction) ...
    && pos(cfg.size.min_diameter_m) && cfg.size.max_diameter_m > cfg.size.min_diameter_m && pos(cfg.size.max_candidates_per_frame) ...
    && pos(cfg.lidar.cell_m) && pos(cfg.lidar.context_radius_m) && pos(cfg.lidar.protrusion_m) ...
    && pos(cfg.association.gate_m) && pos(cfg.association.merge_m) ...
    && cfg.association.pose_sigma_m >= 0 && cfg.event.min_detections >= 1 && islogical(cfg.event.emit_single_channel) ...
    && cfg.timing.tolerance_ticks >= 0 && pos(cfg.timing.timestamp_tolerance_s) && pos(cfg.evidence.max_per_modality) ...
    && pos(cfg.evidence.crop_half_px) && cfg.landmark_exclusion_m >= 0;
th = cfg.event.score_threshold;
ok = ok && isstruct(th) && isequal(sort(string(fieldnames(th)))', ["FUSED","RGB_ONLY","THERMAL_ONLY"]) ...
    && all(structfun(@(v) isnumeric(v) && isscalar(v) && v >= 0 && v <= 1, th));
if ~ok, error(id, 'Detector config has an invalid value.'); end
cfg.parameter_hash = mgv2.sensors.configFingerprint(cfg);
end
