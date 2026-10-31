function app = openComparisonApp(gridBundle, ppoBundle, comparison)
%OPENCOMPARISONAPP Side-by-side fixed-grid vs PPO mission comparison window (MG-019). SIMULATION ONLY.
%   app = mineguard.app.openComparisonApp(gridBundle, ppoBundle, comparison)
%   gridBundle - redacted runBundle of the fixed-grid mission, or [] if the grid route was
%                INFEASIBLE (that panel then shows NOT RUN / INFEASIBLE)
%   ppoBundle  - redacted runBundle of the PPO mission (required)
%   comparison - table from mineguard.integration.comparisonTable (planner metrics, aggregates only)
%   Both bundles are validated with validateRunBundle and must share the same scenario_id and
%   bounds. Each map shows only that run's own route, visited cells and SUSPECTED events; sensor
%   data are never mixed. "Open replay" buttons open the full MG-011 dashboard for either run.
%   Returns a mineguard.app.ComparisonApp handle.
if ~isempty(gridBundle), mineguard.app.validateRunBundle(gridBundle); end
mineguard.app.validateRunBundle(ppoBundle);
if ~isempty(gridBundle) && (gridBundle.scenario_id ~= ppoBundle.scenario_id || ...
        ~isequal(gridBundle.geometry.bounds_enu_m, ppoBundle.geometry.bounds_enu_m))
    error('mineguard:InvalidRunBundle', 'Comparison bundles must come from the same scenario and geometry.');
end
need = ["planner","coverage_fraction","distance_m","mission_time_s"];
if ~istable(comparison) || ~all(ismember(need, string(comparison.Properties.VariableNames))) || ...
        any(ismember(string(comparison.Properties.VariableNames), setdiff(mineguard.contract.truthFieldNames(), ["x_east_m","y_north_m"])))
    error('mineguard:InvalidRunBundle', 'comparison must be a planner metrics table without truth columns.');
end
app = mineguard.app.ComparisonApp(gridBundle, ppoBundle, comparison);
end
