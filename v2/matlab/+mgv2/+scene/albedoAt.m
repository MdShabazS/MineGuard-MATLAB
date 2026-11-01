function rgb = albedoAt(world, x, y)
%ALBEDOAT Surface colour (RGB in [0,1]) at ENU points, consistent with the rendered terrain.
%   rgb = mgv2.scene.albedoAt(world, x, y)   x, y vectors -> N-by-3; NaN outside the terrain.
%   Vertex colours are interpolated barycentrically on the same triangles as heightAt; calibration
%   landmark discs (world.landmarks) override the colour inside their radius.
x = x(:); y = y(:); n = numel(x); rgb = nan(n, 3);
gx = world.x; gy = world.y; dx = gx(2) - gx(1); dy = gy(2) - gy(1); ny = numel(gy);
ok = x >= gx(1) & x <= gx(end) & y >= gy(1) & y <= gy(end);
j = min(floor((x(ok) - gx(1)) / dx) + 1, numel(gx) - 1);
i = min(floor((y(ok) - gy(1)) / dy) + 1, numel(gy) - 1);
u = (x(ok) - gx(j)') / dx; v = (y(ok) - gy(i)') / dy;
C = world.vertex_rgb;
c00 = C(i + (j - 1) * ny, :); c10 = C(i + j * ny, :); c01 = C(i + 1 + (j - 1) * ny, :); c11 = C(i + 1 + j * ny, :);
lo = u >= v; out = zeros(nnz(ok), 3);
out(lo,:) = c00(lo,:) + u(lo) .* (c10(lo,:) - c00(lo,:)) + v(lo) .* (c11(lo,:) - c10(lo,:));
up = ~lo;
out(up,:) = c00(up,:) + u(up) .* (c11(up,:) - c01(up,:)) + v(up) .* (c01(up,:) - c00(up,:));
rgb(ok, :) = out;
for k = 1:numel(world.landmarks)
    L = world.landmarks(k);
    in = hypot(x - L.xy(1), y - L.xy(2)) <= L.radius_m;
    rgb(in, :) = repmat(L.color, nnz(in), 1);
end
end
