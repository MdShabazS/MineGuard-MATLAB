function [mask, info] = clipToPolygon(S, poly)
%CLIPTOPOLYGON Cells of a surveyed surface that lie inside a boundary polygon and have data.
%   [mask, info] = mgv22.cutfill.clipToPolygon(S, poly)
%   S is a surface struct (x, y, Z, cell_m); poly is N-by-2 ENU metres and is validated first.
%   mask(i,j) is true when the cell centre (S.x(j), S.y(i)) is inside or on the polygon and S.Z(i,j) is not NaN.
%   info.cells_inside counts the usable cells (= nnz(mask)); info.nan_cells_inside counts no-data cells inside.
poly = mgv22.cutfill.validateOutline(poly);
[X, Y] = meshgrid(S.x, S.y);
in = inpolygon(X, Y, poly(:,1), poly(:,2));
noData = isnan(S.Z);
mask = in & ~noData;
info = struct('cells_inside', nnz(mask), 'nan_cells_inside', nnz(in & noData));
end
