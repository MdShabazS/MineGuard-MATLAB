function [P, hit, range] = georegisterRays(world, O, D)
%GEOREGISTERRAYS First terrain intersection of camera rays on the PUBLIC terrain (ENU metres).
%   [P, hit, range] = mgv2.detect.georegisterRays(world, O, D)
%   Same method as mgv2.scene.intersectTerrain (march along the ray until it passes below heightAt, then
%   bisection on the drawn triangles) with a 0.5 m march (terrain grid 1 m, smooth) and 24 bisection steps
%   (3e-8 m), plus two speed-ups: the march starts where
%   the ray descends to the highest terrain point + 0.5 m (no intersection can exist above it), and all rays
%   are bisected together after the march. Range is measured from the true origin O.
%   hit = false (P, range NaN) if the ray leaves the terrain extent or exceeds 200 m: never a fabricated point.
n = size(O, 1); P = nan(n, 3); range = nan(n, 1); hit = false(n, 1);
if n == 0, return; end
zTop = max(world.Z(:)) + 0.5; step = 0.5; tMax = 200;
f = @(t, i) O(i,3) + t .* D(i,3) - mgv2.scene.heightAt(world, O(i,1) + t .* D(i,1), O(i,2) + t .* D(i,2));
t0 = zeros(n, 1); down = D(:,3) < 0;
t0(down) = max(0, (O(down,3) - zTop) ./ -D(down,3));
a = t0; b = nan(n, 1);
active = find(f(zeros(n, 1), (1:n)') > 0);                % origin must be above the ground
tc = t0;
while ~isempty(active)
    tn = tc(active) + step;
    fv = f(tn, active);
    gone = isnan(fv) | tn > tMax;
    cross = ~gone & fv <= 0;
    b(active(cross)) = tn(cross);
    keep = ~gone & ~cross;
    a(active(keep)) = tn(keep); tc(active(keep)) = tn(keep);
    active = active(keep);
end
idx = find(isfinite(b));
if isempty(idx), return; end
lo = a(idx); hi = b(idx);
for k = 1:24                                             % 0.5 m / 2^24 = 3e-8 m
    m = (lo + hi) / 2; below = f(m, idx) <= 0;
    hi(below) = m(below); lo(~below) = m(~below);
end
range(idx) = hi; P(idx, :) = O(idx, :) + hi .* D(idx, :); hit(idx) = true;
end
