function [runBundle, record] = runExperiment(config)
%RUNEXPERIMENT End-to-end MineGuard simulation run (frozen mg-contract/1.0 API, MG-015).
%   runBundle = mineguard.runExperiment(config)
%   [runBundle, record] = mineguard.runExperiment(config)   (record: optional evaluator-side summary)
%
%   config  - ExperimentConfig (MG-003) with the versioned extension substructs below:
%     sensor_settings   (MG-006/MG-007; e.g. mg007FixtureSettings()). An absent channel means
%                       UNCONFIGURED_SENSOR rows; no values are invented.
%     detector_settings (MG-015, required):
%        method_name            "thermal_only"|"em_only"|"or"|"and"|"weighted"
%        missing_modality_rule  "abstain"|"single_valid"|"require_both"
%        association_tolerance_s, threshold
%        model                  frozen MG-009 model struct (TRAIN normalisers, VALIDATION thresholds)
%        model_id               text identifier/hash of the frozen model
%     run_options (MG-015, optional):
%        evaluate (default true), split_id (train|validation|test|stress; required if evaluate),
%        group_id, localization_match_radius_m (default 0.75), truth_transform (function handle,
%        evaluation fixtures only)
%
%   Pipeline (all of it existing, unmodified modules):
%     1. MG-004 generateScenario, 2. MG-005 makeGridRoute + simulatePose + computeCoverage, and
%     3. MG-007 simulateThermal/simulateEM, all via mineguard.evaluation.runTrial;
%     4. MG-009 detectAnomalies on poses + samples + frozen model ONLY (no truth);
%     5. MG-009 evaluableCellMask (no truth) + scoreDetections. This is the only step that receives
%        truth; it returns aggregates;
%     6. checkProvenance; 7. MG-011 makeRunBundle (allowlisted redaction) -> runBundle for
%        mineguard.app.openMissionApp(runBundle).
%   Hidden truth never enters the detector, the runBundle or the record.
%   Errors from the modules (e.g. mineguard:RouteConflict, mineguard:InvalidScenario) propagate
%   unchanged. Invalid MG-015 settings throw mineguard:InvalidExperimentConfig.
%   SIMULATION ONLY. No hardware, flight controller or network is touched.
id = 'mineguard:InvalidExperimentConfig';
if ~isstruct(config) || ~isscalar(config) || ~isfield(config, 'detector_settings')
    error(id, 'MineGuard runExperiment: config must be an ExperimentConfig with a detector_settings substruct.');
end
ds = config.detector_settings;
need = ["method_name","missing_modality_rule","association_tolerance_s","threshold","model","model_id"];
if ~isstruct(ds) || ~all(isfield(ds, need))
    error(id, 'MineGuard runExperiment: detector_settings needs %s.', strjoin(need, ', '));
end
ro = struct();
if isfield(config, 'run_options'), ro = config.run_options; end
evaluate = ~isfield(ro, 'evaluate') || ro.evaluate;
radius = 0.75; if isfield(ro, 'localization_match_radius_m'), radius = ro.localization_match_radius_m; end
split = "NOT_RECORDED"; if isfield(ro, 'split_id'), split = string(ro.split_id); end
if evaluate && ~ismember(split, ["train","validation","test","stress"])
    error(id, 'MineGuard runExperiment: run_options.split_id must be train|validation|test|stress when evaluate is true.');
end
groupId = "NOT_RECORDED"; if isfield(ro, 'group_id'), groupId = string(ro.group_id); end
topts = struct();
if isfield(ro, 'truth_transform')                 % evaluation fixtures only; not part of the checksum
    topts.truthTransform = ro.truth_transform;
    config.run_options = rmfield(config.run_options, 'truth_transform');
end

% 1-3. Scenario, mission and sensors (MG-004/005/007 via the MG-009 runTrial orchestrator).
trial = mineguard.evaluation.runTrial(config, topts);

% 4. Detection on observables only.
dc = struct('schema_version', "mg-contract/1.0", 'scenario_id', string(config.scenario_id), ...
    'association_tolerance_s', ds.association_tolerance_s, 'threshold', ds.threshold, ...
    'method_name', string(ds.method_name), 'missing_modality_rule', string(ds.missing_modality_rule));
[events, diag] = mineguard.detection.detectAnomalies(dc, trial.public.poses, trial.public.samples, ds.model);

% 5. Evaluation: the only consumer of truth.
grid = struct('bounds_enu_m', trial.public.geometry.bounds_enu_m, 'grid_spacing_m', config.grid_spacing_m, ...
    'exclusion_polygons_enu_m', {trial.public.geometry.exclusion_polygons_enu_m});
mask = mineguard.evaluation.evaluableCellMask(grid, trial.public.poses, trial.public.samples, dc.method_name, dc.missing_modality_rule);
[sha, dirty] = gitState();
rel = string(version('-release'));
v = ver; tbx = strjoin(string({v.Name}) + " " + string({v.Version}), "; ");
rm = struct('scenario_id', string(config.scenario_id), 'grid', grid, 'evaluable_cell_mask', mask, ...
    'algorithm', dc.method_name + "/" + dc.missing_modality_rule, 'split_id', split, ...
    'localization_match_radius_m', radius, 'coverage_fraction', trial.public.coverage.coverage_fraction, ...
    'mission_time_s', trial.public.coverage.mission_time_s, 'distance_m', trial.public.coverage.distance_m, ...
    'git_sha', sha, 'matlab_release', rel, 'toolbox_manifest', tbx);
result = []; report = [];
mineguard.evaluation.checkProvenance(trial, config, dc, rm);
if evaluate
    [result, report] = mineguard.evaluation.scoreDetections(config, events, trial.private.truth, rm);
end
trial.private = [];                                                  % truth dropped here

% 6-7. Redacted, provenance-complete bundle for the MG-011 dashboard.
nav = mineguard.navigation.navigationConfigFromExperiment(config);
route = mineguard.navigation.makeGridRoute(nav, trial.public.geometry);
ss = struct('version', "UNCONFIGURED");
if isfield(config, 'sensor_settings'), ss = config.sensor_settings; end
p = trial.provenance;
prov = struct('scenario_id', string(config.scenario_id), 'seed', config.seed, 'noise_seed', config.noise_seed, ...
    'model_version', string(config.model_version), 'sensor_settings_version', string(ss.version), ...
    'detector_model_version', string(ds.model_id), 'method_name', dc.method_name, ...
    'missing_modality_rule', dc.missing_modality_rule, 'threshold', dc.threshold, 'matlab_release', rel, ...
    'git_sha', sha + dirty, 'run_id', "MG015-" + string(config.scenario_id) + "-" + p.config_checksum, ...
    'run_timestamp_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
    'toolbox_manifest', tbx, 'split_id', split, ...
    'simulation_flags', "SIMULATION ONLY; synthetic MG-004 scenario; kinematic MG-005 grid; MG-007 assumed sensor parameters; frozen MG-009 detector", ...
    'source_note', "mineguard.runExperiment (MG-015); group " + groupId);
pub = struct('scenario_id', string(config.scenario_id), 'geometry', trial.public.geometry, 'poses', trial.public.poses, ...
    'samples', trial.public.samples, 'coverage', trial.public.coverage, 'route_enu_m', route);
meta = struct('provenance', prov, 'display_settings', struct('grid_spacing_m', config.grid_spacing_m));
if evaluate
    meta.result = result; meta.result_report = report;
end
runBundle = mineguard.app.makeRunBundle(pub, events, meta);

if nargout > 1
    agg = struct();
    if evaluate
        keep = ["metric_unit","cell_size_m","total_legal_cell_count","evaluable_cell_count","excluded_cell_count", ...
            "illegal_cell_count","positive_cells_evaluable","prevalence","denominators","specificity","target_objects", ...
            "unobserved_target_count","cells_with_multiple_targets","valid_events","off_grid_events", ...
            "events_in_negative_cells","object_event_matches","unmatched_events","unmatched_targets", ...
            "event_fp_per_mission","event_localization_error_m"];
        for k = keep, agg.(k) = report.(k); end
    end
    record = struct('group_id', groupId, 'scenario_id', string(config.scenario_id), 'split_id', split, ...
        'result', result, 'report', agg, 'diagnostics', diag, 'evaluable_cells', nnz(mask), ...
        'invalid_thermal_fraction', mean(~trial.public.samples.valid(trial.public.samples.sensor_kind == "thermal")), ...
        'invalid_em_fraction', mean(~trial.public.samples.valid(trial.public.samples.sensor_kind == "em")), ...
        'provenance', rmfield(p, 'config_checksum'), 'config_checksum', p.config_checksum, ...
        'events', height(events), 'git_sha', sha + dirty);
end
end

function [sha, dirty] = gitState()
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
[s1, o1] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
if s1 ~= 0, sha = "NOT_RECORDED"; dirty = ""; return; end
sha = strtrim(string(o1));
[~, o2] = system(sprintf('git -C "%s" status --porcelain -- matlab', root));
if strlength(strtrim(string(o2))) > 0, dirty = "+uncommitted"; else, dirty = ""; end
end
