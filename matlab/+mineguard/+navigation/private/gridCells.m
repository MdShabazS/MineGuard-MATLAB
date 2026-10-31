function [xc, yc, dx, dy] = gridCells(bounds, spacing)
%GRIDCELLS Survey cell centres covering bounds. The cells are an even subdivision,
%   so the actual pitch is <= spacing: nx = ceil(width/spacing) columns, etc.
width = bounds(2) - bounds(1);
height = bounds(4) - bounds(3);
nx = max(1, ceil(width / spacing - 1e-9));
ny = max(1, ceil(height / spacing - 1e-9));
dx = width / nx;
dy = height / ny;
xc = bounds(1) + ((1:nx) - 0.5) * dx;
yc = bounds(3) + ((1:ny) - 0.5) * dy;
end
