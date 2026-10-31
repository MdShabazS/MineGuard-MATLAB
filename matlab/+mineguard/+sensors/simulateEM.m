function samples = simulateEM(config, scenario, poses)
%SIMULATEEM Synthetic normalized EM-coil observations (mg-contract/1.0, MG-007).
%   samples = mineguard.sensors.simulateEM(config, scenario, poses)
%
%   em_model_kind must be "phenomenological_em_proxy" (docs/MG006 Section 5). This is an
%   illustrative, NON-CALIBRATED proxy, not a model of any real metal detector:
%     d_i = sqrt(dx_i^2 + dy_i^2 + (standoff + burial_depth_i)^2)
%     f(d) = 1 / (1 + (d / em_distance_scale_m)^em_falloff_exponent)   (bounded, non-increasing)
%     response_norm = em_background_norm + sum_i G_i * f(d_i) + interference + eps
%       G_i   material_response_lookup.(material_i). Nonmetallic surrogates must be 0, and
%             unknown materials are rejected (never assumed metallic).
%       interference  optional em_interference_norm (constant offset; off when absent)
%       eps   N(0, em_noise_sigma_norm^2) drawn from RandStream(environment.rng.em_seed)
%   standoff is coil-to-ground clearance. Burial depth only adds separation, so a higher
%   coil can never get a stronger deterministic signal. When standoff exceeds
%   em_model_max_standoff_m (a declared modelling cutoff, not an empirical range), the
%   reading is invalid with MODEL_OUT_OF_DOMAIN and NaN, never 0. No detection threshold
%   is applied here (that belongs to MG-008/MG-009). footprint_radius_m reports the assumed
%   em_footprint_radius_m support; it is not a detection range. The output carries no truth.
[ch, ctx] = prepareSensorRun(config, scenario, poses, "em");
samples = sampleTable(ctx, "em", "EM");
if isempty(ch)
    samples.invalid_reason(:) = "UNCONFIGURED_SENSOR";
    return
end
c = "em";
kind  = requireParam(ch, c, 'em_model_kind', "text");
if kind ~= "phenomenological_em_proxy"
    error('mineguard:InvalidSensorConfig', 'MineGuard sensors: sensor_settings.em.em_model_kind must be "phenomenological_em_proxy".');
end
d0    = requireParam(ch, c, 'em_distance_scale_m', "positive");
p     = requireParam(ch, c, 'em_falloff_exponent', "positive");
sigma = requireParam(ch, c, 'em_noise_sigma_norm', "nonneg");
bg    = requireParam(ch, c, 'em_background_norm', "finite");
hMax  = requireParam(ch, c, 'em_model_max_standoff_m', "positive");
rFoot = requireParam(ch, c, 'em_footprint_radius_m', "nonneg");
requireParam(ch, c, 'coil_geometry_note', "text");
requireParam(ch, c, 'model_version', "text");
interference = 0;
if isfield(ch, 'em_interference_norm')
    interference = requireParam(ch, c, 'em_interference_norm', "finite");
end
if ~isfield(ch, 'material_response_lookup')
    error('mineguard:InvalidSensorConfig', 'MineGuard sensors: sensor_settings.em.material_response_lookup is required.');
end
truth = ctx.truth;
G = lookupGain(ch.material_response_lookup, truth.material_type, c, 'material_response_lookup');

stream = RandStream('mt19937ar', 'Seed', ctx.seed);
u = rand(stream, ctx.n, 1);
e = randn(stream, ctx.n, 1);

inDomain = ctx.poseOk & ctx.standoff <= hMax;
r = zeros(ctx.n, 1);
for k = find(inDomain)'
    if ~isempty(truth)
        d = sqrt((truth.x_east_m - ctx.x(k)).^2 + (truth.y_north_m - ctx.y(k)).^2 + ...
                 (ctx.standoff(k) + truth.burial_depth_m).^2);
        r(k) = sum(G ./ (1 + (d / d0).^p));
    end
end
resp = bg + r + interference + sigma * e;

drop = dropoutMask(ch, c, ctx.ids, u);
reason = strings(ctx.n, 1);
reason(~ctx.poseOk) = "POSE_INVALID";
reason(ctx.poseOk & ~inDomain) = "MODEL_OUT_OF_DOMAIN";
reason(inDomain & drop) = "DROPPED_SAMPLE";
valid = reason == "";

samples.response_norm(valid) = resp(valid);
samples.noise_sigma(:) = sigma;
samples.standoff_m(ctx.poseOk) = ctx.standoff(ctx.poseOk);
samples.footprint_radius_m(ctx.poseOk) = rFoot;
samples.valid = valid;
samples.invalid_reason = reason;
end
