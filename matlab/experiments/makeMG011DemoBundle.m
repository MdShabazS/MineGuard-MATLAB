function [runBundle, ctx] = makeMG011DemoBundle(opts)
%MAKEMG011DEMOBUNDLE Build a REAL redacted replay bundle from a genuine MG-004/005/007/009 run.
%   [runBundle, ctx] = makeMG011DemoBundle()
%   [runBundle, ctx] = makeMG011DemoBundle(opts)
%     opts.seed (default 3001, the MG-009 TEST group MG009-3001), opts.x_max_m / opts.y_max_m
%     (default 10), opts.grid_spacing_m (0.5), opts.speed_mps (2), opts.dropout_probability (0),
%     opts.altitude_m (0.3; e.g. 5 puts every EM reading MODEL_OUT_OF_DOMAIN)
%   Pipeline: MG-009 runTrial (MG-004 scenario, MG-005 route/poses, MG-007 sensors), then the
%   FROZEN MG-009 model tasks/evidence/MG-009/MG-009-frozen-model.json (weighted/single_valid),
%   then detectAnomalies on observables only, then the evaluator scoreDetections (the only step
%   that sees truth; it returns aggregates), then makeRunBundle (allowlisted redaction).
%   The truth table stays inside this function and never reaches the bundle or the app.
%   ctx returns non-bundle context for tests (config, geometry, route, navConfig).
if nargin < 1, opts = struct(); end
d = struct('seed', 3001, 'x_max_m', 10, 'y_max_m', 10, 'grid_spacing_m', 0.5, 'speed_mps', 2, 'dropout_probability', 0, 'altitude_m', 0.3);
f = fieldnames(d);
for k = 1:numel(f), if ~isfield(opts, f{k}), opts.(f{k}) = d.(f{k}); end, end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
c = struct('schema_version', "mg-contract/1.0", 'scenario_id', "MG009-" + opts.seed, 'seed', opts.seed, ...
    'x_min_m', 0, 'x_max_m', opts.x_max_m, 'y_min_m', 0, 'y_max_m', opts.y_max_m, 'terrain_id', "flat-datum", ...
    'grid_spacing_m', opts.grid_spacing_m, 'dt_s', 0.1, 'sampling_hz', 10, 'altitude_m', opts.altitude_m, 'speed_mps', opts.speed_mps, ...
    'noise_seed', opts.seed + 50000, 'target_count', mod(opts.seed, 4), 'clutter_count', mod(opts.seed * 7, 4), ...
    'min_separation_m', 0.5, 'soil_class', "synthetic_loam", 'model_version', "mg009-0.1");
c.sensor_settings = mg007FixtureSettings();
if opts.dropout_probability > 0
    c.sensor_settings.thermal.dropout_probability = opts.dropout_probability;
    c.sensor_settings.em.dropout_probability = opts.dropout_probability;
    c.sensor_settings.version = c.sensor_settings.version + "+dropout";
end
% Same seeded experiment-level material assignment as runMG009Experiment (seed + 777).
tMat = ["synthetic_metal_cased_surrogate","synthetic_cased_surrogate","synthetic_plastic_surrogate"];
cMat = ["synthetic_metal_debris","synthetic_rock","synthetic_root"];
trial = mineguard.evaluation.runTrial(c, struct('truthTransform', @(t) assign(t, opts.seed, tMat, cMat)));

F = jsondecode(fileread(fullfile(root, 'tasks', 'evidence', 'MG-009', 'MG-009-frozen-model.json')));
m = F.model; m.version = string(m.version);
m.provenance.normaliser_split = string(m.provenance.normaliser_split);
m.provenance.threshold_split = string(m.provenance.threshold_split);
dc = struct('schema_version', "mg-contract/1.0", 'scenario_id', c.scenario_id, 'association_tolerance_s', 0.05, ...
    'threshold', F.method_thresholds.weighted, 'method_name', "weighted", 'missing_modality_rule', "single_valid");
events = mineguard.detection.detectAnomalies(dc, trial.public.poses, trial.public.samples, m);

grid = struct('bounds_enu_m', trial.public.geometry.bounds_enu_m, 'grid_spacing_m', c.grid_spacing_m, ...
    'exclusion_polygons_enu_m', {trial.public.geometry.exclusion_polygons_enu_m});
[st, sha] = system(sprintf('git -C "%s" rev-parse --short HEAD', root)); if st ~= 0, sha = "NOT_RECORDED"; end
v = ver; tbx = strjoin(string({v.Name}) + " " + string({v.Version}), "; ");
rm = struct('scenario_id', c.scenario_id, 'grid', grid, 'evaluable_cell_mask', ...
    mineguard.evaluation.evaluableCellMask(grid, trial.public.poses, trial.public.samples, "weighted", "single_valid"), ...
    'algorithm', "weighted/single_valid", 'split_id', "test", 'localization_match_radius_m', 0.75, ...
    'coverage_fraction', trial.public.coverage.coverage_fraction, 'mission_time_s', trial.public.coverage.mission_time_s, ...
    'distance_m', trial.public.coverage.distance_m, 'git_sha', strtrim(string(sha)), 'matlab_release', string(version('-release')), ...
    'toolbox_manifest', tbx);
[result, report] = mineguard.evaluation.scoreDetections(c, events, trial.private.truth, rm);   % evaluator only
trial.private = [];                                                                          % drop truth now

nav = mineguard.navigation.navigationConfigFromExperiment(c);
route = mineguard.navigation.makeGridRoute(nav, trial.public.geometry);
pub = struct('scenario_id', c.scenario_id, 'geometry', trial.public.geometry, 'poses', trial.public.poses, ...
    'samples', trial.public.samples, 'coverage', trial.public.coverage, 'route_enu_m', route);
prov = struct('scenario_id', c.scenario_id, 'seed', c.seed, 'noise_seed', c.noise_seed, 'model_version', c.model_version, ...
    'sensor_settings_version', string(c.sensor_settings.version), 'detector_model_version', m.version, ...
    'method_name', dc.method_name, 'missing_modality_rule', dc.missing_modality_rule, 'threshold', dc.threshold, ...
    'matlab_release', string(version('-release')), 'git_sha', strtrim(string(sha)), ...
    'run_id', "MG011-REPLAY-" + c.scenario_id + "-" + trial.provenance.config_checksum, ...
    'run_timestamp_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
    'toolbox_manifest', tbx, 'split_id', "test", ...
    'simulation_flags', "SYNTHETIC; kinematic MG-005 replay; MG-007 assumed sensor parameters; frozen MG-009 weighted detector", ...
    'source_note', "MG-009 TEST group replayed with the frozen MG-009 model (no retuning)");
runBundle = mineguard.app.makeRunBundle(pub, events, struct('provenance', prov, 'result', result, ...
    'result_report', report, 'display_settings', struct('grid_spacing_m', c.grid_spacing_m)));
ctx = struct('config', rmfield(c, {'target_count','clutter_count'}), 'geometry', pub.geometry, 'route', route, 'nav', nav);
end

function t = assign(t, seed, tMat, cMat)
s = RandStream('mt19937ar', 'Seed', seed + 777);
for k = 1:height(t)
    if string(t.label(k)) == "target", t.material_type(k) = tMat(randi(s, 3)); else, t.material_type(k) = cMat(randi(s, 3)); end
end
end
