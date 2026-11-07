function spec = checkSpec(spec)
%CHECKSPEC Validate a PlacementSpec; throws mgv21:InvalidPlacement with the reason.
id = 'mgv21:InvalidPlacement'; c = mgv21.contract(); L = c.limits;
want = ["schema_version","mode","seed","clutter_seed","count","visible_fraction","min_spacing_m","edge_margin_m","exclusion_zones","manual"];
if ~(isstruct(spec) && isscalar(spec)) || ~isempty(setxor(string(fieldnames(spec))', want))
    error(id, 'PlacementSpec fields must be exactly: %s.', strjoin(want, ", "));
end
if string(spec.schema_version) ~= c.schemas.placement, error(id, 'schema_version must be "%s".', c.schemas.placement); end
spec.mode = upper(string(spec.mode));
if ~(isscalar(spec.mode) && ismember(spec.mode, c.placement_modes)), error(id, 'mode must be NONE, MANUAL or RANDOM.'); end
for f = ["seed","clutter_seed"]
    v = spec.(f);
    if ~(isnumeric(v) && isscalar(v) && v >= 0 && v < 2^32 && v == round(v)), error(id, '%s must be an integer in [0, 2^32).', f); end
end
v = spec.count;
if ~(isnumeric(v) && isscalar(v) && v == round(v) && v >= L.target_count(1) && v <= L.target_count(2))
    error(id, 'count must be an integer in [%d, %d].', L.target_count(1), L.target_count(2));
end
inr = @(x, r) isnumeric(x) && isscalar(x) && isfinite(x) && x >= r(1) && x <= r(2);
if ~inr(spec.visible_fraction, [0 1]), error(id, 'visible_fraction must be in [0, 1].'); end
if ~inr(spec.min_spacing_m, L.min_spacing_m), error(id, 'min_spacing_m must be in [%g, %g].', L.min_spacing_m); end
if ~inr(spec.edge_margin_m, L.edge_margin_m), error(id, 'edge_margin_m must be in [%g, %g].', L.edge_margin_m); end
Z = spec.exclusion_zones;
if ~(isstruct(Z) && isempty(setxor(string(fieldnames(Z))', ["kind","center_enu_m","radius_m","polygon_enu_m"])))
    error(id, 'exclusion_zones must be a struct array with kind, center_enu_m, radius_m, polygon_enu_m.');
end
M = spec.manual;
if ~(istable(M) && isequal(string(M.Properties.VariableNames), ["x_east_m","y_north_m","surface_signature","burial_depth_m"]))
    error(id, 'manual must be a table with x_east_m, y_north_m, surface_signature, burial_depth_m.');
end
if ~all(isfinite([M.x_east_m; M.y_north_m; M.burial_depth_m])) || ~all(ismember(M.surface_signature, c.signatures))
    error(id, 'manual targets need finite positions and depths and a known surface_signature.');
end
end
