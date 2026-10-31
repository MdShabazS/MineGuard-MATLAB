function m = validateModel(m, dc)
%VALIDATEMODEL Frozen detector model artifact (TRAIN normalisers plus VALIDATION thresholds).
%   Top-level fields are whitelisted. No field at any depth may use a truth field name, and the
%   provenance must show normalisers fitted on "train" and thresholds selected on "validation"
%   (never "test"). Errors use mineguard:InvalidDetectorModel.
id = 'mineguard:InvalidDetectorModel';
if ~isstruct(m) || ~isscalar(m)
    error(id, 'MineGuard detection: model must be a scalar struct.');
end
required = ["version","thermal_background_K","thermal_scale_K","em_background_norm","em_scale_norm", ...
    "thermal_z_threshold","em_z_threshold","w_thermal","w_em","cluster_time_window_s","cluster_radius_m","provenance"];
optional = "weighted_fallback";
names = string(fieldnames(m))';
if ~isempty(setdiff(required, names))
    error(id, 'MineGuard detection: model is missing field(s): %s.', strjoin(setdiff(required, names), ', '));
end
if ~isempty(setdiff(names, [required optional]))
    error(id, 'MineGuard detection: model has unexpected field(s): %s.', strjoin(setdiff(names, [required optional]), ', '));
end
leak = nestedTruthField(m, "model");
if strlength(leak) > 0
    error(id, 'MineGuard detection: model contains a truth field (%s); held-out labels must never enter the detector.', leak);
end
num = @(f, ok) checkNum(m, f, ok, id);
num("thermal_background_K", @(v) v > 0);
num("thermal_scale_K", @(v) v > 0);
num("em_background_norm", @(v) true);
num("em_scale_norm", @(v) v > 0);
num("thermal_z_threshold", @(v) v > 0);
num("em_z_threshold", @(v) v > 0);
num("w_thermal", @(v) v >= 0);
num("w_em", @(v) v >= 0);
num("cluster_time_window_s", @(v) v >= 0);
num("cluster_radius_m", @(v) v >= 0);
p = m.provenance;
if ~isstruct(p) || ~isfield(p, 'normaliser_split') || ~isfield(p, 'threshold_split')
    error(id, 'MineGuard detection: model.provenance needs normaliser_split and threshold_split.');
end
if string(p.normaliser_split) ~= "train" || string(p.threshold_split) ~= "validation"
    error(id, 'MineGuard detection: normalisers must come from "train" and thresholds from "validation" (got %s / %s).', ...
        string(p.normaliser_split), string(p.threshold_split));
end
if dc.method_name == "weighted" && dc.missing_modality_rule == "single_valid"
    fb = [];
    if isfield(m, 'weighted_fallback'), fb = m.weighted_fallback; end
    if ~isstruct(fb) || ~isfield(fb, 'thermal_z_threshold') || ~isfield(fb, 'em_z_threshold') || ...
            ~all(isfinite([fb.thermal_z_threshold fb.em_z_threshold])) || any([fb.thermal_z_threshold fb.em_z_threshold] <= 0)
        error(id, 'MineGuard detection: weighted + single_valid requires a validation-frozen model.weighted_fallback with positive thermal_z_threshold and em_z_threshold.');
    end
end
end

function checkNum(m, f, ok, id)
v = m.(f);
if ~(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v)) || ~ok(double(v))
    error(id, 'MineGuard detection: model.%s is missing, non-finite or out of range.', f);
end
end

function leak = nestedTruthField(v, path)
leak = "";
if istable(v)
    leak = path + " (table)"; return
end
if ~isstruct(v), return; end
f = string(fieldnames(v))';
bad = intersect(f, mineguard.contract.truthFieldNames());
if ~isempty(bad)
    leak = path + "." + bad(1); return
end
for k = 1:numel(f)
    for i = 1:numel(v)
        leak = nestedTruthField(v(i).(f(k)), path + "." + f(k));
        if strlength(leak) > 0, return; end
    end
end
end
