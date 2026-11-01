function sc = thermalSurface(sc)
%THERMALSURFACE Private per-vertex / per-face SURFACE temperature [K] and emissivity (forward model only).
%   sc = mgv2.sensors.thermalSurface(sc)       adds sc.thermal (never part of a public sample)
%   Quasi-steady linearised surface energy balance per material (documented approximation, not a
%   calibrated heat-transfer model):
%     T_s = T_air + g_m * ( a * E * max(0, n . s) - eps * sigma * (T_air^4 - T_sky^4) ) / (h_c + h_r) - M(x,y)
%   a = solar absorptance = 1 - luminance(albedo) (clamped 0.2..0.95), E = irradiance, s = sun vector,
%   h_c = 5 + 4*wind [W/m^2K] (convective), h_r = 4 eps sigma T_air^3 (linearised radiative),
%   g_m = material damping factor standing in for thermal inertia / transpiration, M = seeded smooth
%   moisture (evaporative cooling) nuisance field of amplitude env.moisture_amp_K.
%   Emissivities and g_m below are ASSUMED literature-typical magnitudes, not measured values.
env = sc.env; w = sc.world; sigma = 5.670374419e-8;
mat = struct('name', ["grass","soil","dry_grass","concrete_pad"], 'eps', [0.98 0.95 0.96 0.92], 'g', [0.45 0.85 0.95 0.75]);
objMat = struct('rock', [0.93 0.60], 'bush', [0.98 0.30], 'marker', [0.90 0.80]);   % [eps g]
s = sunVector(env);
hc = 5 + 4 * env.wind_mps;
% terrain vertices
[gx, gy] = gradient(w.Z, w.x(2) - w.x(1));
n = [-gx(:), -gy(:), ones(numel(w.Z), 1)]; n = n ./ vecnorm(n, 2, 2);
lum = w.vertex_rgb * [0.2126; 0.7152; 0.0722]; a = min(max(1 - lum, 0.2), 0.95);
Wm = w.material_weights; epsV = Wm * mat.eps'; gV = Wm * mat.g';
inc = max(0, n * s');
hr = 4 * epsV * sigma * env.ambient_K^3;
lw = epsV * sigma * (env.ambient_K^4 - env.sky_K^4);
M = moisture(env, w.V(:,1), w.V(:,2));
Tv = env.ambient_K + gV .* (a * env.irradiance_W_m2 .* inc - lw) ./ (hc + hr) - M;
% objects (per face)
objT = cell(numel(sc.objects), 1); objE = zeros(numel(sc.objects), 1);
for k = 1:numel(sc.objects)
    ob = sc.objects(k); p = objMat.(char(ob.kind));
    ao = min(max(1 - ob.rgb * [0.2126; 0.7152; 0.0722], 0.2), 0.95);
    hro = 4 * p(1) * sigma * env.ambient_K^3; lwo = p(1) * sigma * (env.ambient_K^4 - env.sky_K^4);
    objT{k} = env.ambient_K + p(2) * (ao * env.irradiance_W_m2 * max(0, ob.N * s') - lwo) / (hc + hro);
    objE(k) = p(1);
end
sc.thermal = struct('vertex_T_K', Tv, 'vertex_eps', epsV, 'object_face_T_K', {objT}, 'object_eps', objE, ...
    'landmark_eps', 0.90, 'sun_vector', s, 'model', "linearised-energy-balance-v1", 'private', true);
end

function s = sunVector(env)
az = deg2rad(env.sun_azimuth_deg); el = deg2rad(env.sun_elevation_deg);
s = [sin(az) * cos(el), cos(az) * cos(el), sin(el)];          % ENU, azimuth clockwise from North
end

function M = moisture(env, x, y)
rs = RandStream('mrg32k3a', 'Seed', env.moisture_seed); M = zeros(size(x));
for k = 1:6
    lam = 12 + 40 * rand(rs); th = 2 * pi * rand(rs); ph = 2 * pi * rand(rs);
    M = M + sin(2 * pi * (cos(th) * x + sin(th) * y) / lam + ph) / 6;
end
M = env.moisture_amp_K * max(M, 0) * 2;
end
