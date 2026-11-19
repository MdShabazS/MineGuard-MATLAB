function R = volumes(S, mask, P)
%VOLUMES Cut and fill volumes of a surveyed surface against a design plane, inside a cell mask.
%   R = mgv22.cutfill.volumes(S, mask, P)
%   Per cell d = Z - (a + b*x + c*y): positive d is cut (material above design), negative is fill.
%   Fields: cut_m3, fill_m3, net_m3 (cut - fill), ratio (cut/fill; Inf if only cut, NaN if neither),
%   max_cut_m, max_fill_m (>= 0), area_m2, area_ha, cut_per_ha (NaN if no area), D (NaN outside mask), cells.
%   Simulation and survey arithmetic only; not a measured earthworks quantity.
[X, Y] = meshgrid(S.x, S.y);
m = logical(mask) & ~isnan(S.Z);
D = S.Z - (P.a + P.b*X + P.c*Y);
D(~m) = NaN;
d = D(m); A = S.cell_m^2;
R.cut_m3 = sum(max(d, 0))*A;
R.fill_m3 = sum(max(-d, 0))*A;
R.net_m3 = R.cut_m3 - R.fill_m3;
if R.fill_m3 > 0, R.ratio = R.cut_m3/R.fill_m3;
elseif R.cut_m3 > 0, R.ratio = Inf;
else, R.ratio = NaN;
end
R.max_cut_m = max([0; d]);
R.max_fill_m = max([0; -d]);
R.cells = nnz(m);
R.area_m2 = R.cells*A;
R.area_ha = R.area_m2/1e4;
if R.area_ha > 0, R.cut_per_ha = R.cut_m3/R.area_ha; else, R.cut_per_ha = NaN; end
R.D = D;
end
