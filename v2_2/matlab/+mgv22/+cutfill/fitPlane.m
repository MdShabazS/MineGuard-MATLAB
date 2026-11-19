function P = fitPlane(S, mask)
%FITPLANE Least-squares design plane z = a + b*x + c*y through the masked surface cells.
%   P = mgv22.cutfill.fitPlane(S, mask)
%   Returns P.a, P.b, P.c (ENU metres), P.slope_pct = 100*hypot(b,c) and P.heading_deg, the downhill
%   compass azimuth (clockwise from north, [0,360); 0 for a level plane). Errors with 'mgv22:TooFewCells'
%   when fewer than 3 cells are usable or the cells are collinear (rank-deficient).
[X, Y] = meshgrid(S.x, S.y);
m = logical(mask) & ~isnan(S.Z);
if nnz(m) < 3
    error('mgv22:TooFewCells', 'At least 3 cells with data are needed to fit a plane.');
end
A = [ones(nnz(m), 1), X(m), Y(m)];
if rank(A) < 3
    error('mgv22:TooFewCells', 'Cells are collinear; a plane cannot be fitted.');
end
k = A \ S.Z(m);
P = struct('a', k(1), 'b', k(2), 'c', k(3), 'slope_pct', 100*hypot(k(2), k(3)), 'heading_deg', 0);
if k(2) ~= 0 || k(3) ~= 0, P.heading_deg = mod(atan2d(-k(2), -k(3)), 360); end
end
