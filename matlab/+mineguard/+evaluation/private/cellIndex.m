function [lin, inside] = cellIndex(G, x, y)
%CELLINDEX Linear cell index (ny x nx, column-major) for points, using the half-open boundary rule.
%   Points outside the bounds get inside = false and lin = 0.
b = G.bounds;
inside = isfinite(x) & isfinite(y) & x >= b(1) & x <= b(2) & y >= b(3) & y <= b(4);
ix = min(G.nx, floor((x - b(1)) / G.dx) + 1);
iy = min(G.ny, floor((y - b(3)) / G.dy) + 1);
lin = zeros(size(x));
lin(inside) = sub2ind([G.ny G.nx], iy(inside), ix(inside));
end
