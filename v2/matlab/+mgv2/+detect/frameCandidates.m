function C = frameCandidates(s, world, cfg)
%FRAMECANDIDATES Interpretable per-frame anomaly candidates from ONE public RGB or thermal sample (V2-006).
%   C = mgv2.detect.frameCandidates(s, world, cfg)
%   s      valid RGB_NADIR or THERMAL_LWIR sample (mg-v2-sensors/1.0)
%   world  public V2-003 terrain geometry (heightAt), used only for georegistration
%   cfg    validated detector config (mgv2.detect.validateDetectorConfig)
%   C      struct of column vectors (one element per kept candidate component, decreasing strength):
%          u_px, v_px (strength-weighted centroid, 1-based pixel coordinates), area_px, strength
%          (RGB: peak contrast z, dimensionless; thermal: peak |dT| in K), mean_strength, polarity (+1 brighter
%          / warmer than surroundings, -1 darker / cooler), x_m, y_m, z_m (ENU of the centroid ray's first
%          terrain intersection), range_m, gsd_m (ground sample distance range/f), diameter_m (equivalent
%          diameter on the ground), sigma_m (1-sigma horizontal georegistration uncertainty model).
%   Features:
%     RGB      per-channel residual R_c = I_c - masked box mean (window_px), scaled by the frame's robust spread
%              1.4826 * MAD(R_c); z = sqrt(mean_c (R_c / s_c)^2). Candidate pixel: z > z_threshold.
%     thermal  dT = T - masked box mean (window_px) in K. Candidate pixel: |dT| > dT_threshold_K.
%   Pixels whose box contains < min_support_fraction valid pixels are not candidates (edge/occlusion guard).
%   Georegistration uses the sample's OWN intrinsics (focal_lengths_px, principal_point_px) and extrinsics
%   (T_world_sensor at the sample's pose) with mgv2.scene.pixelRays + mgv2.scene.intersectTerrain on the
%   public terrain. A centroid ray that misses the terrain drops the candidate (no fabricated location).
%   sigma_m = sqrt(gsd^2 (1/12 + 1/(4 pi)) + pose_sigma_m^2 + (0.1 m * tan(off-nadir))^2): declared model of centroid
%   quantisation, the assumed pose term and a 0.1 m surface-height parallax term; NOT a calibrated error.
isRgb = s.sensor_id == "RGB_NADIR";
vars = {'u_px','v_px','area_px','strength','mean_strength','polarity','x_m','y_m','z_m','range_m','gsd_m','diameter_m','sigma_m'};
C = cell2struct(repmat({zeros(0, 1)}, 1, numel(vars)), vars, 2);
if ~s.valid, return; end
m = s.valid_pixel_mask;
if isRgb
    p = cfg.rgb; I = double(s.image_rgb_uint8) / 255; [H, W, ~] = size(I);
    [mu, sup] = boxMean(I, m, p.window_px); R = I - mu; z2 = zeros(H, W); lum = zeros(H, W); lw = [0.2126 0.7152 0.0722];
    for c = 1:3
        r = R(:,:,c); v = r(m & sup >= p.min_support_fraction); v = v(1:4:end);   % every 4th pixel: robust spread
        sc = max(1.4826 * median(abs(v - median(v))), 2 / 255);
        z2 = z2 + (r / sc) .^ 2; lum = lum + lw(c) * r;
    end
    F = sqrt(z2 / 3); sgn = sign(lum); cand = m & sup >= p.min_support_fraction & F > p.z_threshold;
else
    p = cfg.thermal; T = s.temperature_K; T(~m) = 0; [H, W] = size(T);
    [mu, sup] = boxMean(T, m, p.window_px); dT = T - mu; dT(~m) = 0;
    F = abs(dT); sgn = sign(dT); cand = m & sup >= p.min_support_fraction & F > p.dT_threshold_K;
end
[L, n] = mgv2.detect.labelComponents(cand);
if n == 0, return; end
idx = find(L); lab = L(idx); w = F(idx); [vv, uu] = ind2sub([H W], idx);
area = accumarray(lab, 1); sw = accumarray(lab, w);
u = accumarray(lab, w .* uu) ./ sw; v = accumarray(lab, w .* vv) ./ sw;
pk = accumarray(lab, w, [], @max); mn = sw ./ area; pol = sign(accumarray(lab, sgn(idx) .* w));
cam = struct('fx', s.focal_lengths_px(1), 'fy', s.focal_lengths_px(2), 'cx', s.principal_point_px(1), 'cy', s.principal_point_px(2));
% size prefilter with a generous nadir GSD bound (0.5x..2x), exact size test after georegistration
Tw = s.T_world_sensor; h0 = Tw(3,4) - mgv2.scene.heightAt(world, Tw(1,4), Tw(2,4)); g0 = h0 / cam.fx;
d0 = 2 * sqrt(area / pi) * g0;
pre = find(isfinite(d0) & d0 >= 0.5 * cfg.size.min_diameter_m & d0 <= 2 * cfg.size.max_diameter_m);
if ~isfinite(h0), pre = (1:n)'; end
[~, o2] = sort(pk(pre), 'descend'); ord = reshape(pre(o2(1:min(numel(pre), cfg.size.max_candidates_per_frame))), [], 1);
if isempty(ord), return; end
[O, D] = mgv2.scene.pixelRays(cam, s.T_world_sensor, [u(ord) v(ord)]);
[P, hit, rng] = mgv2.detect.georegisterRays(world, O, D);
gsd = rng / cam.fx; dia = 2 * sqrt(area(ord) / pi) .* gsd;
offn = acos(min(max(-D(:,3), -1), 1));                      % off-nadir angle of the centroid ray
sig = sqrt(gsd .^ 2 .* (1 / 12 + 1 ./ (4 * pi)) + cfg.association.pose_sigma_m ^ 2 + (0.1 * tan(offn)) .^ 2);
keep = hit & dia >= cfg.size.min_diameter_m & dia <= cfg.size.max_diameter_m;
o = ord(keep);
vals = {u(o), v(o), area(o), pk(o), mn(o), pol(o), P(keep,1), P(keep,2), P(keep,3), rng(keep), gsd(keep), dia(keep), sig(keep)};
C = cell2struct(vals, vars, 2);
end

function [mu, sup] = boxMean(A, m, w)
% masked separable box mean; sup = fraction of valid pixels in the box
k = ones(1, w) / w; md = double(m);
den = conv2(k, k, md, 'same'); sup = den;
mu = zeros(size(A));
for c = 1:size(A, 3)
    a = A(:,:,c); a(~m) = 0;
    mu(:,:,c) = conv2(k, k, a, 'same') ./ max(den, eps);
end
end
