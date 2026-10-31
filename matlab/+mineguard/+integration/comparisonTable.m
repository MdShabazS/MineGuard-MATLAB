function T = comparisonTable(records)
%COMPARISONTABLE Planner comparison rows from runSurveyMission records (MG-019). Aggregates only.
%   T = mineguard.integration.comparisonTable({gridRecord, ppoRecord, ...})
%   Columns: planner, executed, reason, completed, coverage_fraction, unique_cells, n_legal,
%   distance_m, mission_time_s, coverage_per_m, coverage_per_s, invalid_actions, revisits,
%   decisions, runtime_s, events, tp, fp, tn, fn, precision, recall, f1, fpr,
%   invalid_thermal_fraction, invalid_em_fraction, evaluable_cells.
%   NaN means not applicable / not run (for example an infeasible grid route); never 0.
%   Detection columns are EXPLORATORY: different routes sample different positions.
if isstruct(records), records = num2cell(records); end
f = mineguard.contract.comparisonColumns();   % exact public allowlist (single source of truth)
rows = cell(numel(records), 1);
for k = 1:numel(records)
    r = records{k}; v = cell(1, numel(f));
    for j = 1:numel(f), v{j} = r.(f(j)); end
    rows{k} = cell2table(v, 'VariableNames', cellstr(f));
end
T = vertcat(rows{:});
T.planner = string(T.planner); T.reason = string(T.reason);
T.executed = logical(T.executed); T.completed = logical(T.completed);
mineguard.app.validateComparisonTable(T);
end
