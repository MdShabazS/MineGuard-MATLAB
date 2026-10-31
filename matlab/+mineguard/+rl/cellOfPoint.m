function id = cellOfPoint(G, x, y)
%CELLOFPOINT Survey-cell ID for ENU points, using the MG-005 computeCoverage cell rule.
%   ix = min(nx, max(1, floor((x - x_min)/dx) + 1)), likewise iy; id = (iy-1)*nx + ix.
ix = min(G.nx, max(1, floor((x - G.bounds(1)) / G.dx) + 1));
iy = min(G.ny, max(1, floor((y - G.bounds(3)) / G.dy) + 1));
id = (iy - 1) * G.nx + ix;
end
