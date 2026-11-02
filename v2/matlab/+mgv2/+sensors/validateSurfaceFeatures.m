function F = validateSurfaceFeatures(F)
%VALIDATESURFACEFEATURES Check the PRIVATE forward-model surface-feature list (V2-006 hook). Throws on violation.
%   F = mgv2.sensors.validateSurfaceFeatures(F)      F: struct array (0x1 allowed) with EXACTLY the fields
%     center_enu_m [x y] (m), radius_m (0.05..3), edge_m (soft edge width, 0.01..1), albedo_rgb [r g b] in [0,1],
%     albedo_mix in [0,1] (blend of terrain albedo toward albedo_rgb), delta_T_K (surface temperature change, K,
%     |dT| <= 30), emissivity (NaN = unchanged, else 0.05..1).
%   These are FLAT surface appearance perturbations (disturbed soil, wet patch, scrap, paint) applied only inside
%   the RGB/thermal forward models; they never change geometry, so LiDAR cannot see them. The list carries no
%   identity, class or label field: whether a feature relates to any hidden scenario truth is known only to the
%   private scenario builder and the independent evaluator (V2-004 §3). Empty list = V2-005 behaviour, bit-identical.
id = 'mgv2:InvalidSensorConfig';
want = ["center_enu_m","radius_m","edge_m","albedo_rgb","albedo_mix","delta_T_K","emissivity"];
if isempty(F), F = repmat(cell2struct(cell(numel(want), 1), cellstr(want), 1), 0, 1); return; end
if ~isstruct(F), error(id, 'SurfaceFeatures must be a struct array.'); end
mgv2.sensors.assertPublic(F, "SurfaceFeatures");
if ~isequal(sort(string(fieldnames(F)))', sort(want)), error(id, 'SurfaceFeatures fields must be exactly: %s.', strjoin(want, ', ')); end
F = orderfields(F(:), cellstr(want));
for k = 1:numel(F)
    f = F(k);
    ok = isnumeric(f.center_enu_m) && numel(f.center_enu_m) == 2 && all(isfinite(f.center_enu_m)) ...
        && isscalar(f.radius_m) && f.radius_m >= 0.05 && f.radius_m <= 3 ...
        && isscalar(f.edge_m) && f.edge_m >= 0.01 && f.edge_m <= 1 ...
        && numel(f.albedo_rgb) == 3 && all(f.albedo_rgb >= 0 & f.albedo_rgb <= 1) ...
        && isscalar(f.albedo_mix) && f.albedo_mix >= 0 && f.albedo_mix <= 1 ...
        && isscalar(f.delta_T_K) && isfinite(f.delta_T_K) && abs(f.delta_T_K) <= 30 ...
        && isscalar(f.emissivity) && (isnan(f.emissivity) || (f.emissivity >= 0.05 && f.emissivity <= 1));
    if ~ok, error(id, 'SurfaceFeatures(%d) has an invalid value.', k); end
    F(k).center_enu_m = double(f.center_enu_m(:)'); F(k).albedo_rgb = double(f.albedo_rgb(:)');
end
end
