function dc = validateDetectorConfig(dc)
%VALIDATEDETECTORCONFIG DetectorConfig whitelist (mg-contract/1.0 plus the approved MG-009 clarification).
%   Exactly these fields are allowed: schema_version, scenario_id, association_tolerance_s,
%   threshold, method_name, missing_modality_rule. Any other field, such as truth, counts,
%   generator settings or an ExperimentConfig, is rejected with mineguard:InvalidDetectorConfig.
%
%   missing_modality_rule (the field name for the "explicit missing-modality rule" in MG-003,
%   approved by Shabaz):
%     "abstain"      - a method decides only when every modality it uses is valid
%     "single_valid" - OR uses whichever modality is present; weighted uses the separately
%                      frozen single-channel fallback in the model (required); AND still abstains
%     "require_both" - every method, single-channel ones included, decides only when BOTH
%                      modalities are valid (a strictly paired population)
id = 'mineguard:InvalidDetectorConfig';
allowed = ["schema_version","scenario_id","association_tolerance_s","threshold","method_name","missing_modality_rule"];
if ~isstruct(dc) || ~isscalar(dc)
    error(id, 'MineGuard detection: detectorConfig must be a scalar DetectorConfig struct.');
end
names = string(fieldnames(dc))';
missing = setdiff(allowed, names);
if ~isempty(missing)
    error(id, 'MineGuard detection: detectorConfig is missing field(s): %s.', strjoin(missing, ', '));
end
extra = setdiff(names, allowed);
if ~isempty(extra)
    error(id, ['MineGuard detection: detectorConfig has non-contract field(s) %s. The detector must not ' ...
        'receive truth, counts, generator or scenario settings.'], strjoin(extra, ', '));
end
for f = ["schema_version","scenario_id","method_name","missing_modality_rule"]
    v = dc.(f);
    if ~((ischar(v) && isrow(v)) || (isstring(v) && isscalar(v) && ~ismissing(v))) || strlength(string(v)) == 0
        error(id, 'MineGuard detection: detectorConfig.%s must be nonempty text.', f);
    end
    dc.(f) = string(v);
end
if dc.schema_version ~= "mg-contract/1.0"
    error(id, 'MineGuard detection: detectorConfig.schema_version must be "mg-contract/1.0".');
end
if ~ismember(dc.method_name, ["thermal_only","em_only","or","and","weighted"])
    error(id, 'MineGuard detection: method_name "%s" is not one of thermal_only, em_only, or, and, weighted.', dc.method_name);
end
if ~ismember(dc.missing_modality_rule, ["abstain","single_valid","require_both"])
    error(id, 'MineGuard detection: missing_modality_rule "%s" must be abstain, single_valid or require_both.', dc.missing_modality_rule);
end
for f = ["association_tolerance_s","threshold"]
    v = dc.(f);
    if ~(isnumeric(v) && isreal(v) && isscalar(v)) || ~isfinite(v)
        error(id, 'MineGuard detection: detectorConfig.%s must be a finite real scalar.', f);
    end
    dc.(f) = double(v);
end
if dc.association_tolerance_s < 0
    error(id, 'MineGuard detection: association_tolerance_s must be nonnegative.');
end
end
