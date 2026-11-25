function F = findFeatures(A, S, opts)
%FINDFEATURES Connected relief anomalies with size, depth and a type guess (V22-T12).
%   F = mgv22.relief.findFeatures(A, S)
%   F = mgv22.relief.findFeatures(A, S, DepthM=0.3, MinAreaM2=0.5, CraterMinWidthM=3, CraterMaxWidthM=15, LinearAspect=4)
%   Regions are 4-neighbour connected components (graph + conncomp) of D <= -DepthM (pits) and, separately,
%   D >= DepthM (raised). Defaults from published sizes (HALO Angola: foxholes 0.6-0.8 m deep, ~2.5 m wide;
%   craters ~5.9 m wide, 0.65 m deep; trenches long and linear): DepthM = half the shallowest foxhole depth.
%   Per region: area_m2 (cells*cell_m^2, regions below MinAreaM2 dropped), centroid, depth_m = max |D|, and
%   PCA axes length_m = 4*sqrt(largest eigenvalue) + cell_m, width_m = 4*sqrt(smallest) + cell_m.
%   type: raised -> "berm"; length/width >= LinearAspect -> "trench"; width > CraterMaxWidthM -> "large depression"
%   (wider than any crater in the sources; usually natural relief); width >= CraterMinWidthM -> "crater";
%   else "pit (foxhole-size)". Note a DSM also shows bushes and rocks, which appear as berms. F: id ("RF-01".. ), type, x_east_m, y_north_m, area_m2, depth_m, length_m,
%   width_m, label. Empty table with these columns when none. INDIRECT EVIDENCE from simulation only.
arguments
    A (1,1) struct
    S (1,1) struct
    opts.DepthM (1,1) double {mustBePositive} = 0.3
    opts.MinAreaM2 (1,1) double {mustBeNonnegative} = 0.5
    opts.CraterMinWidthM (1,1) double {mustBePositive} = 3
    opts.CraterMaxWidthM (1,1) double {mustBePositive} = 15
    opts.LinearAspect (1,1) double {mustBePositive} = 4
end
if ~isequal(size(A.D), size(S.Z))
    error('mgv22:InvalidRelief', 'A.D and S.Z must have the same size.');
end
[X, Y] = meshgrid(S.x, S.y); c = S.cell_m;
rows = struct('type', {}, 'x', {}, 'y', {}, 'area', {}, 'depth', {}, 'len', {}, 'wid', {});
masks = {A.D <= -opts.DepthM, A.D >= opts.DepthM};
for m = 1:2
    M = masks{m}; M(isnan(A.D)) = false;
    idx = find(M); n = numel(idx);
    if n == 0, continue; end
    node = zeros(size(M)); node(idx) = 1:n;
    h = M(:, 1:end-1) & M(:, 2:end); v = M(1:end-1, :) & M(2:end, :);
    a = node(:, 1:end-1); b = node(:, 2:end); p = node(1:end-1, :); q = node(2:end, :);
    s = [a(h); p(v)]; t = [b(h); q(v)];
    G = graph(sparse([s; t], [t; s], 1, n, n));
    bins = conncomp(G);
    for k = 1:max(bins)
        cells = idx(bins == k);
        area = numel(cells) * c^2;
        if area < opts.MinAreaM2, continue; end
        xs = X(cells); ys = Y(cells);
        dx = xs - mean(xs); dy = ys - mean(ys);
        ev = sort(max(eig([dx dy]' * [dx dy] / numel(cells)), 0));
        len = 4*sqrt(ev(2)) + c; wid = 4*sqrt(ev(1)) + c;
        if m == 2, ty = "berm";
        elseif len / wid >= opts.LinearAspect, ty = "trench";
        elseif wid > opts.CraterMaxWidthM, ty = "large depression";
        elseif wid >= opts.CraterMinWidthM, ty = "crater";
        else, ty = "pit (foxhole-size)";
        end
        rows(end+1) = struct('type', ty, 'x', mean(xs), 'y', mean(ys), 'area', area, ...
            'depth', max(abs(A.D(cells))), 'len', len, 'wid', wid); %#ok<AGROW>
    end
end
nr = numel(rows); col = @(f) reshape([rows.(f)], [], 1);
if nr == 0
    z = zeros(0, 1); ty = strings(0, 1);
    F = table(strings(0, 1), ty, z, z, z, z, z, z, strings(0, 1));
else
    F = table(compose("RF-%02d", (1:nr)'), reshape([rows.type], [], 1), col('x'), col('y'), col('area'), ...
        col('depth'), col('len'), col('wid'), repmat("INDIRECT EVIDENCE (SIMULATION)", nr, 1));
end
F.Properties.VariableNames = {'id', 'type', 'x_east_m', 'y_north_m', 'area_m2', 'depth_m', 'length_m', ...
    'width_m', 'label'};
end
