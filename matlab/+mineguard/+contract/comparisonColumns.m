function cols = comparisonColumns()
%COMPARISONCOLUMNS Exact, ordered allowlist of PUBLIC planner-comparison metrics (MG-019).
%   cols = mineguard.contract.comparisonColumns()
%   The single source of truth for mineguard.integration.comparisonTable,
%   mineguard.app.validateComparisonTable (used by validateRunBundle and openComparisonApp) and the
%   comparison export. All of these are aggregate, observation-derived or evaluator-aggregate
%   quantities. No truth field, object identity or "accuracy"-style alias is allowed. Changing this
%   list is a reviewed contract change.
cols = ["planner","executed","reason","completed","coverage_fraction","unique_cells","n_legal","distance_m", ...
    "mission_time_s","coverage_per_m","coverage_per_s","invalid_actions","revisits","decisions","runtime_s", ...
    "events","tp","fp","tn","fn","precision","recall","f1","fpr","invalid_thermal_fraction","invalid_em_fraction","evaluable_cells"];
end
