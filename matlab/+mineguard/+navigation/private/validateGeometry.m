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
