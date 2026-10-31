function S = resetSurvey(G, cfg)
%RESETSURVEY Deterministic episode start for the MG-013 coverage environment (no randomness).
%   The vehicle starts at cfg.start_cell centre with t = 0 and distance = 0. Its starting cell
%   counts as visited, because the first pose sample is inside it (same rule as MG-005).
if ~G.legal(cfg.start_cell)
    error('mineguard:InvalidScenario', 'MineGuard RL: start cell %d is not legal in this scenario.', cfg.start_cell);
end
S = struct('cell', cfg.start_cell, 't_s', 0, 'dist_m', 0, 'decisions', 0, 'visited', false(G.N, 1), ...
    'invalid_actions', 0, 'revisits', 0, 'done', false, 'reason', "", ...
    'pose_xy', G.centers(cfg.start_cell, :), 'pose_t', 0, 'reward_log', zeros(0, 8));
S.visited(cfg.start_cell) = true;
if ~any(G.reach(cfg.start_cell, :))
    S.done = true; S.reason = "NO_LEGAL_ACTION";
end
end
