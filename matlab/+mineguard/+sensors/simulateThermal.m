function samples = simulateThermal(config, scenario, poses)
%SIMULATETHERMAL Synthetic nadir thermal observations (mg-contract/1.0, MG-007).
%   samples = mineguard.sensors.simulateThermal(config, scenario, poses)
%
%   PHENOMENOLOGICAL PROXY, not a heat-equation solver and not calibrated to any camera
%   (docs/MG006_SENSOR_PHYSICS_AND_TESTS.md Section 4). For each pose:
%     T = T_background + sum_i A * g_i * exp(-depth_i / L_depth) * phase(t) * w_i + eps
%       A        contrast_amplitude_K (signed; 0 is the required negative control)
%       g_i      material_contrast_lookup.(material_i) (signed, dimensionless; clutter such
%                as a hot rock may exceed a target)
%       L_depth  thermal_depth_scale_m (assumed suppression with burial depth)
%       phase    1 for diurnal_mode "static"; for "cosine",
%                cos(2*pi*(time_of_day_s + t_s - contrast_peak_time_s)/86400), so the
%                contrast can warm, vanish or invert with time
%       w_i      fraction of the camera footprint disc (radius standoff*tan(half FOV))
%                covered by an object disc of radius thermal_object_radius_m. This is
%                footprint dilution, bounded [0,1].
%       eps      N(0, thermal_noise_sigma_K^2) drawn from RandStream(environment.rng.thermal_seed)
%   Hidden truth is read only inside this forward model. The returned table has exactly
%   the 11 SensorSample columns and no label, ID, coordinate or material of any object.
%   Invalid rows keep their ID and timestamp, with temperature_K = NaN and invalid_reason
%   one of UNCONFIGURED_SENSOR | POSE_INVALID | DROPPED_SAMPLE | MODEL_OUT_OF_DOMAIN.
%   Not modelled: moisture transport, emissivity, sun/shadow, wind, radiometric optics.
[ch, ctx] = prepareSensorRun(config, scenario, poses, "thermal");
samples = sampleTable(ctx, "thermal", "TH");
if isempty(ch)
    samples.invalid_reason(:) = "UNCONFIGURED_SENSOR";
    return
end
c = "thermal";
Tb    = requireParam(ch, c, 'background_temperature_K', "positive");
A     = requireParam(ch, c, 'contrast_amplitude_K', "finite");
L     = requireParam(ch, c, 'thermal_depth_scale_m', "positive");
fov   = requireParam(ch, c, 'camera_half_fov_rad', "halfangle");
sigma = requireParam(ch, c, 'thermal_noise_sigma_K', "nonneg");
a     = requireParam(ch, c, 'thermal_object_radius_m', "positive");
tod   = requireParam(ch, c, 'time_of_day_s', "finite");
mode  = requireParam(ch, c, 'diurnal_mode', "text");
requireParam(ch, c, 'model_version', "text");
if ~ismember(mode, ["static","cosine"])
    error('mineguard:InvalidSensorConfig', 'MineGuard sensors: sensor_settings.thermal.diurnal_mode must be "static" or "cosine".');
end
if ~isfield(ch, 'material_contrast_lookup')
    error('mineguard:InvalidSensorConfig', 'MineGuard sensors: sensor_settings.thermal.material_contrast_lookup is required.');
end
truth = ctx.truth;
gain = lookupGain(ch.material_contrast_lookup, truth.material_type, c, 'material_contrast_lookup');
depthFactor = exp(-truth.burial_depth_m / L);

% Fixed draw order (uniform draws, then normal draws) so the masks and noise reproduce exactly.
stream = RandStream('mt19937ar', 'Seed', ctx.seed);
u = rand(stream, ctx.n, 1);
e = randn(stream, ctx.n, 1);

if mode == "cosine"
    tPeak = requireParam(ch, c, 'contrast_peak_time_s', "finite");
    phase = cos(2 * pi * (tod + ctx.t - tPeak) / 86400);
else
    phase = ones(ctx.n, 1);
end

R = ctx.standoff * tan(fov);
dT = zeros(ctx.n, 1);
for k = find(ctx.poseOk)'
    if ~isempty(truth)
        d = hypot(truth.x_east_m - ctx.x(k), truth.y_north_m - ctx.y(k));
        w = discOverlapFraction(R(k), a, d);
        dT(k) = A * phase(k) * sum(gain .* depthFactor .* w);
    end
end
T = Tb + dT + sigma * e;

drop = dropoutMask(ch, c, ctx.ids, u);
reason = strings(ctx.n, 1);
reason(~ctx.poseOk) = "POSE_INVALID";
reason(ctx.poseOk & drop) = "DROPPED_SAMPLE";
reason(reason == "" & ~(T > 0)) = "MODEL_OUT_OF_DOMAIN";   % nonphysical kelvin value
valid = reason == "";

samples.temperature_K(valid) = T(valid);
samples.noise_sigma(:) = sigma;
samples.standoff_m(ctx.poseOk) = ctx.standoff(ctx.poseOk);
samples.footprint_radius_m(ctx.poseOk) = R(ctx.poseOk);
samples.valid = valid;
samples.invalid_reason = reason;
end
