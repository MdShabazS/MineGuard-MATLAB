function nav = validateNavConfig(nav)
%VALIDATENAVCONFIG Check a NavigationConfig (mg-contract/1.0). Uses a field WHITELIST:
%   any other field, including truth, counts, labels or soil, is rejected.
%   This enforces the ground-truth firewall at the planner's public input.
id = 'mineguard:InvalidNavigationConfig';
if ~isstruct(nav) || ~isscalar(nav)
    error(id, 'MineGuard navigation: navConfig must be a scalar NavigationConfig struct, not %s.', class(nav));
end
required = ["schema_version","scenario_id","seed","grid_spacing_m","dt_s","altitude_m","speed_mps"];
optional = ["virtual_origin_lat_deg","virtual_origin_lon_deg","gps_sigma_m"];
names = string(fieldnames(nav))';
missing = setdiff(required, names);
if ~isempty(missing)
    error(id, 'MineGuard navigation: navConfig is missing field(s): %s.', strjoin(missing, ', '));
end
extra = setdiff(names, [required optional]);
if ~isempty(extra)
    error(id, ['MineGuard navigation: navConfig has non-NavigationConfig field(s) %s. Navigation must not ' ...
        'receive truth, counts, labels or generator settings; derive navConfig with navigationConfigFromExperiment.'], ...
        strjoin(extra, ', '));
end
for f = ["schema_version","scenario_id"]
    v = nav.(f);
    if ~((ischar(v) && isrow(v)) || (isstring(v) && isscalar(v) && ~ismissing(v))) || strlength(string(v)) == 0
        error(id, 'MineGuard navigation: navConfig.%s must be nonempty text.', f);
    end
    nav.(f) = string(v);
end
if nav.schema_version ~= "mg-contract/1.0"
    error(id, 'MineGuard navigation: navConfig.schema_version must be "mg-contract/1.0".');
end
for f = intersect(["seed","grid_spacing_m","dt_s","altitude_m","speed_mps",optional], names, 'stable')
    v = nav.(f);
    if ~(isnumeric(v) && isreal(v) && isscalar(v)) || ~isfinite(v)
        error(id, 'MineGuard navigation: navConfig.%s must be a finite real scalar.', f);
    end
    nav.(f) = double(v);
end
if nav.seed < 0 || nav.seed ~= fix(nav.seed) || nav.seed > 2^32-1
    error(id, 'MineGuard navigation: navConfig.seed must be an integer in [0, 2^32-1].');
end
for f = ["grid_spacing_m","dt_s","speed_mps"]
    if nav.(f) <= 0
        error(id, 'MineGuard navigation: navConfig.%s must be positive (got %g).', f, nav.(f));
    end
end
if nav.altitude_m < 0
    error(id, 'MineGuard navigation: navConfig.altitude_m must be nonnegative.');
end
hasLat = isfield(nav, 'virtual_origin_lat_deg');
hasLon = isfield(nav, 'virtual_origin_lon_deg');
if hasLat ~= hasLon
    error(id, 'MineGuard navigation: give both virtual_origin_lat_deg and virtual_origin_lon_deg, or neither.');
end
if hasLat && (abs(nav.virtual_origin_lat_deg) >= 89 || abs(nav.virtual_origin_lon_deg) > 180)
    error(id, 'MineGuard navigation: virtual origin must satisfy |lat| < 89 and |lon| <= 180 degrees.');
end
if isfield(nav, 'gps_sigma_m')
    if nav.gps_sigma_m < 0
        error(id, 'MineGuard navigation: navConfig.gps_sigma_m must be nonnegative.');
    end
    if ~hasLat
        error(id, 'MineGuard navigation: gps_sigma_m requires a virtual origin.');
    end
end
end
