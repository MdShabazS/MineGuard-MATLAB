function G = buildSurveyGrid(navConfig, geometry)
%BUILDSURVEYGRID Fixed survey-cell grid and precomputed legal legs for the MG-013 PPO environment.
%   G = mineguard.rl.buildSurveyGrid(navConfig, geometry)
%   Uses ONLY public NavigationConfig + ScenarioGeometry (no truth). The cells match MG-005:
%     nx = max(1, ceil(width/spacing - 1e-9)), dx = width/nx (likewise in y), centres at
%     x_min + (i-0.5)*dx. Cell ID = (iy-1)*nx + ix, i.e. row-major from the SW cell, east first.
%   A cell is legal when its centre is outside every exclusion polygon. A leg i->j is legal
%   only if MG-005's public simulatePose accepts the straight leg (it applies the exact
%   segment/polygon test and rejects bounds or exclusion violations). The leg poses come from
%   that same simulatePose call, so coverage uses the identical sampled-pose rule.
%   Fields: N, nx, ny, dx, dy, bounds, centers (Nx2), legal (Nx1), reach (NxN logical),
%   leg_len (NxN), leg_dur (NxN), leg_xy{i,j} (samples after the start), leg_trel{i,j},
%   leg_cells{i,j} (cell IDs touched by every sample of the leg, start included), nav, geometry.
b = double(geometry.bounds_enu_m);
s = navConfig.grid_spacing_m;
nx = max(1, ceil((b(2) - b(1)) / s - 1e-9)); ny = max(1, ceil((b(4) - b(3)) / s - 1e-9));
dx = (b(2) - b(1)) / nx; dy = (b(4) - b(3)) / ny;
N = nx * ny;
[IX, IY] = meshgrid(1:nx, 1:ny);
ix = reshape(IX', [], 1); iy = reshape(IY', [], 1);           % row-major order
centers = [b(1) + (ix - 0.5) * dx, b(3) + (iy - 0.5) * dy];
legal = true(N, 1);
polys = geometry.exclusion_polygons_enu_m;
for k = 1:numel(polys)
    legal = legal & ~inpolygon(centers(:,1), centers(:,2), polys{k}(:,1), polys{k}(:,2));
end
G = struct('N', N, 'nx', nx, 'ny', ny, 'dx', dx, 'dy', dy, 'bounds', b, 'centers', centers, 'legal', legal, ...
    'reach', false(N), 'leg_len', NaN(N), 'leg_dur', NaN(N), 'leg_xy', {cell(N)}, 'leg_trel', {cell(N)}, ...
    'leg_cells', {cell(N)}, 'nav', navConfig, 'geometry', geometry, 'grid_version', "mg013-grid-1.0");
z = navConfig.altitude_m;
for i = find(legal)'
    for j = find(legal)'
        if i == j, continue; end
        try
            p = mineguard.navigation.simulatePose(navConfig, geometry, [centers(i,:) z; centers(j,:) z]);
        catch err
            if ismember(err.identifier, {'mineguard:RouteConflict','mineguard:InvalidNavigationInput'})
                continue
            end
            rethrow(err);
        end
        G.reach(i, j) = true;
        G.leg_len(i, j) = hypot(centers(j,1) - centers(i,1), centers(j,2) - centers(i,2));
        G.leg_dur(i, j) = p.t_s(end);
        G.leg_xy{i, j} = [p.x_east_m(2:end) p.y_north_m(2:end)];
        G.leg_trel{i, j} = p.t_s(2:end);
        G.leg_cells{i, j} = unique(mineguard.rl.cellOfPoint(G, p.x_east_m, p.y_north_m))';
    end
end
end
