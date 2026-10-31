function summary = computeCoverage(navConfig, geometry, poses)
%COMPUTECOVERAGE Navigation metrics from the pose log alone (no truth) (MG-005).
%   summary = mineguard.navigation.computeCoverage(navConfig, geometry, poses)
%   coverage_fraction = visited_valid_cells / total_valid_cells (docs/ACCEPTANCE_MATRIX.md).
%   Valid cells are survey cells whose centre is outside every exclusion polygon. A cell
%   counts as visited when at least one pose sample falls inside it. The pose spacing is
%   speed_mps*dt_s, so cells can be missed when that exceeds the cell pitch; this
%   function reports such gaps honestly.
navConfig = validateNavConfig(navConfig);
[bounds, polys] = validateGeometry(geometry);
if ~istable(poses) || ~all(ismember({'t_s','x_east_m','y_north_m','mission_state'}, poses.Properties.VariableNames))
    error('mineguard:InvalidNavigationInput', 'MineGuard navigation: poses must be a PoseSample table.');
end
[xc, yc, dx, dy] = gridCells(bounds, navConfig.grid_spacing_m);
[X, Y] = meshgrid(xc, yc);
valid = ~insidePolys(X, Y, polys);
ix = min(numel(xc), max(1, floor((poses.x_east_m - bounds(1)) / dx) + 1));
iy = min(numel(yc), max(1, floor((poses.y_north_m - bounds(3)) / dy) + 1));
visited = false(size(valid));
visited(sub2ind(size(visited), iy, ix)) = true;
nValid = nnz(valid);
summary = struct( ...
    'coverage_fraction', nnz(visited & valid) / nValid, ...
    'visited_valid_cells', nnz(visited & valid), ...
    'total_valid_cells', nValid, ...
    'cell_pitch_m', [dx dy], ...
    'mission_time_s', poses.t_s(end) - poses.t_s(1), ...
    'distance_m', sum(sqrt(diff(poses.x_east_m).^2 + diff(poses.y_north_m).^2 + diff(poses.z_up_m).^2)), ...
    'completed', poses.mission_state(end) == "COMPLETE", ...
    'n_pose_samples', height(poses));
end
