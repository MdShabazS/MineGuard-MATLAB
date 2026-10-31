function G = gridSpec(grid)
%GRIDSPEC Evaluation cell grid. It matches the MG-005 survey grid: nx = ceil(width/spacing),
%   even subdivision. Cells are half-open [x0+(i-1)dx, x0+i*dx), except the last cell, which is
%   closed at x_max (and likewise in y). A cell is legal when its centre is outside every
%   exclusion polygon.
id = 'mineguard:InvalidEvaluationInput';
if ~isstruct(grid) || ~all(isfield(grid, {'bounds_enu_m','grid_spacing_m','exclusion_polygons_enu_m'}))
    error(id, 'MineGuard evaluation: grid needs bounds_enu_m, grid_spacing_m and exclusion_polygons_enu_m.');
end
b = double(grid.bounds_enu_m);
s = double(grid.grid_spacing_m);
if ~(numel(b) == 4 && all(isfinite(b)) && b(1) < b(2) && b(3) < b(4) && isscalar(s) && s > 0)
    error(id, 'MineGuard evaluation: invalid grid bounds or spacing.');
end
nx = max(1, ceil((b(2) - b(1)) / s - 1e-9));
ny = max(1, ceil((b(4) - b(3)) / s - 1e-9));
dx = (b(2) - b(1)) / nx; dy = (b(4) - b(3)) / ny;
[X, Y] = meshgrid(b(1) + ((1:nx) - 0.5) * dx, b(3) + ((1:ny) - 0.5) * dy);
legal = true(ny, nx);
polys = grid.exclusion_polygons_enu_m;
for k = 1:numel(polys)
    legal = legal & ~inpolygon(X, Y, polys{k}(:,1), polys{k}(:,2));
end
G = struct('bounds', b, 'nx', nx, 'ny', ny, 'dx', dx, 'dy', dy, 'legal', legal);
end
