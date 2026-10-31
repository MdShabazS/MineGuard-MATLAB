function [result, report] = scoreDetections(config, events, truth, runMetadata)
%SCOREDETECTIONS Evaluator-only scoring (mg-contract/1.0, MG-009; MG-008 Sections 5-6).
%   result = mineguard.evaluation.scoreDetections(config, events, truth, runMetadata)
%   [result, report] = ...   (report: denominators, exclusions, localization details)
%
%   PRIMARY (cell unit, metric_unit = "evaluable_survey_cell"): the population is the legal AND
%   evaluable cells in runMetadata.evaluable_cell_mask (from evaluableCellMask, with no truth).
%     A truth-positive cell holds at least one TargetTruth label=="target" (clutter is negative).
%     A predicted-positive cell holds at least one valid SUSPECTED event (many events = one).
%     Off-grid or invalid events cannot create a TP. Unassessed legal cells are excluded and
%     counted, never treated as TN. Undefined ratios are NaN.
%   SECONDARY (object localization, kept separate): valid in-bounds events are matched to
%   targets within localization_match_radius_m by a maximum-cardinality, minimum-total-distance
%   one-to-one matching (matchpairs with a dominant unmatched cost). localization_error_m is the
%   mean matched distance, or NaN when there is no pair.
%   result has exactly the frozen ExperimentResult fields; missing provenance is "NOT_RECORDED".
id = 'mineguard:InvalidEvaluationInput';
if ~isstruct(config) || ~all(isfield(config, {'schema_version','scenario_id','seed'}))
    error(id, 'MineGuard evaluation: config must contain schema_version, scenario_id and seed.');
end
need = {'scenario_id','grid','evaluable_cell_mask','algorithm','split_id','localization_match_radius_m'};
if ~isstruct(runMetadata) || ~all(isfield(runMetadata, need))
    error(id, 'MineGuard evaluation: runMetadata needs %s.', strjoin(need, ', '));
end
if string(runMetadata.scenario_id) ~= string(config.scenario_id)
    error('mineguard:ProvenanceMismatch', 'MineGuard evaluation: runMetadata.scenario_id "%s" does not match config.scenario_id "%s".', ...
        string(runMetadata.scenario_id), string(config.scenario_id));
end
if ~ismember(string(runMetadata.split_id), ["train","validation","test","stress"])
    error(id, 'MineGuard evaluation: split_id must be train, validation, test or stress.');
end
r = runMetadata.localization_match_radius_m;
if ~(isnumeric(r) && isscalar(r) && isfinite(r) && r >= 0)
    error(id, 'MineGuard evaluation: localization_match_radius_m must be a finite nonnegative scalar.');
end
cols = ["event_id","t_s","x_est_m","y_est_m","confidence_0_1","uncertainty_m", ...
    "thermal_sample_id","em_sample_id","method_name","threshold","status","valid"];
if ~istable(events) || ~isequal(string(events.Properties.VariableNames), cols)
    error(id, 'MineGuard evaluation: events must be a DetectionEvent table with exactly the 12 contract columns.');
end
if ~istable(truth) || ~all(ismember({'x_east_m','y_north_m','label'}, truth.Properties.VariableNames))
    error(id, 'MineGuard evaluation: truth must be a TargetTruth table.');
end

G = gridSpec(runMetadata.grid);
mask = runMetadata.evaluable_cell_mask;
if ~islogical(mask) || ~isequal(size(mask), [G.ny G.nx])
    error(id, 'MineGuard evaluation: evaluable_cell_mask must be a %dx%d logical array.', G.ny, G.nx);
end
if any(mask(:) & ~G.legal(:))
    error(id, 'MineGuard evaluation: evaluable_cell_mask marks illegal (excluded-zone) cells as evaluable.');
end
pop = mask & G.legal;

isTarget = string(truth.label) == "target";
[tl, tin] = cellIndex(G, truth.x_east_m(isTarget), truth.y_north_m(isTarget));
if any(~tin)
    error(id, 'MineGuard evaluation: target truth lies outside the grid bounds.');
end
truthPos = false(G.ny, G.nx); truthPos(tl) = true;

ok = events.valid & events.status == "SUSPECTED";
[el, ein] = cellIndex(G, events.x_est_m, events.y_est_m);
predPos = false(G.ny, G.nx); predPos(el(ok & ein)) = true;

TP = nnz(pop & truthPos & predPos);  FP = nnz(pop & ~truthPos & predPos);
FN = nnz(pop & truthPos & ~predPos); TN = nnz(pop & ~truthPos & ~predPos);
ratio = @(a, b) local_ratio(a, b);

% Secondary: one-to-one localization matching.
ev = find(ok & ein);
tg = find(isTarget);
nMatch = 0; locErr = NaN; pairs = zeros(0, 3);
if ~isempty(ev) && ~isempty(tg)
    D = hypot(events.x_est_m(ev) - truth.x_east_m(tg)', events.y_est_m(ev) - truth.y_north_m(tg)');
    C = D; C(D > r) = Inf;
    feasible = D(D <= r);
    if ~isempty(feasible)
        big = sum(feasible) + 1;          % dominant: maximises cardinality first
        M = matchpairs(C, big);
        nMatch = size(M, 1);
        d = D(sub2ind(size(D), M(:,1), M(:,2)));
        pairs = [ev(M(:,1)) tg(M(:,2)) d];
        locErr = mean(d);
    end
end

prov = @(f) local_get(runMetadata, f, "NOT_RECORDED");
num = @(f) local_get(runMetadata, f, NaN);
result = struct( ...
    'schema_version', string(config.schema_version), 'scenario_id', string(config.scenario_id), ...
    'seed', config.seed, 'algorithm', string(runMetadata.algorithm), ...
    'coverage_fraction', num('coverage_fraction'), 'mission_time_s', num('mission_time_s'), 'distance_m', num('distance_m'), ...
    'tp', TP, 'fp', FP, 'tn', TN, 'fn', FN, ...
    'precision', ratio(TP, TP + FP), 'recall', ratio(TP, TP + FN), 'f1', ratio(2*TP, 2*TP + FP + FN), ...
    'false_alarm_rate', ratio(FP, FP + TN), 'localization_error_m', locErr, ...
    'matlab_release', prov('matlab_release'), 'toolbox_manifest', prov('toolbox_manifest'), ...
    'git_sha', prov('git_sha'), 'split_id', string(runMetadata.split_id), 'scenario_seed', config.seed);

unassessed = G.legal & ~mask;
report = struct( ...
    'metric_unit', "evaluable_survey_cell", 'cell_size_m', [G.dx G.dy], 'grid_cells', G.nx * G.ny, ...
    'total_legal_cell_count', nnz(G.legal), 'evaluable_cell_count', nnz(pop), 'excluded_cell_count', nnz(unassessed), ...
    'illegal_cell_count', nnz(~G.legal), 'positive_cells_evaluable', nnz(pop & truthPos), ...
    'prevalence', ratio(nnz(pop & truthPos), nnz(pop)), ...
    'denominators', struct('precision', TP + FP, 'recall', TP + FN, 'f1', 2*TP + FP + FN, 'false_alarm_rate', FP + TN, 'specificity', TN + FP), ...
    'specificity', ratio(TN, TN + FP), ...
    'target_objects', nnz(isTarget), 'unobserved_target_count', nnz(unassessed(tl)), ...
    'targets_in_illegal_cells', nnz(~G.legal(tl)), ...
    'cells_with_multiple_targets', nnz(accumarray(tl(:), 1, [G.ny*G.nx 1]) > 1), ...
    'valid_events', nnz(ok), 'off_grid_events', nnz(ok & ~ein), ...
    'events_in_negative_cells', nnz(ok & ein & ~truthPos(max(el,1))), ...
    'object_event_matches', nMatch, 'unmatched_events', numel(ev) - nMatch, 'unmatched_targets', numel(tg) - nMatch, ...
    'event_fp_per_mission', numel(ev) - nMatch, 'event_localization_error_m', locErr, ...
    'match_pairs_event_target_dist', pairs, 'localization_match_radius_m', r);
end

function v = local_ratio(a, b)
if b > 0
    v = a / b;
else
    v = NaN;
end
end

function v = local_get(s, f, default)
if isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
    if isstring(default), v = string(v); end
else
    v = default;
end
end
