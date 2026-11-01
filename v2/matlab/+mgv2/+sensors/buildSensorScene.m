function sc = buildSensorScene(world, env)
%BUILDSENSORSCENE Precomputed, PUBLIC visibility scene + private-to-forward-model radiometry (V2-005).
%   sc = mgv2.sensors.buildSensorScene(world)
%   sc = mgv2.sensors.buildSensorScene(world, env)      env from mgv2.sensors.defaultEnvironment
%   Built once per mission from the shared V2-003 world (same triangles as the 3-D view):
%     objects  - per object: world-frame vertices/faces, face normals, bounding sphere, kind, RGB
%     terrain  - world reference (heightAt/albedoAt), global max height, max slope (ray-cast bound)
%     thermal  - per-vertex surface temperature [K] and emissivity, per-object temperature/emissivity
%   V2-004 §2.3: the radiometric part (temperatures, emissivities) is SceneRadiometryConfig-like data used
%   only inside the forward models; public samples never contain it. The world has no hidden targets.
if nargin < 2, env = mgv2.sensors.defaultEnvironment(); end
O = world.objects; n = height(O);
obj = struct('kind', cell(n, 1), 'V', [], 'F', [], 'N', [], 'c', [], 'r', [], 'rgb', [], 'T_K', [], 'eps', []);
for k = 1:n
    [V, F] = mgv2.scene.objectMesh(O(k, :));
    e1 = V(F(:,2),:) - V(F(:,1),:); e2 = V(F(:,3),:) - V(F(:,1),:);
    N = cross(e1, e2, 2); N = N ./ max(vecnorm(N, 2, 2), eps);
    c = mean(V, 1);
    obj(k).kind = O.kind(k); obj(k).V = V; obj(k).F = F; obj(k).N = N; obj(k).c = c;
    obj(k).r = max(vecnorm(V - c, 2, 2)); obj(k).rgb = O.rgb(k, :);
end
% local slope bound for the ray caster: max |grad h| per 4 m tile, dilated by one tile (3x3 max)
% exact slopes of the two DRAWN triangles in every grid cell (same split as mgv2.scene.heightAt)
Z = world.Z; d = world.x(2) - world.x(1);
z00 = Z(1:end-1, 1:end-1); z10 = Z(1:end-1, 2:end); z01 = Z(2:end, 1:end-1); z11 = Z(2:end, 2:end);
sl = max(hypot(z10 - z00, z11 - z10), hypot(z11 - z01, z01 - z00)) / d;      % (ny-1) x (nx-1) cells
ts = 4; nx = ceil(size(sl, 2) / ts); ny = ceil(size(sl, 1) / ts);
tile = zeros(ny, nx);
for i = 1:ny
    for j = 1:nx
        r = (i - 1) * ts + 1:min(i * ts, size(sl, 1)); c = (j - 1) * ts + 1:min(j * ts, size(sl, 2));
        tile(i, j) = max(sl(r, c), [], 'all');
    end
end
pad = -inf(ny + 2, nx + 2); pad(2:end-1, 2:end-1) = tile; dil = tile;
for di = -1:1, for dj = -1:1, dil = max(dil, pad((2:end-1) + di, (2:end-1) + dj)); end, end
slopeTiles = struct('x0', world.x(1), 'y0', world.y(1), 'size_m', ts * (world.x(2) - world.x(1)), 'max_slope', dil);
sc = struct('schema', "mg-v2-sensorscene/0.1", 'world', world, 'objects', obj, ...
    'obj_c', reshape([obj.c], 3, [])', 'obj_r', [obj.r]', ...
    'zmax', max(world.Z(:)), 'zmin', min(world.Z(:)), 'max_slope', max(sl(:)), 'slope_tiles', slopeTiles, 'env', env);
sc = mgv2.sensors.thermalSurface(sc);
end
