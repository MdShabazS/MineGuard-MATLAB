function [V, F] = objectMesh(obj)
%OBJECTMESH Deterministic world-frame mesh (ENU metres) for one world.objects row.
%   [V, F] = mgv2.scene.objectMesh(world.objects(k, :))
%   rock   - irregular low-poly boulder (seeded radial jitter of a 10x6 sphere), base at z_base_m
%   bush   - two stacked jittered spheroids (canopy) on a short trunk, base at z_base_m
%   marker - survey-corner pole (8-sided prism) with height height_m
rs = RandStream('mt19937ar', 'Seed', double(obj.mesh_seed));
x0 = obj.x_east_m; y0 = obj.y_north_m; z0 = obj.z_base_m; r = obj.radius_m; h = obj.height_m;
switch obj.kind
    case "rock"
        [sx, sy, sz] = sphere(10);
        jit = 1 + 0.22 * (rand(rs, size(sx)) - 0.5); jit(:, end) = jit(:, 1); jit(1, :) = mean(jit(1,:)); jit(end, :) = mean(jit(end,:));
        [V, F] = surf2mesh(x0 + r * sx .* jit, y0 + r * 0.8 * sy .* jit, z0 + h * (max(sz, -0.3) + 0.3) / 1.3 .* jit);
    case "bush"
        [sx, sy, sz] = sphere(8);
        jit = 1 + 0.25 * (rand(rs, size(sx)) - 0.5); jit(:, end) = jit(:, 1);
        [V1, F1] = surf2mesh(x0 + r * sx .* jit, y0 + r * sy .* jit, z0 + 0.25 * h + 0.45 * h * (sz + 1) .* jit);
        [V2, F2] = surf2mesh(x0 + 0.3 * r + 0.6 * r * sx, y0 - 0.2 * r + 0.6 * r * sy, z0 + 0.55 * h + 0.25 * h * (sz + 1));
        [V3, F3] = prism(x0, y0, z0, 0.06, 0.3 * h, 6);
        V = [V1; V2; V3]; F = [F1; F2 + size(V1, 1); F3 + size(V1, 1) + size(V2, 1)];
    otherwise   % marker
        [V, F] = prism(x0, y0, z0, r, h, 8);
end
end

function [V, F] = surf2mesh(X, Y, Z)
[m, n] = size(X); V = [X(:) Y(:) Z(:)]; id = reshape(1:m*n, m, n);
a = id(1:end-1, 1:end-1); b = id(2:end, 1:end-1); c = id(2:end, 2:end); d = id(1:end-1, 2:end);
F = [a(:) b(:) c(:); a(:) c(:) d(:)];
end

function [V, F] = prism(x0, y0, z0, r, h, n)
a = (0:n-1)' * 2 * pi / n; ring = [x0 + r * cos(a), y0 + r * sin(a)];
V = [ring, z0 + zeros(n, 1); ring, z0 + h + zeros(n, 1); x0 y0 z0 + h];
k = (1:n)'; k2 = mod(k, n) + 1;
F = [k k2 k2 + n; k k2 + n k + n; k + n, k2 + n, repmat(2 * n + 1, n, 1)];
end
