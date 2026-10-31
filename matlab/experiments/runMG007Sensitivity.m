function out = runMG007Sensitivity(csvFolder)
%RUNMG007SENSITIVITY S-14 sensitivity sweeps for the MG-007 synthetic sensor proxies.
%   out = runMG007Sensitivity()           returns the sweep tables
%   out = runMG007Sensitivity(csvFolder)  also writes one CSV per sweep
%   Single synthetic object at (10,10) m in a flat 20x20 m S0 field. The sensor is
%   directly above it unless an offset is stated. Noise is off except in the noise sweep.
%   These are MODEL OUTPUTS under assumed parameters, not measured sensor behaviour.
base = baseCase();

% 1) Thermal contrast and EM signal vs burial depth (0.5 m standoff).
depth = [0 0.02 0.05 0.1 0.2 0.3 0.5]';
dT = zeros(size(depth)); emR = zeros(size(depth));
for k = 1:numel(depth)
    [c, s] = setup(base, depth(k), "synthetic_metal_cased_surrogate", 0, 0);
    p = poseRows([10 10 0.5]);
    th = mineguard.sensors.simulateThermal(c, s, p);
    em = mineguard.sensors.simulateEM(c, s, p);
    dT(k) = th.temperature_K - c.sensor_settings.thermal.background_temperature_K;
    emR(k) = em.response_norm - c.sensor_settings.em.em_background_norm;
end
out.depth = table(depth, dT, emR, 'VariableNames', {'burial_depth_m','thermal_contrast_K_at_0p5m','em_signal_norm_at_0p5m'});

% 2) Clearance (standoff) sweep: thermal footprint dilution and EM falloff / domain.
h = [0.05 0.2 0.5 1 2 5]';
[c, s] = setup(base, 0.05, "synthetic_metal_cased_surrogate", 0, 0);
p = poseRows([repmat([10 10], numel(h), 1) h]);
th = mineguard.sensors.simulateThermal(c, s, p);
em = mineguard.sensors.simulateEM(c, s, p);
out.clearance = table(h, th.footprint_radius_m, th.temperature_K - 293.15, em.response_norm - 0.05, em.valid, em.invalid_reason, ...
    'VariableNames', {'standoff_m','thermal_footprint_radius_m','thermal_contrast_K','em_signal_norm','em_valid','em_invalid_reason'});

% 3) Footprint (half-FOV) sweep at 2 m standoff, depth 0.
fov = [0.05 0.1 0.2 0.35 0.5 0.8]';
dTf = zeros(size(fov)); Rf = zeros(size(fov));
for k = 1:numel(fov)
    [c, s] = setup(base, 0, "synthetic_metal_cased_surrogate", 0, 0);
    c.sensor_settings.thermal.camera_half_fov_rad = fov(k);
    th = mineguard.sensors.simulateThermal(c, s, poseRows([10 10 2]));
    dTf(k) = th.temperature_K - 293.15; Rf(k) = th.footprint_radius_m;
end
out.footprint = table(fov, Rf, dTf, 'VariableNames', {'camera_half_fov_rad','footprint_radius_m','thermal_contrast_K'});

% 4) Noise sweep: empirical std over 2000 background-only poses (empty field).
sig = [0 0.05 0.1 0.5]';
thStd = zeros(size(sig)); emStd = zeros(size(sig));
grid = [10 + 0.001*(1:2000)' repmat(5, 2000, 1) ones(2000, 1)];
for k = 1:numel(sig)
    [c, s] = setup(base, [], "", sig(k), sig(k));
    p = poseRows(grid);
    thStd(k) = std(mineguard.sensors.simulateThermal(c, s, p).temperature_K);
    emStd(k) = std(mineguard.sensors.simulateEM(c, s, p).response_norm);
end
out.noise = table(sig, thStd, emStd, 'VariableNames', {'configured_sigma','thermal_empirical_std_K','em_empirical_std_norm'});

% 5) Dropout-probability sweep: realised invalid fraction over 2000 poses.
pd = [0 0.1 0.3 0.5]';
fr = zeros(size(pd));
for k = 1:numel(pd)
    [c, s] = setup(base, [], "", 0, 0);
    c.sensor_settings.thermal.dropout_probability = pd(k);
    fr(k) = mean(~mineguard.sensors.simulateThermal(c, s, poseRows(grid)).valid);
end
out.dropout = table(pd, fr, 'VariableNames', {'dropout_probability','thermal_invalid_fraction'});

if nargin >= 1
    names = fieldnames(out);
    for k = 1:numel(names)
        writetable(out.(names{k}), fullfile(csvFolder, "MG-007-sensitivity-" + names{k} + ".csv"));
    end
end
end

function b = baseCase()
b.config = struct('schema_version', "mg-contract/1.0", 'scenario_id', "S0-mg007-sweep", ...
    'seed', 42, 'x_min_m', 0, 'x_max_m', 20, 'y_min_m', 0, 'y_max_m', 20, ...
    'terrain_id', "flat-datum", 'grid_spacing_m', 1, 'dt_s', 0.1, 'sampling_hz', 10, ...
    'altitude_m', 1, 'speed_mps', 1, 'noise_seed', 7, 'target_count', 0, 'clutter_count', 0, ...
    'min_separation_m', 0.5, 'soil_class', "synthetic_loam", 'model_version', "mg007-0.1");
b.config.sensor_settings = mg007FixtureSettings();
end

function [c, s] = setup(b, depth, material, thSigma, emSigma)
c = b.config;
c.sensor_settings.thermal.thermal_noise_sigma_K = thSigma;
c.sensor_settings.em.em_noise_sigma_norm = emSigma;
[g, t, e] = mineguard.scenario.generateScenario(c);
if ~isempty(depth)
    t = table("OBJ-0001", 10, 10, depth, string(material), categorical("target", ["target" "clutter"]), ...
        "synthetic_loam", depth == 0, 'VariableNames', t.Properties.VariableNames);
end
s = struct('config', c, 'geometry', g, 'hidden_truth', t, 'environment', e);
end

function p = poseRows(xyz)
n = size(xyz, 1);
p = table(compose("P-%06d", (1:n)'), (0:n-1)' * 0.1, xyz(:,1), xyz(:,2), xyz(:,3), ...
    'VariableNames', {'pose_sample_id','t_s','x_east_m','y_north_m','z_up_m'});
end
