function [bounds, polys] = validateGeometry(geometry)
%VALIDATEGEOMETRY Check a ScenarioGeometry passed to navigation. It must have exactly
%   the 6 frozen mg-contract/1.0 fields, so a struct carrying truth is rejected.
id = 'mineguard:InvalidNavigationInput';
allowed = ["schema_version","scenario_id","bounds_enu_m","terrain_id","terrain_model","exclusion_polygons_enu_m"];
if ~isstruct(geometry) || ~isscalar(geometry)
    error(id, 'MineGuard navigation: geometry must be a scalar ScenarioGeometry struct, not %s.', class(geometry));
end
names = string(fieldnames(geometry))';
if ~isempty(setxor(names, allowed))
    error(id, 'MineGuard navigation: geometry fields must be exactly {%s}; got {%s}.', ...
        strjoin(allowed, ', '), strjoin(names, ', '));
end
% Nested firewall: terrain_model (the only free-form field) must not hide truth at any
% depth. No forbidden field names are allowed, and no tables (truth is a table).
leak = findNestedLeak(geometry.terrain_model, "terrain_model", mineguard.contract.truthFieldNames());
if strlength(leak) > 0
    error(id, 'MineGuard navigation: geometry.%s is not allowed; geometry must not carry hidden truth.', leak);
end
bounds = geometry.bounds_enu_m;
if ~(isnumeric(bounds) && isequal(size(bounds), [1 4])) || any(~isfinite(bounds)) || ...
        ~(bounds(1) < bounds(2) && bounds(3) < bounds(4))
    error(id, 'MineGuard navigation: geometry.bounds_enu_m must be finite [x_min x_max y_min y_max] with min < max.');
end
bounds = double(bounds);
polys = geometry.exclusion_polygons_enu_m;
if ~iscell(polys)
    error(id, 'MineGuard navigation: geometry.exclusion_polygons_enu_m must be a cell array.');
end
polys = reshape(polys, 1, []);
for k = 1:numel(polys)
    p = polys{k};
    if ~(isnumeric(p) && size(p,2) == 2 && size(p,1) >= 3) || any(~isfinite(p(:)))
        error(id, 'MineGuard navigation: exclusion polygon %d must be a finite Nx2 array, N >= 3.', k);
    end
end
end

function leak = findNestedLeak(v, path, forbidden)
%FINDNESTEDLEAK Return the path of the first forbidden field or table found in v, or "".
leak = "";
if istable(v)
    leak = path + " (table)";
elseif isstruct(v)
    f = string(fieldnames(v))';
    bad = intersect(f, forbidden);
    if ~isempty(bad)
        leak = path + "." + bad(1);
        return
    end
    for i = 1:numel(v)
        for name = f
            leak = findNestedLeak(v(i).(name), path + "." + name, forbidden);
            if strlength(leak) > 0, return; end
        end
    end
elseif iscell(v)
    for i = 1:numel(v)
        leak = findNestedLeak(v{i}, path + "{" + i + "}", forbidden);
        if strlength(leak) > 0, return; end
    end
end
end
