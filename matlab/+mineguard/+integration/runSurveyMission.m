function [runBundle, record] = runSurveyMission(config, planner, opts)
%RUNSURVEYMISSION End-to-end mission on the MG-013 5x5 survey environment with a chosen planner (MG-019).
%   [runBundle, record] = mineguard.integration.runSurveyMission(config, planner)
%   [runBundle, record] = mineguard.integration.runSurveyMission(config, planner, opts)
%   This is a separate, versioned orchestration ("mg019-mission-1.0"). It does NOT change
%   mineguard.runExperiment, whose default stays the MG-005 fixed grid.
%
%   config  - ExperimentConfig (e.g. mg013ScenarioConfig with objects) + sensor_settings (optional;
%             absent = UNCONFIGURED) + detector_settings (frozen detector) + run_options
%             (split_id, group_id, evaluate)
%   planner - "grid": MG-005 makeGridRoute waypoints, executed in the MG-013 environment;
%             mineguard:RouteConflict -> record.reason "INFEASIBLE_ROUTE_CONFLICT", no mission
%             "ppo":  frozen MG-013 agent through the frozen mineguard.rl.selectSurveyCell API
%   opts    - .policy (from loadPPOCheckpoint; loaded if omitted), .env_config (default
%             mineguard.rl.defaultEnvConfig: D_max 60 m, T_max 30 s, 50 decisions, start cell 1)
%
%   Pipeline:
%     1. MG-004 generateScenario
%     2. MG-013 buildSurveyGrid (legs via MG-005 simulatePose, exact exclusion tests)
%     3. planner decisions -> mineguard.rl.runEpisode. Invalid actions are rejected and penalised;
%        accepted moves produce the MG-005 sampled poses
%     4. MG-007 thermal/EM along the ACTUAL executed poses
%     5. MG-009 detectAnomalies (observables + frozen model only)
%     6. MG-009 evaluableCellMask + scoreDetections (the only consumer of truth; aggregates only)
%     7. MG-011 makeRunBundle (allowlisted, redacted)
%   A 25-action policy is never applied to a grid with a different cell count
%   (mineguard:IncompatiblePolicy). SIMULATION ONLY.
if nargin < 3, opts = struct(); end
planner = string(planner);
if ~ismember(planner, ["grid","ppo"])
    error('mineguard:InvalidExperimentConfig', 'planner must be "grid" or "ppo".');
end
cfg = mineguard.rl.defaultEnvConfig();
if isfield(opts, 'env_config'), cfg = opts.env_config; end
ro = struct(); if isfield(config, 'run_options'), ro = config.run_options; end
evaluate = ~isfield(ro, 'evaluate') || ro.evaluate;
split = "NOT_RECORDED"; if isfield(ro, 'split_id'), split = string(ro.split_id); end
groupId = "NOT_RECORDED"; if isfield(ro, 'group_id'), groupId = string(ro.group_id); end
if ~isfield(config, 'detector_settings')
    error('mineguard:InvalidExperimentConfig', 'config.detector_settings (frozen detector) is required.');
end
ds = config.detector_settings;

% 1-2. Scenario and survey grid (public geometry only for planning).
[geometry, truth, environment] = mineguard.scenario.generateScenario(config);
nav = mineguard.navigation.navigationConfigFromExperiment(config);
G = mineguard.rl.buildSurveyGrid(nav, geometry);

% 3. Planner decisions.
policyInfo = struct('checksum', "NOT_APPLICABLE", 'version', "NOT_APPLICABLE");
t0 = tic;
if planner == "grid"
    [seq, feasible, freason] = mineguard.rl.gridBaselineSequence(G);
    if ~feasible
        runBundle = [];
        record = emptyRecord(config, planner, groupId, split, freason, G, toc(t0), policyInfo, cfg);
        return
    end
    E = mineguard.rl.runEpisode(G, cfg, seq, string(config.scenario_id));
else
    if isfield(opts, 'policy'), policy = opts.policy; else, policy = mineguard.integration.loadPPOCheckpoint(); end
    if policy.n_cells ~= G.N
        error('mineguard:IncompatiblePolicy', ['The PPO policy has %d actions, but this grid has %d cells. A 25-action ' ...
            'policy cannot be applied to a %d-cell grid without a separately trained compatible policy.'], policy.n_cells, G.N, G.N);
    end
    policyInfo = struct('checksum', string(policy.checksum), 'version', string(policy.version));
    E = mineguard.rl.runEpisode(G, cfg, policy, string(config.scenario_id));
end
planSeconds = toc(t0);
poses = E.poses;

% 4. Sensors along the executed trajectory (forward models may read truth).
scen = struct('config', config, 'geometry', geometry, 'hidden_truth', truth, 'environment', environment);
th = mineguard.sensors.simulateThermal(config, scen, poses);
em = mineguard.sensors.simulateEM(config, scen, poses);
samples = [th; em];

% 5. Detection on observables only.
dc = struct('schema_version', "mg-contract/1.0", 'scenario_id', string(config.scenario_id), ...
    'association_tolerance_s', ds.association_tolerance_s, 'threshold', ds.threshold, ...
    'method_name', string(ds.method_name), 'missing_modality_rule', string(ds.missing_modality_rule));
[events, diag] = mineguard.detection.detectAnomalies(dc, poses, samples, ds.model);

% 6. Evaluation (truth used only here).
grid = struct('bounds_enu_m', geometry.bounds_enu_m, 'grid_spacing_m', config.grid_spacing_m, ...
    'exclusion_polygons_enu_m', {geometry.exclusion_polygons_enu_m});
mask = mineguard.evaluation.evaluableCellMask(grid, poses, samples, dc.method_name, dc.missing_modality_rule);
rel = string(version('-release')); sha = gitSha();
result = []; report = [];
if evaluate
    rm = struct('scenario_id', string(config.scenario_id), 'grid', grid, 'evaluable_cell_mask', mask, ...
        'algorithm', planner + ":" + dc.method_name + "/" + dc.missing_modality_rule, 'split_id', split, ...
        'localization_match_radius_m', 0.75, 'coverage_fraction', E.coverage_fraction, 'mission_time_s', E.mission_time_s, ...
        'distance_m', E.distance_m, 'git_sha', sha, 'matlab_release', rel, 'toolbox_manifest', "see evidence");
    [result, report] = mineguard.evaluation.scoreDetections(config, events, truth, rm);
end
truth = []; scen = []; %#ok<NASGU>   % truth released here

% 7. Redacted bundle.
ss = struct('version', "UNCONFIGURED"); if isfield(config, 'sensor_settings'), ss = config.sensor_settings; end
route = [G.centers([cfg.start_cell; E.actions(validMoves(E))], :), repmat(nav.altitude_m, 1 + nnz(validMoves(E)), 1)];
prov = struct('scenario_id', string(config.scenario_id), 'seed', config.seed, 'noise_seed', config.noise_seed, ...
    'model_version', "mg019-mission-1.0/" + string(config.model_version), 'sensor_settings_version', string(ss.version), ...
    'detector_model_version', string(ds.model_id), 'method_name', dc.method_name, 'missing_modality_rule', dc.missing_modality_rule, ...
    'threshold', dc.threshold, 'matlab_release', rel, 'git_sha', sha, ...
    'run_id', "MG019-" + upper(planner) + "-" + string(config.scenario_id), ...
    'run_timestamp_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
    'split_id', split, 'simulation_flags', "SIMULATION ONLY; planner=" + upper(planner) + ...
        "; MG-013 5x5 environment; shared budget D_max 60 m / T_max 30 s / 50 decisions; MG-007 assumed sensors; frozen detector", ...
    'source_note', "mineguard.integration.runSurveyMission (MG-019); planner " + upper(planner) + "; PPO checkpoint " + policyInfo.checksum);
cov = E.coverage;
pub = struct('scenario_id', string(config.scenario_id), 'geometry', geometry, 'poses', poses, 'samples', samples, ...
    'coverage', cov, 'route_enu_m', route);
meta = struct('provenance', prov, 'display_settings', struct('grid_spacing_m', config.grid_spacing_m));
if evaluate, meta.result = result; meta.result_report = report; end
runBundle = mineguard.app.makeRunBundle(pub, events, meta);

record = emptyRecord(config, planner, groupId, split, E.reason, G, planSeconds, policyInfo, cfg);
record.executed = true;
record.coverage_fraction = E.coverage_fraction; record.unique_cells = E.visited_legal_cells;
record.distance_m = E.distance_m; record.mission_time_s = E.mission_time_s;
record.coverage_per_m = ratio(E.coverage_fraction, E.distance_m); record.coverage_per_s = ratio(E.coverage_fraction, E.mission_time_s);
record.invalid_actions = E.invalid_actions; record.revisits = E.revisits; record.decisions = E.decisions;
record.completed = E.reason == "COVERAGE_GOAL"; record.n_poses = height(poses); record.actions = E.actions;
record.reward_return = E.return;
record.events = height(events); record.raw_exceedances = diag.raw_exceedances; record.evaluable_cells = nnz(mask);
record.invalid_thermal_fraction = mean(~th.valid); record.invalid_em_fraction = mean(~em.valid);
if evaluate
    record.tp = result.tp; record.fp = result.fp; record.tn = result.tn; record.fn = result.fn;
    record.precision = result.precision; record.recall = result.recall; record.f1 = result.f1;
    record.fpr = result.false_alarm_rate; record.localization_error_m = result.localization_error_m;
end
end

function v = validMoves(E)
% Actions that actually moved the vehicle: those whose reward row shows a leg (dL > 0).
v = E.reward_log(1:numel(E.actions), 2) > 0;
end

function r = emptyRecord(config, planner, groupId, split, reason, G, secs, policyInfo, cfg)
r = struct('scenario_id', string(config.scenario_id), 'group_id', groupId, 'split_id', split, 'planner', planner, ...
    'executed', false, 'reason', string(reason), 'n_legal', nnz(G.legal), 'n_exclusions', numel(G.geometry.exclusion_polygons_enu_m), ...
    'coverage_fraction', NaN, 'unique_cells', NaN, 'distance_m', NaN, 'mission_time_s', NaN, 'coverage_per_m', NaN, ...
    'coverage_per_s', NaN, 'invalid_actions', NaN, 'revisits', NaN, 'decisions', NaN, 'completed', false, 'n_poses', 0, ...
    'actions', zeros(0, 1), 'reward_return', NaN, 'runtime_s', secs, 'events', NaN, 'raw_exceedances', NaN, 'evaluable_cells', NaN, ...
    'invalid_thermal_fraction', NaN, 'invalid_em_fraction', NaN, 'tp', NaN, 'fp', NaN, 'tn', NaN, 'fn', NaN, ...
    'precision', NaN, 'recall', NaN, 'f1', NaN, 'fpr', NaN, 'localization_error_m', NaN, ...
    'policy_checksum', policyInfo.checksum, 'budget', [cfg.D_max_m cfg.T_max_s cfg.max_decisions], 'start_cell', cfg.start_cell);
end

function v = ratio(a, b)
if b > 0, v = a / b; else, v = NaN; end
end

function s = gitSha()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
[st, o] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
if st ~= 0, s = "NOT_RECORDED"; else, s = strtrim(string(o)); end
end
