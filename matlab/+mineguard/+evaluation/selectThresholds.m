function [model, thresholds, selection] = selectThresholds(valBundles, valConfigs, model, opts)
%SELECTTHRESHOLDS Choose decision thresholds on VALIDATION scenarios only, then freeze them (MG-008 Section 4.4).
%   [model, thresholds, selection] = mineguard.evaluation.selectThresholds(valBundles, valConfigs, model, opts)
%   For each method, sweep a pre-declared candidate grid and keep the threshold with the highest
%   pooled validation cell F1. NaN F1 ranks lowest, and ties go to the lowest threshold.
%     thermal_only and em_only grids: opts.z_grid. The winners also become the model's
%       component thresholds (thermal_z_threshold / em_z_threshold) and the weighted single-channel fallback.
%     or, and: the decision score is a ratio to the component thresholds; grid opts.ratio_grid.
%     weighted: fixed pre-declared weights (model.w_thermal / model.w_em); grid opts.z_grid.
%   The rule used for selection is opts.rule. opts.split_ids (from the manifest) must all be "validation".
%   Test data is never passed to this function.
if ~isfield(opts, 'split_ids') || numel(opts.split_ids) ~= numel(valConfigs) || any(string(opts.split_ids) ~= "validation")
    error('mineguard:SplitLeakage', 'MineGuard evaluation: threshold selection accepts only scenarios whose manifest split_id is "validation".');
end
eo = struct('split_id', "validation", 'association_tolerance_s', opts.association_tolerance_s, ...
    'localization_match_radius_m', opts.localization_match_radius_m);
sel = {};
best = struct();
order = ["thermal_only","em_only","or","and","weighted"];
for meth = order
    if ismember(meth, ["or","and"])
        grid = opts.ratio_grid;
    else
        grid = opts.z_grid;
    end
    tmp = model;
    if meth == "weighted" || ismember(meth, ["or","and"])
        tmp.thermal_z_threshold = best.thermal_only; tmp.em_z_threshold = best.em_only;
        tmp.weighted_fallback = struct('thermal_z_threshold', best.thermal_only, 'em_z_threshold', best.em_only);
    else
        tmp.thermal_z_threshold = 1; tmp.em_z_threshold = 1;   % placeholders, unused by single-channel methods
    end
    f1 = -Inf(size(grid));
    for i = 1:numel(grid)
        p = mineguard.evaluation.evaluateMethod(valBundles, valConfigs, tmp, meth, opts.rule, grid(i), eo);
        if ~isnan(p.f1), f1(i) = p.f1; end
        sel{end+1, 1} = table(meth, grid(i), p.f1, p.precision, p.recall, p.fpr, p.tp, p.fp, p.tn, p.fn, ...
            'VariableNames', {'method','threshold','val_f1','val_precision','val_recall','val_fpr','tp','fp','tn','fn'}); %#ok<AGROW>
    end
    [~, b] = max(f1);
    best.(meth) = grid(b);
end
model.thermal_z_threshold = best.thermal_only;
model.em_z_threshold = best.em_only;
model.weighted_fallback = struct('thermal_z_threshold', best.thermal_only, 'em_z_threshold', best.em_only);
model.provenance.threshold_split = "validation";
model.provenance.validation_scenario_ids = string(cellfun(@(c) string(c.scenario_id), valConfigs));
model.provenance.selection_rule = string(opts.rule);
model.provenance.selection_criterion = "max pooled validation cell F1; ties -> lowest threshold";
thresholds = best;
selection = vertcat(sel{:});
end
