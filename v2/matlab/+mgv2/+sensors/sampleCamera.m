function s = sampleCamera(sc, cfg, mission, pose, seq)
%SAMPLECAMERA RGB_NADIR or THERMAL_LWIR frame from the shared scene at one immutable pose (V2-005).
%   s = mgv2.sensors.sampleCamera(sc, cfg, mission, pose, seq)
%   Geometry: mgv2.sensors.rasterView (exact visible surface per pixel, occlusion by terrain/objects).
%   RGB (uint8): DN = 255 * exposure * albedo * (ambient + (1-ambient) * irradiance/850 * max(0, n.s)),
%     albedo from mgv2.scene.albedoAt (terrain, landmarks) or the object colour; + Gaussian read/shot noise.
%   THERMAL (double K, APPARENT): surface T_s and emissivity from the private forward model
%     (mgv2.sensors.thermalSurface); broadband Stefan-Boltzmann proxy
%     L = tau [eps sigma T_s^4 + (1-eps) sigma T_refl^4] + (1-tau) sigma T_atm^4, tau = exp(-k r),
%     T_app = (L/sigma)^(1/4); then a Gaussian PSF (mask-normalised) and NETD-like white noise.
%     NOT a calibrated 8-14 um camera (V2-004 §2.5). Invalid pixels are NaN with mask = false.
%   Noise uses the sensor's own stream, substream = seq + 1 (mgv2.sensors.sensorStream).
isRgb = cfg.sensor_id == "RGB_NADIR"; cam = cfg.mount; prm = cfg.params; env = sc.env;
W = cam.width_px; H = cam.height_px;
rs = mgv2.sensors.sensorStream(mission.seed, mission.scenario_id, cfg.sensor_id, double(seq) + 1);
[reason, T_ws] = framePrecheck(cfg, pose, rs);
mask = false(H, W); corners = nan(4, 3); cornerOk = false(4, 1); fp = zeros(0, 2);
if isRgb, img = zeros(H, W, 3, 'uint8'); else, img = nan(H, W); end
qual = struct('valid_pixel_fraction', 0, 'object_pixel_fraction', 0, 'stats_available', false);
if reason == "NONE"
    hit = mgv2.sensors.rasterView(sc, cam, T_ws, cfg.valid_range_m(2));
    ok = reshape(isfinite(hit.t) & hit.t >= cfg.valid_range_m(1), H, W);
    k = find(ok); obj = hit.obj(k); fc = hit.face(k); ter = hit.kind(k) == 1; P = hit.P(k, :); Nn = hit.N(k, :);
    sunv = sc.thermal.sun_vector; inc = max(0, Nn * sunv');
    if isRgb
        alb = zeros(numel(k), 3);
        alb(ter, :) = vertexInterp(sc, hit, k, ter, sc.world.vertex_rgb, @(Q) mgv2.scene.albedoAt(sc.world, Q(:,1), Q(:,2)));
        alb = paintLandmarks(sc.world, P, alb);
        if ~isempty(sc.features), alb(ter, :) = featureAlbedo(sc.features, P(ter, :), alb(ter, :)); end
        if any(~ter), rgbM = vertcat(sc.objects.rgb); alb(~ter, :) = rgbM(obj(~ter), :); end
        light = prm.ambient_fraction + (1 - prm.ambient_fraction) * env.irradiance_W_m2 / 850 * inc;
        dn = 255 * prm.exposure_proxy * alb .* light;
        sig = sqrt(prm.read_noise_dn^2 + prm.shot_gain_dn * max(dn, 0));
        dn = dn + sig .* randn(rs, size(dn));
        sat = mean(any(dn >= 255, 2));
        ch = zeros(H * W, 3); ch(k, :) = min(max(round(dn), 0), 255);
        img = reshape(uint8(ch), H, W, 3);
        qual = struct('valid_pixel_fraction', mean(ok(:)), 'object_pixel_fraction', mean(hit.kind == 2), ...
            'saturated_fraction', sat, 'mean_dn', mean(double(ch(k, :)), 'all'), 'stats_available', true);
    else
        th = sc.thermal; sigma = 5.670374419e-8;
        Ts = zeros(numel(k), 1); ep = zeros(numel(k), 1);
        Ts(ter) = vertexInterp(sc, hit, k, ter, th.vertex_T_K, @(Q) terrainThermal(sc, Q));
        ep(ter) = vertexInterp(sc, hit, k, ter, th.vertex_eps, @(Q) terrainEps(sc, Q));
        ep = paintEmissivity(sc, P, ep);
        if ~isempty(sc.features), [Ts(ter), ep(ter)] = featureThermal(sc.features, P(ter, :), Ts(ter), ep(ter)); end
        for ob = unique(obj(~ter))'                       % temperature of the exact face that was hit
            j = find(~ter & obj == ob); Tf = th.object_face_T_K{ob};
            Ts(j) = Tf(fc(j)); ep(j) = th.object_eps(ob);
        end
        tau = exp(-env.extinction_per_m * hit.t(k));
        L = tau .* (ep * sigma .* Ts.^4 + (1 - ep) * sigma * env.reflected_K^4) + (1 - tau) * sigma * env.atm_K^4;
        Ta = nan(H, W); Ta(k) = (L / sigma) .^ 0.25;
        g = exp(-((-1:1).^2) / (2 * prm.psf_sigma_px^2)); g = g' * g; g = g / sum(g(:));
        num = conv2(fillmissing0(Ta), g, 'same'); den = conv2(double(ok), g, 'same');
        Tb = num ./ den; Tb(~ok) = NaN;
        img = Tb + prm.netd_K * randn(rs, H, W); img(~ok) = NaN;
        qual = struct('valid_pixel_fraction', mean(ok(:)), 'object_pixel_fraction', mean(hit.kind == 2), ...
            'min_K', min(img(ok)), 'max_K', max(img(ok)), 'mean_K', mean(img(ok)), 'stats_available', true);
    end
    mask = ok;
    uvc = [0.5 0.5; W + 0.5 0.5; W + 0.5 H + 0.5; 0.5 H + 0.5];       % image corners (as mgv2.scene.cameraFootprint)
    [Oc, Dc] = mgv2.scene.pixelRays(cam, T_ws, uvc); hc = mgv2.sensors.castRays(sc, Oc, Dc, cfg.valid_range_m(2));
    corners = hc.P; cornerOk = isfinite(hc.t);
    if all(cornerOk), fp = corners(:, 1:2); end
    if mean(ok(:)) < prm.min_valid_fraction, reason = "NO_INTERSECTION"; end
end
valid = reason == "NONE";
s = mgv2.sensors.makeEnvelope(mission, cfg, pose, seq, valid, reason, "sensor", fp, qual);
Kc = cam.K;
if isRgb
    s.image_rgb_uint8 = img; s.valid_pixel_mask = mask; s.image_height = H; s.image_width = W; s.K = Kc;
    s.focal_lengths_px = [cam.fx cam.fy]; s.principal_point_px = [cam.cx cam.cy]; s.fov_h_deg = cam.hfov_deg;
    s.distortion = cam.distortion; s.T_body_sensor = cam.T_body_sensor; s.T_world_sensor = T_ws;
    s.exposure_proxy = prm.exposure_proxy; s.lighting_mode = env.mode;
    s.noise_parameters = struct('read_noise_dn', prm.read_noise_dn, 'shot_gain_dn', prm.shot_gain_dn);
    s.source_model_version = cfg.model_version; s.corner_hits_enu_m = corners; s.corner_valid = cornerOk;
else
    s.temperature_K = img; s.temperature_kind = "APPARENT"; s.valid_pixel_mask = mask; s.image_height = H; s.image_width = W;
    s.simulated_temperature_uncertainty_K = prm.netd_K; s.emissivity_assumed = "per-material (0.90-0.98), see model doc";
    s.atmosphere_transmittance_assumed = sprintf("exp(-%.4f * range_m)", env.extinction_per_m);
    s.reflected_temperature_K = env.reflected_K; s.ambient_temperature_K = env.ambient_K;
    if any(mask(:)), s.display_min_K = min(img(mask)); s.display_max_K = max(img(mask)); else, s.display_min_K = NaN; s.display_max_K = NaN; end
    s.palette_id = prm.palette_id; s.K = Kc; s.focal_lengths_px = [cam.fx cam.fy]; s.principal_point_px = [cam.cx cam.cy];
    s.fov_h_deg = cam.hfov_deg; s.T_body_sensor = cam.T_body_sensor; s.T_world_sensor = T_ws;
end
end

function v = vertexInterp(~, hit, k, ter, field, pointQuery)
% exact barycentric interpolation of a per-vertex field on the drawn triangle that the raster found;
% pixels without raster barycentrics (ray-cast fallback) use the point query on the same triangles
ii = k(ter); tv = hit.tri_vertices(ii, :); b = hit.bary(ii, :);
v = zeros(numel(ii), size(field, 2)); have = all(tv > 0, 2) & all(isfinite(b), 2);
v(have, :) = b(have,1) .* field(tv(have,1), :) + b(have,2) .* field(tv(have,2), :) + b(have,3) .* field(tv(have,3), :);
if any(~have), v(~have, :) = pointQuery(hit.P(ii(~have), :)); end
end

function alb = paintLandmarks(w, P, alb)
for q = 1:numel(w.landmarks)
    L = w.landmarks(q); c = abs(P(:,1) - L.xy(1)) <= L.radius_m & abs(P(:,2) - L.xy(2)) <= L.radius_m;
    c(c) = hypot(P(c,1) - L.xy(1), P(c,2) - L.xy(2)) <= L.radius_m; alb(c, :) = repmat(L.color, nnz(c), 1);
end
end

function ep = paintEmissivity(sc, P, ep)
w = sc.world;
for q = 1:numel(w.landmarks)
    L = w.landmarks(q); c = abs(P(:,1) - L.xy(1)) <= L.radius_m & abs(P(:,2) - L.xy(2)) <= L.radius_m;
    c(c) = hypot(P(c,1) - L.xy(1), P(c,2) - L.xy(2)) <= L.radius_m; ep(c) = sc.thermal.landmark_eps;
end
end

function ep = terrainEps(sc, P)
[~, ep] = terrainThermal(sc, P);
end

function [Ts, ep] = terrainThermal(sc, P)
% barycentric interpolation of the private per-vertex surface temperature/emissivity on the drawn triangles
w = sc.world; th = sc.thermal; gx = w.x; gy = w.y; d = gx(2) - gx(1); ny = numel(gy);
j = min(max(floor((P(:,1) - gx(1)) / d) + 1, 1), numel(gx) - 1); i = min(max(floor((P(:,2) - gy(1)) / d) + 1, 1), ny - 1);
u = (P(:,1) - gx(j)') / d; v = (P(:,2) - gy(i)') / d;
i00 = i + (j - 1) * ny; i10 = i + j * ny; i01 = i + 1 + (j - 1) * ny; i11 = i + 1 + j * ny;
lo = u >= v; F = {th.vertex_T_K, th.vertex_eps}; out = cell(1, 2);
for q = 1:2
    f = F{q}; o = f(i00) + u .* (f(i11) - f(i01)) + v .* (f(i01) - f(i00));
    o(lo) = f(i00(lo)) + u(lo) .* (f(i10(lo)) - f(i00(lo))) + v(lo) .* (f(i11(lo)) - f(i10(lo)));
    out{q} = o;
end
Ts = out{1}; ep = out{2};
for k = 1:numel(w.landmarks)          % painted calibration discs: emissivity of paint, same substrate temperature
    L = w.landmarks(k); in = hypot(P(:,1) - L.xy(1), P(:,2) - L.xy(2)) <= L.radius_m; ep(in) = th.landmark_eps;
end
end

function A = fillmissing0(A), A(isnan(A)) = 0; end

function w = featureWeight(f, P)
% smooth disc weight: 1 inside radius - edge/2, 0 outside radius + edge/2 (smoothstep)
d = hypot(P(:,1) - f.center_enu_m(1), P(:,2) - f.center_enu_m(2));
u = min(max((f.radius_m + f.edge_m / 2 - d) / f.edge_m, 0), 1); w = u .^ 2 .* (3 - 2 * u);
end

function alb = featureAlbedo(F, P, alb)
% PRIVATE forward model (V2-006 hook): flat surface features blend the terrain albedo (terrain pixels only)
for q = 1:numel(F)
    w = F(q).albedo_mix * featureWeight(F(q), P); j = w > 0;
    alb(j, :) = (1 - w(j)) .* alb(j, :) + w(j) .* F(q).albedo_rgb;
end
end

function [Ts, ep] = featureThermal(F, P, Ts, ep)
% PRIVATE forward model (V2-006 hook): surface temperature change and optional emissivity of flat features
for q = 1:numel(F)
    w = featureWeight(F(q), P); j = w > 0;
    Ts(j) = Ts(j) + w(j) * F(q).delta_T_K;
    if ~isnan(F(q).emissivity), ep(j) = (1 - w(j)) .* ep(j) + w(j) * F(q).emissivity; end
end
end

function [reason, T_ws] = framePrecheck(cfg, pose, rs)
reason = "NONE"; T_ws = nan(4);
p = pose.position_enu_m; q = pose.orientation_quat;
if ~(all(isfinite(p)) && all(isfinite(q)) && abs(norm(q) - 1) < 1e-6), reason = "INVALID_POSE"; return; end
T_ws = mgv2.scene.sensorPose(pose, cfg.mount);
dm = cfg.dropout_model; u = rand(rs);                     % first draw of the sample stream: dropout
if any(pose.t_s >= dm.intervals_s(:,1) & pose.t_s <= dm.intervals_s(:,2)) || u < dm.frame_probability
    reason = "SENSOR_DROPOUT";
end
end
