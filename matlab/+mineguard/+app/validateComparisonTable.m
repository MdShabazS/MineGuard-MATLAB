function validateComparisonTable(T)
%VALIDATECOMPARISONTABLE Strict check of a public PPO/fixed-grid comparison table (MG-019).
%   mineguard.app.validateComparisonTable(T)   throws mineguard:InvalidComparison
%   - The column names must EXACTLY equal mineguard.contract.comparisonColumns() (same names, same
%     order). Any extra column is rejected, including hidden-truth fields (label, target_count,
%     burial_depth_m, ...) and misleading alternatives (accuracy, detection_rate, mines_found,
%     safe_fraction, ...), as is any missing column.
%   - planner is a string from {"grid","ppo"} with no duplicates; reason is a string.
%   - executed and completed are logical. All other columns are real double scalars per row,
%     where NaN means not applicable / not run and Inf is rejected.
%   - Ratios (coverage, precision, recall, f1, fpr, invalid fractions) are NaN or within [0,1];
%     counts are NaN or nonnegative integers; distances and times are NaN or >= 0.
id = 'mineguard:InvalidComparison';
if ~istable(T)
    error(id, 'Invalid comparison: must be a table.');
end
allow = mineguard.contract.comparisonColumns();
names = string(T.Properties.VariableNames);
extra = setdiff(names, allow, 'stable');
missing = setdiff(allow, names, 'stable');
if ~isempty(extra) || ~isempty(missing) || ~isequal(names, allow)
    error(id, 'Invalid comparison: columns must exactly match the public allowlist. Unexpected: {%s}; missing: {%s}.', ...
        strjoin(extra, ', '), strjoin(missing, ', '));
end
if height(T) < 1 || ~isstring(T.planner) || ~all(ismember(T.planner, ["grid","ppo"])) || numel(unique(T.planner)) ~= height(T)
    error(id, 'Invalid comparison: planner must be unique strings from {"grid","ppo"}.');
end
if ~isstring(T.reason)
    error(id, 'Invalid comparison: reason must be a string column.');
end
if ~islogical(T.executed) || ~islogical(T.completed)
    error(id, 'Invalid comparison: executed and completed must be logical.');
end
num = setdiff(allow, ["planner","reason","executed","completed"], 'stable');
for c = num
    v = T.(c);
    if ~isa(v, 'double') || ~isreal(v) || ~iscolumn(v) || any(isinf(v))
        error(id, 'Invalid comparison: %s must be a finite-or-NaN real double column.', c);
    end
end
frac = ["coverage_fraction","precision","recall","f1","fpr","invalid_thermal_fraction","invalid_em_fraction"];
for c = frac
    v = T.(c); v = v(~isnan(v));
    if any(v < 0 | v > 1), error(id, 'Invalid comparison: %s must be NaN or within [0,1].', c); end
end
cnt = ["unique_cells","n_legal","invalid_actions","revisits","decisions","events","tp","fp","tn","fn","evaluable_cells"];
for c = cnt
    v = T.(c); v = v(~isnan(v));
    if any(v < 0 | v ~= fix(v)), error(id, 'Invalid comparison: %s must be NaN or a nonnegative integer.', c); end
end
for c = ["distance_m","mission_time_s","coverage_per_m","coverage_per_s","runtime_s"]
    v = T.(c); v = v(~isnan(v));
    if any(v < 0), error(id, 'Invalid comparison: %s must be NaN or nonnegative.', c); end
end
end
