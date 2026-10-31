function E = runEpisode(G, cfg, chooser, scenarioId)
%RUNEPISODE Roll out one episode in the MG-013 environment and summarise it.
%   E = mineguard.rl.runEpisode(G, cfg, chooser, scenarioId)
%   chooser: a policy struct (passed to selectSurveyCell), a numeric vector of cell IDs to execute
%   in order (the fixed-grid baseline), or a function handle @(S,G) -> cell ID (the random-legal
%   reference). The rollout stops at termination, or when the sequence runs out ("ROUTE_END").
%   E.poses is a global PoseSample-compatible table (unique IDs, monotonic t_s), so coverage can
%   be checked independently with MG-005 computeCoverage.
S = mineguard.rl.resetSurvey(G, cfg);
k = 0; actions = zeros(0, 1);
while ~S.done
    if isnumeric(chooser)
        k = k + 1;
        if k > numel(chooser), S.reason = "ROUTE_END"; break; end
        a = chooser(k);
    elseif isa(chooser, 'function_handle')
        a = chooser(S, G);                       % e.g. the seeded random-legal reference policy
    else
        [o, ac] = mineguard.rl.observationRecords(S, G, cfg, scenarioId);
        a = mineguard.rl.selectSurveyCell(o, ac, chooser);
    end
    actions(end+1, 1) = double(a); %#ok<AGROW>
    S = mineguard.rl.stepSurvey(S, a, G, cfg);
end
n = size(S.pose_xy, 1);
poses = table(compose("P-%06d", (1:n)'), S.pose_t, S.pose_xy(:,1), S.pose_xy(:,2), repmat(G.nav.altitude_m, n, 1), ...
    repmat("SURVEY", n, 1), 'VariableNames', {'pose_sample_id','t_s','x_east_m','y_north_m','z_up_m','mission_state'});
poses.mission_state(1) = "INIT"; poses.mission_state(end) = "COMPLETE";
cov = mineguard.navigation.computeCoverage(G.nav, G.geometry, poses);
E = struct('scenario_id', string(scenarioId), 'reason', S.reason, 'coverage_fraction', cov.coverage_fraction, ...
    'visited_legal_cells', nnz(S.visited & G.legal), 'n_legal', nnz(G.legal), 'distance_m', S.dist_m, ...
    'mission_time_s', S.t_s, 'decisions', S.decisions, 'invalid_actions', S.invalid_actions, 'revisits', S.revisits, ...
    'return', sum(S.reward_log(:, end)), 'actions', actions, 'reward_log', S.reward_log, 'poses', poses, 'coverage', cov);
end
