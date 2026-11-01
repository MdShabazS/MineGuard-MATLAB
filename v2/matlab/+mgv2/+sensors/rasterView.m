function hit = rasterView(sc, cam, T_ws, maxRange)
%RASTERVIEW Visible surface for every pixel of a pinhole camera by perspective z-buffer rasterization.
%   hit = mgv2.sensors.rasterView(sc, cam, T_ws, maxRange)
%   Same output as mgv2.sensors.castRays for the camera's pixel rays (column-major pixel order, W*H rows):
%   t (range along the pixel ray), P (ENU point), N (surface normal), kind (0/1 terrain/2 object), obj,
%   reason. Exactness: terrain and objects are planar triangles; perspective-correct barycentrics of a
%   pixel centre inside a projected triangle give the SAME point the pixel ray hits on that triangle, and
%   the minimum-depth triangle (z-buffer) is the first hit. Triangles that cross the near plane (camera
%   very close to the ground) are excluded and every pixel left uncovered is ray-cast exactly with
%   mgv2.sensors.castRays, so the result matches ray casting (verified in testV2005Sensors).
W = cam.width_px; H = cam.height_px; R = T_ws(1:3,1:3); c0 = T_ws(1:3,4)'; near = 0.05;
fx = cam.fx; fy = cam.fy; cx = cam.cx; cy = cam.cy;
w = sc.world;
% ---- candidate triangles: terrain + objects ----
[Vt, Ft, Nt] = terrainTriangles(w);
% conservative pre-selection of terrain cells: everything the camera can see lies inside the cone of
% half-angle (optical-axis tilt from nadir + half-diagonal FOV); intersect it with z >= zmin. If that cone
% approaches the horizon (> 80 deg) every triangle is kept.
ax = R(:,3)'; tilt = acosd(max(-1, min(1, -ax(3))));
halfDiag = atand(hypot((W / 2) / fx, (H / 2) / fy));
if tilt + halfDiag < 80 && c0(3) > sc.zmin
    rad = (c0(3) - sc.zmin) * tand(tilt + halfDiag) + 2 * (w.x(2) - w.x(1));
    d = w.x(2) - w.x(1); ny1 = numel(w.y) - 1; nx1 = numel(w.x) - 1;
    j0 = max(1, floor((c0(1) - rad - w.x(1)) / d) + 1); j1 = min(nx1, floor((c0(1) + rad - w.x(1)) / d) + 1);
    i0 = max(1, floor((c0(2) - rad - w.y(1)) / d) + 1); i1 = min(ny1, floor((c0(2) + rad - w.y(1)) / d) + 1);
    [II, JJ] = ndgrid(i0:i1, j0:j1); cellIdx = (JJ(:) - 1) * ny1 + II(:);
    sel = [cellIdx; ny1 * nx1 + cellIdx];          % lower then upper triangle of each cell (world.F order)
    Ft = Ft(sel, :); Nt = Nt(sel, :);
end
Vs = Vt; Fs = Ft; Ns = Nt; kindT = ones(size(Ft, 1), 1); objT = zeros(size(Ft, 1), 1); faceT = zeros(size(Ft, 1), 1);
% objects: conservative view-frustum test on each bounding sphere, then ONE concatenation
oc = (sc.obj_c - c0) * R; rr = sc.obj_r; th = (W / 2) / fx; tv = (H / 2) / fy;
vis = find(oc(:,3) + rr > near & abs(oc(:,1)) <= (oc(:,3) + rr) * th + rr .* sqrt(1 + th^2) ...
    & abs(oc(:,2)) <= (oc(:,3) + rr) * tv + rr .* sqrt(1 + tv^2) & vecnorm(oc, 2, 2) - rr < maxRange);
if ~isempty(vis)
    obs = sc.objects(vis); nvo = arrayfun(@(o) size(o.V, 1), obs); nfo = arrayfun(@(o) size(o.F, 1), obs);
    base = size(Vt, 1) + [0; cumsum(nvo(1:end-1))];
    Fo = cell2mat(arrayfun(@(i) obs(i).F + base(i), (1:numel(obs))', 'UniformOutput', false));
    Vs = [Vt; vertcat(obs.V)]; Fs = [Ft; Fo]; Ns = [Nt; vertcat(obs.N)];
    kindT = [kindT; 2 * ones(sum(nfo), 1)]; objT = [objT; reshape(repelem(vis(:), nfo(:)), [], 1)];
    faceT = [faceT; cell2mat(arrayfun(@(m) (1:m)', nfo(:), 'UniformOutput', false))];
end
Pc = (Vs - c0) * R;                         % camera coordinates (x right, y down, z optical)
z = Pc(:,3); u = fx * Pc(:,1) ./ z + cx; v = fy * Pc(:,2) ./ z + cy;
zf = z(Fs); uf = u(Fs); vf = v(Fs);
allFront = all(zf > near, 2); anyFront = any(zf > near, 2);
crossNear = anyFront & ~allFront;
if any(crossNear)   % only crossing triangles near the camera or with a front vertex inside the image matter
    dmin = min(sqrt(sum((reshape(Vs(Fs(crossNear,:)', :), 3, [], 3) - reshape(c0, 1, 1, 3)).^2, 3)), [], 1)';
    inImg = any(zf(crossNear,:) > near & uf(crossNear,:) >= 0.5 & uf(crossNear,:) <= W + 0.5 & vf(crossNear,:) >= 0.5 & vf(crossNear,:) <= H + 0.5, 2);
    ci = find(crossNear); crossNear(ci(~(dmin < 2 | inImg))) = false;
end
umin = max(ceil(min(uf, [], 2)), 1); umax = min(floor(max(uf, [], 2)), W);
vmin = max(ceil(min(vf, [], 2)), 1); vmax = min(floor(max(vf, [], 2)), H);
keep = find(allFront & umin <= umax & vmin <= vmax);
% ---- (triangle, pixel) pairs inside each triangle's pixel bounding box ----
nu = umax(keep) - umin(keep) + 1; nv = vmax(keep) - vmin(keep) + 1; cnt = nu .* nv;
tri = repelem(keep, cnt);
off = (1:sum(cnt))' - repelem(cumsum(cnt) - cnt, cnt) - 1;          % 0-based index within each box
nuR = repelem(nu, cnt);
pu = repelem(umin(keep), cnt) + mod(off, nuR); pv = repelem(vmin(keep), cnt) + floor(off ./ nuR);
x0 = uf(tri,1); y0 = vf(tri,1); x1 = uf(tri,2); y1 = vf(tri,2); x2 = uf(tri,3); y2 = vf(tri,3);
den = (y1 - y2) .* (x0 - x2) + (x2 - x1) .* (y0 - y2);
l0 = ((y1 - y2) .* (pu - x2) + (x2 - x1) .* (pv - y2)) ./ den;
l1 = ((y2 - y0) .* (pu - x2) + (x0 - x2) .* (pv - y2)) ./ den;
l2 = 1 - l0 - l1;
tol = -1e-9; in = l0 >= tol & l1 >= tol & l2 >= tol & abs(den) > 1e-12;
tri = tri(in); pu = pu(in); pv = pv(in); l0 = l0(in); l1 = l1(in); l2 = l2(in);
iz = l0 ./ zf(tri,1) + l1 ./ zf(tri,2) + l2 ./ zf(tri,3);           % perspective-correct 1/depth
depth = 1 ./ iz;
pix = (pu - 1) * H + pv;                                             % column-major linear pixel index
[~, ord] = sort(depth); [~, first] = unique(pix(ord), 'first'); win = ord(first);
n = W * H; t = nan(n, 1); P = nan(n, 3); Nrm = nan(n, 3); kind = zeros(n, 1); objIdx = zeros(n, 1); face = zeros(n, 1);
tv3 = zeros(n, 3); bary = nan(n, 3);   % terrain: drawn-triangle vertex indices and perspective-correct weights
wi = win; px = pix(wi); tr = tri(wi);
b0 = l0(wi) ./ zf(tr,1) ./ iz(wi); b1 = l1(wi) ./ zf(tr,2) ./ iz(wi); b2 = l2(wi) ./ zf(tr,3) ./ iz(wi);
F3 = Fs(tr, :);
P(px, :) = b0 .* Vs(F3(:,1), :) + b1 .* Vs(F3(:,2), :) + b2 .* Vs(F3(:,3), :);
t(px) = vecnorm(P(px, :) - c0, 2, 2);
Nrm(px, :) = Ns(tr, :); kind(px) = kindT(tr); objIdx(px) = objT(tr); face(px) = faceT(tr);
terw = kindT(tr) == 1; tv3(px(terw), :) = F3(terw, :); bary(px(terw), :) = [b0(terw) b1(terw) b2(terw)];
% ---- exact ray-cast fallback for uncovered pixels (near-plane triangles, gaps, beyond range) ----
miss = find(isnan(t));
if ~isempty(miss) || any(crossNear)
    if any(crossNear), miss = (1:n)'; end      % camera at the surface: ray-cast the whole frame exactly
    [vv0, uu0] = ind2sub([H W], miss);
    [O, D] = mgv2.scene.pixelRays(cam, T_ws, [uu0(:) vv0(:)]);
    h2 = mgv2.sensors.castRays(sc, O, D, maxRange);
    t(miss) = h2.t; P(miss, :) = h2.P; Nrm(miss, :) = h2.N; kind(miss) = h2.kind; objIdx(miss) = h2.obj; face(miss) = h2.face;
    tv3(miss, :) = 0; bary(miss, :) = NaN;   % ray-cast pixels: no raster barycentrics (consumers use point queries)
end
reason = repmat("NONE", n, 1);
far = isfinite(t) & t > maxRange; t(far) = NaN; P(far, :) = NaN; kind(far) = 0; objIdx(far) = 0; face(far) = 0; tv3(far, :) = 0; bary(far, :) = NaN; reason(far) = "OUT_OF_RANGE";
reason(isnan(t) & ~far) = "NO_INTERSECTION";
hit = struct('t', t, 'P', P, 'N', Nrm, 'kind', kind, 'obj', objIdx, 'face', face, 'tri_vertices', tv3, 'bary', bary, 'reason', reason);
end

function [V, F, N] = terrainTriangles(w)
persistent key Vc Fc Nc
k = [numel(w.x) numel(w.y) w.x(1) w.y(1) sum(w.Z(:))];
if isequal(k, key), V = Vc; F = Fc; N = Nc; return; end
V = w.V; F = w.F;
e1 = V(F(:,2),:) - V(F(:,1),:); e2 = V(F(:,3),:) - V(F(:,1),:);
N = cross(e1, e2, 2); N = N ./ vecnorm(N, 2, 2); N(N(:,3) < 0, :) = -N(N(:,3) < 0, :);
key = k; Vc = V; Fc = F; Nc = N;
end
