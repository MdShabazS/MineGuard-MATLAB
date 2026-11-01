function [P, hit, range] = intersectTerrain(world, O, D, maxRange, step)
%INTERSECTTERRAIN First intersection of rays with the terrain surface (height field) — ENU metres.
%   [P, hit, range] = mgv2.scene.intersectTerrain(world, O, D)
%   [P, hit, range] = mgv2.scene.intersectTerrain(world, O, D, maxRange, step)
%   O, D N-by-3 ray origins and unit directions. Marches each ray in steps of `step` (default 0.25 m)
%   until it passes below heightAt, then bisects 40 times (sub-micrometre). hit=false (P, range NaN)
%   when the ray leaves the terrain extent or exceeds maxRange (default 200 m) — never a fabricated
%   point. Thin features narrower than `step` can be missed (documented limitation); objects (rocks,
%   bushes, markers) are NOT intersected here — terrain only.
if nargin < 4, maxRange = 200; end
if nargin < 5, step = 0.25; end
n = size(O, 1); P = nan(n, 3); range = nan(n, 1); hit = false(n, 1);
f = @(t, idx) O(idx,3) + t .* D(idx,3) - mgv2.scene.heightAt(world, O(idx,1) + t .* D(idx,1), O(idx,2) + t .* D(idx,2));
active = (1:n)'; t0 = zeros(n, 1); f0 = f(t0, active);
active = active(f0 > 0);                     % origin must be above ground
tPrev = zeros(n, 1);
for t = step:step:maxRange
    if isempty(active), break; end
    fv = f(repmat(t, numel(active), 1), active);
    out = isnan(fv); active(out) = []; fv(out) = [];
    cross = fv <= 0;
    idx = active(cross);
    if ~isempty(idx)
        a = tPrev(idx); b = repmat(t, numel(idx), 1);
        for k = 1:40
            m = (a + b) / 2; fm = f(m, idx);
            below = fm <= 0; b(below) = m(below); a(~below) = m(~below);
        end
        range(idx) = b; P(idx, :) = O(idx, :) + b .* D(idx, :); hit(idx) = true;
    end
    active = active(~cross); tPrev(active) = t;
end
end
