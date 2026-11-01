function hit = castRays(sc, O, D, maxRange)
%CASTRAYS First intersection of rays with the shared V2-003 terrain AND objects (V2-005 core caster).
%   hit = mgv2.sensors.castRays(sc, O, D, maxRange)
%   O, D  N-by-3 ENU origins and unit directions; maxRange (m)
%   hit   struct: t (N-by-1 range, NaN if none), P (N-by-3 point), N (N-by-3 surface normal),
%         kind (0 none, 1 terrain, 2 object), obj (object index or 0), face (object-local face or 0), reason ("NONE" | "NO_INTERSECTION"
%         | "OUT_OF_RANGE")
%   Terrain (height field z = h(x,y), same triangles as rendering): along a ray p(t) = O + tD with D_z < 0,
%   g(t) = O_z + t D_z - h(O_xy + t D_xy) is strictly decreasing when |grad h| * |D_xy| < |D_z|, so the
%   intersection is UNIQUE (hence the first) and the fixed point t = (O_z - h(p_xy(t))) / (-D_z) is a
%   contraction with factor |grad h| |D_xy| / |D_z|. The bound uses the LOCAL maximum slope (4 m tiles,
%   dilated) along the ray's [z_max, z_min] segment. Rays where the bound is >= 0.95 or that do not converge
%   fall back to 0.25 m marching + bisection restricted to that segment (first crossing guaranteed).
%   Objects: bounding-sphere culling, then Moller-Trumbore ray/triangle intersection on the object mesh.
%   The nearest of terrain/object wins (occlusion). The UAV body is not part of the scene (no self-hit).
w = sc.world; n = size(O, 1);
t = nan(n, 1); kind = zeros(n, 1); objIdx = zeros(n, 1); face = zeros(n, 1); Nrm = nan(n, 3);
% ---------- terrain ----------
down = D(:,3) < -1e-9;
hz0 = mgv2.scene.heightAt(w, O(:,1), O(:,2));
above = O(:,3) > hz0 | isnan(hz0);
cand = find(down & above);
if ~isempty(cand)
    Oc = O(cand,:); Dc = D(cand,:); dz = -Dc(:,3);
    tHi = max(0, (Oc(:,3) - sc.zmax) ./ dz); tLo = (Oc(:,3) - sc.zmin) ./ dz;   % the hit lies in [tHi, tLo]
    % local contraction bound along the ray segment (dilated 4 m slope tiles sampled every <= segment/7)
    st = sc.slope_tiles; mx = zeros(numel(cand), 1);
    for f = linspace(0, 1, 8)
        tq = tHi + f * (tLo - tHi);
        ix = floor((Oc(:,1) + tq .* Dc(:,1) - st.x0) / st.size_m) + 1; iy = floor((Oc(:,2) + tq .* Dc(:,2) - st.y0) / st.size_m) + 1;
        okq = ix >= 1 & iy >= 1 & ix <= size(st.max_slope, 2) & iy <= size(st.max_slope, 1);
        v = inf(numel(cand), 1); v(okq) = st.max_slope(sub2ind(size(st.max_slope), iy(okq), ix(okq)));
        mx = max(mx, v);
    end
    rho = mx .* vecnorm(Dc(:,1:2), 2, 2) ./ dz;
    rho((tLo - tHi) .* vecnorm(Dc(:,1:2), 2, 2) / 7 > st.size_m) = inf;   % samples too sparse: no bound claimed
    % Illinois (modified regula falsi) on the guaranteed bracket g(tHi) >= 0 >= g(tLo); converged rays
    % leave the active set. With rho < 0.95 the root in the bracket is unique, hence the first hit.
    gfun = @(tt, ii) Oc(ii,3) - tt .* dz(ii) - mgv2.scene.heightAt(w, Oc(ii,1) + tt .* Dc(ii,1), Oc(ii,2) + tt .* Dc(ii,2));
    a = tHi; b = tLo; ga = gfun(a, (1:numel(cand))'); gb = gfun(b, (1:numel(cand))');
    tc = nan(numel(cand), 1); side = zeros(numel(cand), 1);
    act = find(isfinite(ga) & isfinite(gb) & ga >= 0 & gb <= 0);
    z0 = act(ga(act) == 0); tc(z0) = a(z0); act = setdiff(act, z0);
    for it = 1:60
        if isempty(act), break; end
        m = (a(act) .* gb(act) - b(act) .* ga(act)) ./ (gb(act) - ga(act));
        gm = gfun(m, act);
        conv = abs(gm) < 1e-9 | (b(act) - a(act)) < 1e-9;
        tc(act(conv)) = m(conv);
        pos = gm > 0;                                       % root in [m, b]
        ia = act(pos); a(ia) = m(pos); ga(ia) = gm(pos);
        ib = act(~pos); b(ib) = m(~pos); gb(ib) = gm(~pos);
        % Illinois: halve the retained end's value when the same side moves twice
        rp = ia(side(ia) == 1); gb(rp) = gb(rp) / 2; rn = ib(side(ib) == -1); ga(rn) = ga(rn) / 2;
        side(ia) = 1; side(ib) = -1;
        act = act(~conv);
    end
    ok = isfinite(tc) & tc >= 0 & rho < 0.95;
    t(cand(ok)) = tc(ok);
    fb = find(~ok);
    if ~isempty(fb)          % bounded march over [tHi, tLo] (0.25 m) + bisection: first crossing guaranteed
        a = tHi(fb); b = tLo(fb); tf = nan(numel(fb), 1); act = true(numel(fb), 1);
        g = @(tt, idx) Oc(fb(idx),3) - tt .* dz(fb(idx)) - mgv2.scene.heightAt(w, Oc(fb(idx),1) + tt .* Dc(fb(idx),1), Oc(fb(idx),2) + tt .* Dc(fb(idx),2));
        prev = a; step = 0.25;
        for tt = 0:step:max(b - a)
            idx = find(act); if isempty(idx), break; end
            cur = min(a(idx) + tt + step, b(idx)); gv = g(cur, idx);
            out = isnan(gv); act(idx(out)) = false;
            cr = ~out & gv <= 0; ci = idx(cr);
            if ~isempty(ci)
                lo = prev(ci); hi = cur(cr);
                for k = 1:40, m = (lo + hi) / 2; bel = g(m, ci) <= 0; hi(bel) = m(bel); lo(~bel) = m(~bel); end
                tf(ci) = hi; act(ci) = false;
            end
            prev(idx) = cur;
        end
        t(cand(fb(isfinite(tf)))) = tf(isfinite(tf));
    end
    kind(isfinite(t)) = 1;
end
% ---------- objects (culled to the region spanned by the rays) ----------
if ~isempty(sc.objects)
    tEnd = t; tEnd(isnan(tEnd)) = maxRange; Pend = O + min(tEnd, maxRange) .* D;
    lo = min([O; Pend], [], 1); hi = max([O; Pend], [], 1);
    oc = sc.obj_c; orr = sc.obj_r;
    near = find(all(oc + orr >= lo & oc - orr <= hi, 2));
    for k = near'
        L = oc(k,:) - O; tca = sum(L .* D, 2); d2 = sum(L .* L, 2) - tca.^2;
        rays = find(d2 <= orr(k)^2 & tca + orr(k) > 0 & (isnan(t) | tca - orr(k) < t));
        if isempty(rays), continue; end
        ob = sc.objects(k);
        [tk, fk] = mollerTrumbore(O(rays,:), D(rays,:), ob.V, ob.F);
        closer = isfinite(tk) & (isnan(t(rays)) | tk < t(rays));
        r = rays(closer);
        t(r) = tk(closer); kind(r) = 2; objIdx(r) = k; face(r) = fk(closer); Nrm(r,:) = ob.N(fk(closer), :);
    end
end
% ---------- range limits, points, terrain normals ----------
reason = repmat("NONE", n, 1);
reason(isnan(t)) = "NO_INTERSECTION";
far = isfinite(t) & t > maxRange; reason(far) = "OUT_OF_RANGE";
t(far) = NaN; kind(far) = 0; objIdx(far) = 0; face(far) = 0;
P = O + t .* D;
ter = kind == 1;
if any(ter)                       % exact normal of the drawn triangle containing the hit (same split as heightAt)
    gx = w.x; gy = w.y; dd = gx(2) - gx(1); ny = numel(gy); Z = w.Z;
    j = min(max(floor((P(ter,1) - gx(1)) / dd) + 1, 1), numel(gx) - 1); i = min(max(floor((P(ter,2) - gy(1)) / dd) + 1, 1), ny - 1);
    u = (P(ter,1) - gx(j)') / dd; v = (P(ter,2) - gy(i)') / dd;
    z00 = Z(i + (j - 1) * ny); z10 = Z(i + j * ny); z01 = Z(i + 1 + (j - 1) * ny); z11 = Z(i + 1 + j * ny);
    lowr = u >= v;
    zx = (z11 - z01) / dd; zy = (z01 - z00) / dd;
    zx(lowr) = (z10(lowr) - z00(lowr)) / dd; zy(lowr) = (z11(lowr) - z10(lowr)) / dd;
    nn = [-zx, -zy, ones(nnz(ter), 1)];
    Nrm(ter, :) = nn ./ vecnorm(nn, 2, 2);
end
hit = struct('t', t, 'P', P, 'N', Nrm, 'kind', kind, 'obj', objIdx, 'face', face, 'reason', reason);
end

function [tmin, fmin] = mollerTrumbore(O, D, V, F)
% vectorised over rays x triangles (object meshes are small: <= ~300 triangles)
v0 = V(F(:,1),:); e1 = V(F(:,2),:) - v0; e2 = V(F(:,3),:) - v0;
nr = size(O, 1); nt = size(F, 1);
if nr * nt <= 4e5          % small problem: fully vectorised rays x triangles
    E1 = reshape(e1', 1, 3, nt); E2 = reshape(e2', 1, 3, nt); V0 = reshape(v0', 1, 3, nt);
    pv = cross(repmat(D, 1, 1, nt), repmat(E2, nr, 1, 1), 2);
    det = sum(pv .* E1, 2); tv = O - V0; u = sum(tv .* pv, 2) ./ det;
    qv = cross(tv, repmat(E1, nr, 1, 1), 2); v = sum(D .* qv, 2) ./ det; tt = sum(qv .* E2, 2) ./ det;
    h = abs(det) > 1e-12 & u >= 0 & v >= 0 & u + v <= 1 & tt > 1e-6;
    tt(~h) = inf; tt = reshape(tt, nr, nt);
    [tmin, fmin] = min(tt, [], 2); fmin(isinf(tmin)) = 0; tmin(isinf(tmin)) = NaN;
    return
end
tmin = inf(nr, 1); fmin = zeros(nr, 1);
for j = 1:nt
    pv = cross(D, repmat(e2(j,:), nr, 1), 2); det = pv * e1(j,:)';
    okd = abs(det) > 1e-12; inv = 1 ./ det;
    tv = O - v0(j,:); u = sum(tv .* pv, 2) .* inv;
    qv = cross(tv, repmat(e1(j,:), nr, 1), 2); v = sum(D .* qv, 2) .* inv;
    tt = (qv * e2(j,:)') .* inv;
    h = okd & u >= 0 & v >= 0 & u + v <= 1 & tt > 1e-6 & tt < tmin;
    tmin(h) = tt(h); fmin(h) = j;
end
tmin(isinf(tmin)) = NaN;
end
