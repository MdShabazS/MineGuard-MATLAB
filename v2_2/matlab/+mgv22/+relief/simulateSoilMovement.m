function [before, after] = simulateSoilMovement(S, opts)
%SIMULATESOILMOVEMENT SIMULATED flood/landslide change of a surface: a downhill gully and a deposit fan (V22-T12).
%   [before, after] = mgv22.relief.simulateSoilMovement(S)
%   [before, after] = mgv22.relief.simulateSoilMovement(S, Seed=1, ChannelDepthM=0.4, DepositM=0.3, ChannelWidthM=3)
%   before = S. The path starts at the highest interior cell of a smoothed surface (box filter, radius 2 m, NaN
%   ignored) and steps one cell at a time to the steepest-descent 8-neighbour (drop/distance); it stops at the grid
%   edge, at a local minimum, at a NaN cell or after 2000 steps. Erosion: ChannelDepthM*max(0,1-(d/(w/2))^2), d =
%   distance to the path. Deposit at the path end: DepositM*exp(-r^2/(2*4^2)) within 12 m. NaN cells stay NaN.
%   Seed only adds a small smoothed random offset (5 mm RMS) to the routing surface for sinuosity
%   (RandStream mt19937ar), so the same Seed gives an identical result. Mines moved by water are motivated by the
%   Bosnia 2014 floods; this is a SIMULATION, not a hydrological model.
arguments
    S (1,1) struct
    opts.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 1
    opts.ChannelDepthM (1,1) double {mustBeNonnegative} = 0.4
    opts.DepositM (1,1) double {mustBeNonnegative} = 0.3
    opts.ChannelWidthM (1,1) double {mustBePositive} = 3
end
before = S;
[ny, nx] = size(S.Z); h = S.cell_m;
nanZ = isnan(S.Z);
k = max(1, round(2/h)); B = ones(2*k + 1);
Z0 = S.Z; Z0(nanZ) = 0;
Zs = conv2(Z0, B, 'same')./conv2(double(~nanZ), B, 'same');
rs = RandStream('mt19937ar', 'Seed', opts.Seed);
N = conv2(randn(rs, ny, nx), B, 'same'); N = 0.005*N/max(std(N(:)), eps);
Zr = Zs + N; Zr(nanZ) = NaN;
inner = Zr; m = min([k, floor((ny - 1)/2), floor((nx - 1)/2)]);
inner([1:m, end-m+1:end], :) = NaN; inner(:, [1:m, end-m+1:end]) = NaN;
if all(isnan(inner(:))), inner = Zr; end
if all(isnan(inner(:))), error('mgv22:InvalidRelief', 'The surface has no data.'); end
[~, i0] = max(inner(:)); [r, c] = ind2sub([ny nx], i0);
path = [r c];
[dc, dr] = meshgrid(-1:1); dr = dr(:); dc = dc(:); keep = ~(dr == 0 & dc == 0); dr = dr(keep); dc = dc(keep);
dist = hypot(dr, dc);
for step = 1:2000
    if r == 1 || r == ny || c == 1 || c == nx, break; end
    zn = Zr(sub2ind([ny nx], r + dr, c + dc));
    [s, j] = max((Zr(r, c) - zn)./dist);                               % NaN neighbours are ignored by max
    if isnan(s) || s <= 0, break; end
    r = r + dr(j); c = c + dc(j); path(end+1, :) = [r c]; %#ok<AGROW>
end
[X, Y] = meshgrid(S.x, S.y);
P = [S.x(path(:, 2))' S.y(path(:, 1))'];
d = hypot(X - P(1, 1), Y - P(1, 2));
for i = 1:size(P, 1) - 1
    v = P(i+1, :) - P(i, :); u = max(0, min(1, ((X - P(i, 1))*v(1) + (Y - P(i, 2))*v(2))/(v*v')));
    d = min(d, hypot(X - P(i, 1) - u*v(1), Y - P(i, 2) - u*v(2)));
end
w2 = opts.ChannelWidthM/2;
rEnd = hypot(X - P(end, 1), Y - P(end, 2));
dZ = -opts.ChannelDepthM*max(0, 1 - (d/w2).^2) + opts.DepositM*exp(-rEnd.^2/(2*4^2)).*(rEnd <= 12);
after = S;
after.Z = S.Z + dZ;
after.label = string(S.label) + " (SIMULATED flood/landslide change)";
end
