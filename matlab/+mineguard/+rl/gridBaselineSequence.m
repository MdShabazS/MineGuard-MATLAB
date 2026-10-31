function [seq, feasible, reason] = gridBaselineSequence(G)
%GRIDBASELINESEQUENCE The MG-005 fixed serpentine grid as a sequence of MG-013 cell IDs.
%   [seq, feasible, reason] = mineguard.rl.gridBaselineSequence(G)
%   Calls the unmodified MG-005 makeGridRoute(navConfig, geometry). If MG-005 rejects the
%   scenario (mineguard:RouteConflict, interior exclusion), the baseline is reported INFEASIBLE.
%   It is never rerouted. The first waypoint must be the shared start cell; the remaining
%   waypoints become the action sequence, executed under the same shared budget.
try
    route = mineguard.navigation.makeGridRoute(G.nav, G.geometry);
catch err
    if strcmp(err.identifier, 'mineguard:RouteConflict')
        seq = zeros(0, 1); feasible = false; reason = "INFEASIBLE_ROUTE_CONFLICT"; return
    end
    rethrow(err);
end
ids = mineguard.rl.cellOfPoint(G, route(:,1), route(:,2));
if any(abs(G.centers(ids, :) - route(:, 1:2)) > 1e-9, 'all')
    error('mineguard:InvalidScenario', 'MineGuard RL: MG-005 waypoints do not coincide with MG-013 cell centres.');
end
seq = ids(2:end); feasible = true; reason = "FEASIBLE";
end
