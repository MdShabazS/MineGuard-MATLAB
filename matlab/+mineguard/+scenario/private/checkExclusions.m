function checkExclusions(polys, bounds, name)
%CHECKEXCLUSIONS Validate a cell array of Nx2 ENU polygons (N>=3, finite, inside bounds).
if ~iscell(polys) || (~isempty(polys) && ~isvector(polys))
    invalidScenario('%s must be a cell array of Nx2 numeric polygons (an empty cell is allowed).', name);
end
for k = 1:numel(polys)
    p = polys{k};
    if ~(isnumeric(p) && isreal(p) && ismatrix(p) && size(p,2) == 2 && size(p,1) >= 3) || any(~isfinite(p(:)))
        invalidScenario('%s{%d} must be a finite Nx2 numeric array with N >= 3 vertices.', name, k);
    end
    if any(p(:,1) < bounds(1) | p(:,1) > bounds(2) | p(:,2) < bounds(3) | p(:,2) > bounds(4))
        invalidScenario('%s{%d} has vertices outside bounds [%g %g %g %g].', name, k, bounds(1), bounds(2), bounds(3), bounds(4));
    end
end
end
