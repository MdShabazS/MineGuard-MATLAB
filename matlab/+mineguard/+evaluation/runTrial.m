function bundle = runTrial(config, opts)
%RUNTRIAL Generate one synthetic trial: MG-004 scenario, then MG-005 route/poses, then MG-007 sensors.
%   bundle = mineguard.evaluation.runTrial(config)
%   bundle = mineguard.evaluation.runTrial(config, opts)
%     opts.truthTransform  - optional @(truth) -> truth (experiment-level material assignment;
%                            positions and labels must not change)
%     opts.em_pose_stride  - optional integer >= 1; EM is sampled on every k-th pose
%                            (a rate-mismatch / time-skew stress condition)
%   bundle.public     - scenario_id, geometry, poses, samples (thermal and EM vertcat). Contains NO truth.
%   bundle.private    - truth and environment (evaluator / forward-model only)
%   bundle.provenance - schema, scenario ID, seeds (scenario, noise, thermal, EM, navigation),
%                       sensor settings and model versions, plus the config checksum
%   Completed MG-004/005/007 functions are only called here, never modified.
if nargin < 2, opts = struct(); end
[g, t, e] = mineguard.scenario.generateScenario(config);
if isfield(opts, 'truthTransform')
    t2 = opts.truthTransform(t);
    if ~isequal(t2(:, {'target_id','x_east_m','y_north_m','label'}), t(:, {'target_id','x_east_m','y_north_m','label'}))
        error('mineguard:InvalidEvaluationInput', 'MineGuard evaluation: truthTransform may change materials/depths only.');
    end
    t = t2;
end
nav = mineguard.navigation.navigationConfigFromExperiment(config);
route = mineguard.navigation.makeGridRoute(nav, g);
poses = mineguard.navigation.simulatePose(nav, g, route);
scen = struct('config', config, 'geometry', g, 'hidden_truth', t, 'environment', e);
th = mineguard.sensors.simulateThermal(config, scen, poses);
emPoses = poses;
if isfield(opts, 'em_pose_stride') && opts.em_pose_stride > 1
    emPoses = poses(1:opts.em_pose_stride:end, :);
end
em = mineguard.sensors.simulateEM(config, scen, emPoses);
cov = mineguard.navigation.computeCoverage(nav, g, poses);
ss = config.sensor_settings;
bundle.public = struct('scenario_id', string(config.scenario_id), 'geometry', g, 'poses', poses, 'samples', [th; em], ...
    'coverage', cov);
bundle.private = struct('truth', t, 'environment', e);
bundle.provenance = struct( ...
    'schema_version', string(config.schema_version), 'scenario_id', string(config.scenario_id), ...
    'scenario_seed', config.seed, 'noise_seed', config.noise_seed, ...
    'thermal_seed', e.rng.thermal_seed, 'em_seed', e.rng.em_seed, 'navigation_seed', nav.seed, ...
    'sensor_settings_version', string(ss.version), ...
    'thermal_model_version', string(ss.thermal.model_version), 'em_model_version', string(ss.em.model_version), ...
    'em_pose_stride', local_stride(opts), ...
    'config_checksum', mineguard.evaluation.configChecksum(config));
end

function s = local_stride(opts)
s = 1;
if isfield(opts, 'em_pose_stride'), s = opts.em_pose_stride; end
end
