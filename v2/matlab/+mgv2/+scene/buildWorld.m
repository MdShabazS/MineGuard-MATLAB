function world = buildWorld(cfg)
%BUILDWORLD Seeded, triangulated synthetic survey world: the single geometry source (V2-003).
%   world = mgv2.scene.buildWorld()            default field
%   world = mgv2.scene.buildWorld(cfg)         cfg from mgv2.scene.defaultSceneConfig
%
%   Terrain: regular grid (cfg.grid_spacing_m), height = gentle slope + seeded sum of smooth Fourier
%   modes + one mound and one shallow gully, blended flat over the home pad. Every grid cell is split
%   into two triangles along the (i,j)-(i+1,j+1) diagonal; world.F lists exactly those triangles and the
%   renderer draws exactly world.V/world.F, so mgv2.scene.heightAt agrees with the drawn ground to
%   floating-point precision (barycentric on the same triangles).
%   Surface colour (albedo) is per vertex: soil/grass mixture driven by a second seeded noise field and
%   by slope; calibration landmark discs are painted into mgv2.scene.albedoAt.
%   Objects (rocks, bushes, survey corner markers) are seeded and SEATED on the terrain; each object's
%   mesh is generated deterministically by mgv2.scene.objectMesh, so render and export agree.
%   No hidden truth: the world has no target/label/material-of-hazard fields.
if nargin < 1, cfg = mgv2.scene.defaultSceneConfig(); end
cfg = validate(cfg);
rs = RandStream('mt19937ar', 'Seed', cfg.seed);
x = cfg.extent_enu_m(1,1):cfg.grid_spacing_m:cfg.extent_enu_m(1,2);
y = cfg.extent_enu_m(2,1):cfg.grid_spacing_m:cfg.extent_enu_m(2,2);
[X, Y] = meshgrid(x, y);                                   % rows = y (north), cols = x (east)
Z = cfg.slope(1) * X + cfg.slope(2) * Y;
nm = 14; amp = cfg.relief_m * 0.55;
for k = 1:nm                                               % smooth rolling relief, wavelengths 18..90 m
    lam = 18 + 72 * rand(rs); th = 2 * pi * rand(rs); ph = 2 * pi * rand(rs);
    Z = Z + amp * (lam / 90) * sin(2 * pi * (cos(th) * X + sin(th) * Y) / lam + ph) / sqrt(nm / 3);
end
Z = Z + 0.9 * cfg.relief_m * exp(-((X - 25).^2 + (Y - 35).^2) / (2 * 14^2));          % mound
Z = Z - 0.5 * cfg.relief_m * exp(-((X + 5 * sin(Y / 20) + 10).^2) / (2 * 3^2)) .* (abs(Y) < 60);   % gully
% flat home pad (blend over 6 m)
h = cfg.home_enu_m; d = max(abs(X - h(1)), abs(Y - h(2))) - cfg.home_pad_m / 2;
zh = interp2(X, Y, Z, h(1), h(2)); wgt = min(max(d / 6, 0), 1); wgt = wgt .^ 2 .* (3 - 2 * wgt);
Z = zh + (Z - zh) .* wgt;
% albedo: grass (olive) vs bare soil (brown), slope makes soil, small seeded jitter
N2 = zeros(size(X));
for k = 1:8
    lam = 6 + 30 * rand(rs); th = 2 * pi * rand(rs); ph = 2 * pi * rand(rs);
    N2 = N2 + sin(2 * pi * (cos(th) * X + sin(th) * Y) / lam + ph) / 8;
end
[gx, gy] = gradient(Z, cfg.grid_spacing_m); slope = hypot(gx, gy);
soil = min(max(0.5 + 1.6 * N2 + 3 * slope, 0), 1);
grass = [0.46 0.58 0.27]; dirt = [0.68 0.57 0.41]; dry = [0.74 0.69 0.47];
N3 = zeros(size(X));                                       % fine-scale patchiness (1.5..5 m)
for k = 1:6
    lam = 1.5 + 3.5 * rand(rs); th = 2 * pi * rand(rs); ph = 2 * pi * rand(rs);
    N3 = N3 + sin(2 * pi * (cos(th) * X + sin(th) * Y) / lam + ph) / 6;
end
dryw = min(max(0.5 + 2.2 * N3, 0), 1) .* (1 - soil) * 0.6;
C = (1 - soil(:) - dryw(:)) .* grass + soil(:) .* dirt + dryw(:) .* dry;
C = C .* (0.90 + 0.20 * rand(rs, numel(X), 1));
pad = max(abs(X(:) - h(1)), abs(Y(:) - h(2))) <= cfg.home_pad_m / 2;
C(pad, :) = repmat([0.62 0.62 0.60], nnz(pad), 1);         % concrete pad
C = min(max(C, 0), 1);
[ny, nx] = size(Z); V = [X(:) Y(:) Z(:)];
id = reshape(1:numel(Z), ny, nx);
a = id(1:end-1, 1:end-1); b = id(1:end-1, 2:end); c = id(2:end, 2:end); e = id(2:end, 1:end-1);
F = [a(:) b(:) c(:); a(:) c(:) e(:)];                     % same diagonal everywhere: (i,j)-(i+1,j+1)
world = struct('schema_version', cfg.schema_version, 'scene_id', cfg.scene_id, 'seed', cfg.seed, ...
    'config', cfg, 'x', x, 'y', y, 'Z', Z, 'V', V, 'F', F, 'vertex_rgb', C, ...
    'units', "metres, ENU (x east, y north, z up above virtual datum)");
world.landmarks = cfg.landmarks;
for k = 1:numel(world.landmarks)
    world.landmarks(k).z = mgv2.scene.heightAt(world, world.landmarks(k).xy(1), world.landmarks(k).xy(2));
end
world.objects = placeObjects(world, cfg, rs);
end

function O = placeObjects(world, cfg, rs)
kinds = [repmat("rock", 1, cfg.n_rocks), repmat("bush", 1, cfg.n_bushes)];
ext = cfg.extent_enu_m; h = cfg.home_enu_m; rows = cell(0, 1);
for k = 1:numel(kinds)
    for tries = 1:50
        p = [ext(1,1) + 4 + (diff(ext(1,:)) - 8) * rand(rs), ext(2,1) + 4 + (diff(ext(2,:)) - 8) * rand(rs)];
        if max(abs(p - h)) > cfg.home_pad_m + 3 && all(arrayfun(@(L) norm(p - L.xy) > 4, cfg.landmarks)), break; end
    end
    if kinds(k) == "rock"
        r = 0.25 + 0.55 * rand(rs); ht = r * (0.5 + 0.4 * rand(rs)); col = [0.47 0.45 0.42] .* (0.85 + 0.25 * rand(rs));
    else
        r = 0.5 + 0.7 * rand(rs); ht = 0.6 + 0.9 * rand(rs); col = [0.17 0.33 0.12] .* (0.8 + 0.4 * rand(rs));
    end
    rows{end+1, 1} = {sprintf("%s-%03d", upper(kinds(k)), k), kinds(k), p(1), p(2), r, ht, min(col, 1), randi(rs, 2^31)}; %#ok<AGROW>
end
P = cfg.survey_polygon_enu_m;
for k = 1:size(P, 1)
    rows{end+1, 1} = {sprintf("MARKER-%d", k), "marker", P(k,1), P(k,2), 0.08, 1.5, [1.0 0.45 0.05], k}; %#ok<AGROW>
end
R = vertcat(rows{:});
O = cell2table(R, 'VariableNames', {'object_id','kind','x_east_m','y_north_m','radius_m','height_m','rgb','mesh_seed'});
O.object_id = string(O.object_id); O.kind = string(O.kind);
% seat each object on its ACTUAL mesh footprint: base = lowest ground under any mesh vertex, embedded
% 3 cm, so no vertex of the object floats above the ground (tested in testV2003Scene s05)
O.z_base_m = zeros(height(O), 1); zb = zeros(height(O), 1);
for k = 1:height(O)
    V = mgv2.scene.objectMesh(O(k, :));
    zb(k) = min(mgv2.scene.heightAt(world, [V(:,1); O.x_east_m(k)], [V(:,2); O.y_north_m(k)])) - 0.03;
end
O.z_base_m = zb;
end

function cfg = validate(cfg)
id = 'mgv2:InvalidSceneConfig';
allowed = ["schema_version","scene_id","seed","extent_enu_m","grid_spacing_m","relief_m","slope","home_enu_m", ...
    "home_pad_m","survey_polygon_enu_m","n_rocks","n_bushes","landmarks"];
f = string(fieldnames(cfg))';
if ~isempty(setxor(f, allowed)), error(id, 'Scene config fields must be exactly: %s (no truth/target data).', strjoin(allowed, ', ')); end
e = cfg.extent_enu_m;
if ~(isnumeric(e) && isequal(size(e), [2 2]) && all(isfinite(e), 'all') && all(e(:,2) - e(:,1) >= 10)), error(id, 'extent_enu_m must be 2x2 with spans >= 10 m.'); end
if ~(isscalar(cfg.grid_spacing_m) && cfg.grid_spacing_m >= 0.25 && cfg.grid_spacing_m <= 10), error(id, 'grid_spacing_m must be in [0.25, 10] m.'); end
if prod(floor(diff(e, 1, 2)' / cfg.grid_spacing_m) + 1) > 2e6, error(id, 'Terrain grid too large (> 2e6 vertices).'); end
if ~(isscalar(cfg.relief_m) && cfg.relief_m >= 0 && cfg.relief_m <= 50), error(id, 'relief_m must be in [0, 50] m.'); end
if ~(isscalar(cfg.seed) && cfg.seed >= 0 && cfg.seed == round(cfg.seed)), error(id, 'seed must be a non-negative integer.'); end
h = cfg.home_enu_m;
if ~(numel(h) == 2 && h(1) > e(1,1) + cfg.home_pad_m && h(1) < e(1,2) - cfg.home_pad_m && h(2) > e(2,1) + cfg.home_pad_m && h(2) < e(2,2) - cfg.home_pad_m)
    error(id, 'home pad must lie inside the extent.');
end
if ~(isscalar(cfg.n_rocks) && cfg.n_rocks >= 0 && isscalar(cfg.n_bushes) && cfg.n_bushes >= 0), error(id, 'object counts must be >= 0.'); end
end
