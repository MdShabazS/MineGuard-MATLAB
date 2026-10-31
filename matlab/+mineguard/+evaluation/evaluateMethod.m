function [pooled, perScenario, nEvents] = evaluateMethod(bundles, configs, model, methodName, rule, threshold, opts)
%EVALUATEMETHOD Run detection, then scoring, over a set of trials with ONE frozen model/threshold.
%   [pooled, perScenario, nEvents] = mineguard.evaluation.evaluateMethod(bundles, configs, model,
%       methodName, rule, threshold, opts)
%   opts.split_id, opts.association_tolerance_s, opts.localization_match_radius_m,
%   opts.common_mask (optional, a cell array of per-trial masks; used for matched comparisons),
%   opts.provenance (optional struct of git_sha / matlab_release / toolbox_manifest)
%   The detector receives only detectorConfig, poses, samples and model. Truth is passed only to
%   scoreDetections. pooled holds micro-aggregated counts and ratios; perScenario holds one
%   row per trial.
n = numel(bundles);
rows = cell(n, 1); nEvents = 0;
TP = 0; FP = 0; TN = 0; FN = 0; M = 0; U = 0; locSum = 0;
for k = 1:n
    b = bundles{k}; c = configs{k};
    dc = struct('schema_version', "mg-contract/1.0", 'scenario_id', b.public.scenario_id, ...
        'association_tolerance_s', opts.association_tolerance_s, 'threshold', threshold, ...
        'method_name', string(methodName), 'missing_modality_rule', string(rule));
    ev = mineguard.detection.detectAnomalies(dc, b.public.poses, b.public.samples, model);
    grid = struct('bounds_enu_m', b.public.geometry.bounds_enu_m, 'grid_spacing_m', c.grid_spacing_m, ...
        'exclusion_polygons_enu_m', {b.public.geometry.exclusion_polygons_enu_m});
    if isfield(opts, 'common_mask')
        mask = opts.common_mask{k};
    else
        mask = mineguard.evaluation.evaluableCellMask(grid, b.public.poses, b.public.samples, methodName, rule);
    end
    rm = struct('scenario_id', b.public.scenario_id, 'grid', grid, 'evaluable_cell_mask', mask, ...
        'algorithm', string(methodName) + "/" + string(rule), 'split_id', opts.split_id, ...
        'localization_match_radius_m', opts.localization_match_radius_m, ...
        'coverage_fraction', b.public.coverage.coverage_fraction, 'mission_time_s', b.public.coverage.mission_time_s, ...
        'distance_m', b.public.coverage.distance_m);
    if isfield(opts, 'provenance')
        f = fieldnames(opts.provenance);
        for j = 1:numel(f), rm.(f{j}) = opts.provenance.(f{j}); end
    end
    mineguard.evaluation.checkProvenance(b, c, dc, rm);
    [res, rep] = mineguard.evaluation.scoreDetections(c, ev, b.private.truth, rm);
    rows{k} = table(string(res.scenario_id), res.scenario_seed, res.tp, res.fp, res.tn, res.fn, res.precision, res.recall, ...
        res.f1, res.false_alarm_rate, rep.evaluable_cell_count, rep.excluded_cell_count, height(ev), ...
        rep.object_event_matches, rep.target_objects, res.localization_error_m, ...
        'VariableNames', {'scenario_id','seed','tp','fp','tn','fn','precision','recall','f1','fpr', ...
        'evaluable_cells','excluded_cells','events','matches','targets','loc_err_m'});
    TP = TP + res.tp; FP = FP + res.fp; TN = TN + res.tn; FN = FN + res.fn;
    M = M + rep.object_event_matches; U = U + rep.unmatched_events; nEvents = nEvents + height(ev);
    if rep.object_event_matches > 0
        locSum = locSum + rep.event_localization_error_m * rep.object_event_matches;
    end
end
perScenario = vertcat(rows{:});
r = @safeRatio;
pooled = struct('method', string(methodName), 'rule', string(rule), 'threshold', threshold, ...
    'tp', TP, 'fp', FP, 'tn', TN, 'fn', FN, 'precision', r(TP, TP + FP), 'recall', r(TP, TP + FN), ...
    'f1', r(2*TP, 2*TP + FP + FN), 'fpr', r(FP, FP + TN), 'events', nEvents, ...
    'object_matches', M, 'unmatched_events', U, 'mean_loc_err_m', r(locSum, M));
end

function v = safeRatio(a, b)
%SAFERATIO a/b when b > 0, otherwise NaN (undefined ratio is never coerced to 0).
if b > 0
    v = a / b;
else
    v = NaN;
end
end
