function [P, S] = validateObservations(poses, samples, tol)
%VALIDATEOBSERVATIONS Check PoseSample/SensorSample inputs for the detector (MG-008 Section 2).
%   Errors (mineguard:InvalidDetectorInput) are raised for schema or unit mismatches, duplicate
%   IDs, unmatched pose references, and sample times inconsistent with their pose (> tol + 1e-9 s).
%   The returned S has the additional columns pose_row (an index into P) and kind_is_thermal.
id = 'mineguard:InvalidDetectorInput';
if ~istable(poses) || ~all(ismember({'pose_sample_id','t_s','x_east_m','y_north_m'}, poses.Properties.VariableNames))
    error(id, 'MineGuard detection: poses must be a PoseSample table.');
end
P = poses;
P.pose_sample_id = string(P.pose_sample_id);
if numel(unique(P.pose_sample_id)) ~= height(P) || any(strlength(P.pose_sample_id) == 0)
    error(id, 'MineGuard detection: pose_sample_id values must be unique and nonempty.');
end
if any(~isfinite([P.t_s; P.x_east_m; P.y_north_m]))
    error(id, 'MineGuard detection: pose t_s and ENU positions must be finite.');
end
cols = ["sample_id","pose_sample_id","t_s","sensor_kind","temperature_K","response_norm", ...
    "noise_sigma","standoff_m","footprint_radius_m","valid","invalid_reason"];
if ~istable(samples) || ~isequal(string(samples.Properties.VariableNames), cols)
    error(id, 'MineGuard detection: samples must be a SensorSample table with exactly the 11 contract columns.');
end
S = samples;
if ~isstring(S.sample_id) || ~isstring(S.sensor_kind) || ~islogical(S.valid) || ~isstring(S.invalid_reason) || ...
        ~isa(S.temperature_K, 'double') || ~isa(S.response_norm, 'double') || ~isa(S.t_s, 'double')
    error(id, 'MineGuard detection: SensorSample column types do not match mg-contract/1.0.');
end
if numel(unique(S.sample_id)) ~= height(S)
    error(id, 'MineGuard detection: duplicate sample_id values.');
end
if ~all(ismember(S.sensor_kind, ["thermal","em"]))
    error(id, 'MineGuard detection: sensor_kind must be "thermal" or "em".');
end
[found, row] = ismember(string(S.pose_sample_id), P.pose_sample_id);
if ~all(found)
    error(id, 'MineGuard detection: sample %s references an unknown pose_sample_id.', S.sample_id(find(~found, 1)));
end
if any(abs(S.t_s - P.t_s(row)) > tol + 1e-9)
    error(id, 'MineGuard detection: sample %s t_s differs from its pose time by more than association_tolerance_s.', ...
        S.sample_id(find(abs(S.t_s - P.t_s(row)) > tol + 1e-9, 1)));
end
isT = S.sensor_kind == "thermal";
% Unit and channel checks: no cross-unit data and no NaN masquerading as valid.
if any(~isnan(S.response_norm(isT))) || any(~isnan(S.temperature_K(~isT)))
    error(id, 'MineGuard detection: channel/unit mismatch (thermal rows must have NaN response_norm; EM rows NaN temperature_K).');
end
vT = S.valid & isT; vE = S.valid & ~isT;
if any(~isfinite(S.temperature_K(vT))) || any(S.temperature_K(vT) <= 150 | S.temperature_K(vT) >= 400)
    error(id, ['MineGuard detection: valid thermal temperature_K must be finite kelvin within the sanity range ' ...
        '(150, 400) K; normalised EM values in the kelvin column are rejected.']);
end
if any(~isfinite(S.response_norm(vE)))
    error(id, 'MineGuard detection: valid EM samples need a finite response_norm.');
end
if any(~isnan(S.temperature_K(~S.valid & isT))) || any(~isnan(S.response_norm(~S.valid & ~isT)))
    error(id, 'MineGuard detection: invalid samples must carry NaN in their active channel.');
end
if any(strlength(S.invalid_reason(~S.valid)) == 0)
    error(id, 'MineGuard detection: invalid samples must state an invalid_reason.');
end
S.pose_row = row;
S.kind_is_thermal = isT;
end
