function z = heightAt(world, x, y)
%HEIGHTAT Terrain height (m above ENU datum) at (x_east, y_north), exactly on the drawn triangles.
%   z = mgv2.scene.heightAt(world, x, y)   vectorised; NaN outside the terrain extent.
%   Each grid cell [x_j, x_j+1] x [y_i, y_i+1] is split along the (i,j)-(i+1,j+1) diagonal, the same
%   split used in world.F. With local coordinates u (east), v (north) in [0,1]:
%     u >= v : triangle (00, 10, 11)  z = z00 + u (z10 - z00) + v (z11 - z10)
%     u <  v : triangle (00, 11, 01)  z = z00 + u (z11 - z01) + v (z01 - z00)
sz = size(x); x = x(:); y = y(:);
gx = world.x; gy = world.y; Z = world.Z; dx = gx(2) - gx(1); dy = gy(2) - gy(1);
z = nan(numel(x), 1);
ok = x >= gx(1) & x <= gx(end) & y >= gy(1) & y <= gy(end) & isfinite(x) & isfinite(y);
j = min(floor((x(ok) - gx(1)) / dx) + 1, numel(gx) - 1);
i = min(floor((y(ok) - gy(1)) / dy) + 1, numel(gy) - 1);
u = (x(ok) - gx(j)') / dx; v = (y(ok) - gy(i)') / dy;
ny = size(Z, 1);
z00 = Z(i + (j - 1) * ny); z10 = Z(i + j * ny); z01 = Z(i + 1 + (j - 1) * ny); z11 = Z(i + 1 + j * ny);
lower = u >= v;
zz = zeros(size(u));
zz(lower) = z00(lower) + u(lower) .* (z10(lower) - z00(lower)) + v(lower) .* (z11(lower) - z10(lower));
up = ~lower;
zz(up) = z00(up) + u(up) .* (z11(up) - z01(up)) + v(up) .* (z01(up) - z00(up));
z(ok) = zz;
z = reshape(z, sz);
end
