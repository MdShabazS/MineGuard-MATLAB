function cfg = defaultEnvConfig()
%DEFAULTENVCONFIG Versioned MG-013 environment, budget and reward configuration.
%   The budget is shared by PPO and the fixed grid. Reward weights are the MG-012 illustrative
%   set (non-negative, finite); they are educational parameters, not fitted physical utilities.
%   The coverage-only observation layout "cov-2N+5-v1" is
%     [x_norm; y_norm; visited(N); reachable(N); remaining_time; remaining_distance; elapsed_time].
cfg = struct( ...
    'env_version', "mg013-env-1.0", ...
    'layout_id', "cov-2N+5-v1", ...
    'D_max_m', 60, ...               % shared maximum travel distance
    'T_max_s', 30, ...               % shared maximum simulated mission time
    'max_decisions', 50, ...         % shared decision budget (invalid actions count)
    'start_cell', 1, ...             % SW cell = first MG-005 serpentine waypoint
    'w', struct('cov', 1, 'dist', 0.1, 'time', 0.1, 'visit', 0.02, 'bad', 0.1, 'step', 0.001, 'end', 0.05));
end
