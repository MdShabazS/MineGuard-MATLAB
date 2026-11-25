function T = localTrend(S, radius_m, opts)
%LOCALTREND Robust, NaN-aware local trend of a surveyed surface (V22-T12).
%   T = mgv22.relief.localTrend(S, radius_m)
%   T = mgv22.relief.localTrend(S, radius_m, Iterations=3, RobustM=0.15)
%   At every cell a quadratic surface z = p1 + p2*u + p3*v + p4*u^2 + p5*u*v + p6*v^2 is fitted by least squares
%   to the valid cells within a (2h+1)-by-(2h+1) window, h = round(radius_m/cell_m); T is p1 (the fit at the
%   centre). The normal equations come from conv2 of the data mask and of the surface with the monomial kernels,
%   so NaN cells simply drop out. A quadratic follows natural slopes and curvature (mounds, gullies) that a moving
%   average would leave behind as false relief. Robust step: after each fit, cells with |S.Z - T| > RobustM are
%   left out and the fit is repeated (Iterations times), so a crater or a bush does not pull the trend towards
%   itself. Cells whose window has fewer than 10 valid cells, or an ill-conditioned fit, take the value of a
%   least-squares plane through the whole surface. Cells without data stay NaN. radius_m must exceed 2*cell_m
%   (error 'mgv22:InvalidRelief'). Simulation arithmetic only.
arguments
    S (1,1) struct
    radius_m (1,1) double
    opts.Iterations (1,1) double {mustBeInteger, mustBeNonnegative} = 3
    opts.RobustM (1,1) double {mustBePositive} = 0.15
end
if ~(isfinite(radius_m) && radius_m >= 2 * S.cell_m)
    error('mgv22:InvalidRelief', 'radius_m (%g) must be at least twice the cell size (%g m).', radius_m, S.cell_m);
end
Z = double(S.Z); W0 = ~isnan(Z);
[ny, nx] = size(Z);
T = nan(ny, nx);
if nnz(W0) < 3, return; end
[X, Y] = meshgrid(S.x, S.y);
c = [ones(nnz(W0), 1) X(W0) Y(W0)] \ Z(W0);
P = c(1) + c(2) * X + c(3) * Y;                       % fallback where the local fit is not possible

h = round(radius_m / S.cell_m);
[U, V] = meshgrid((-h:h) * S.cell_m);
pw = [0 0; 1 0; 0 1; 2 0; 1 1; 0 2];                  % monomials u^a v^b
K = @(a, b) rot90(U.^a .* V.^b, 2);                   % conv2 flips the kernel; flip it back
W = W0;
for it = 0:opts.Iterations
    Wd = double(W); Z0 = Z; Z0(~W) = 0;
    M = zeros(ny * nx, 6, 6); b = zeros(ny * nx, 6);
    for i = 1:6
        for j = i:6
            a = pw(i, :) + pw(j, :);
            m = conv2(Wd, K(a(1), a(2)), 'same');
            M(:, i, j) = m(:); M(:, j, i) = m(:);
        end
        r = conv2(Z0, K(pw(i, 1), pw(i, 2)), 'same'); b(:, i) = r(:);
    end
    T = P;
    for q = find(W0(:))'
        if M(q, 1, 1) < 10, continue; end
        A = reshape(M(q, :, :), 6, 6);
        if rcond(A) < 1e-12, continue; end
        p = A \ b(q, :)';
        T(q) = p(1);
    end
    W = W0 & abs(Z - T) <= opts.RobustM;
end
T(~W0) = NaN;
end
