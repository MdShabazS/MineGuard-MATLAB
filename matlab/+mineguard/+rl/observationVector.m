function v = observationVector(S, G, cfg)
%OBSERVATIONVECTOR Coverage-only observation, layout "cov-2N+5-v1" (MG-012 Section 4). Uses no truth.
%   v = [x_norm; y_norm; visited(N); reachable(N); rem_time; rem_dist; elapsed], length 2N+5.
%   Positions are normalised over the scenario bounds. Time and distance fractions are clamped
%   to [0,1]. The reachable mask is the static legal-leg mask from the current cell.
b = G.bounds;
p = G.centers(S.cell, :);
v = [ (p(1) - b(1)) / (b(2) - b(1)); (p(2) - b(3)) / (b(4) - b(3)); ...
      double(S.visited); double(G.reach(S.cell, :)'); ...
      min(1, max(0, 1 - S.t_s / cfg.T_max_s)); min(1, max(0, 1 - S.dist_m / cfg.D_max_m)); ...
      min(1, max(0, S.t_s / cfg.T_max_s)) ];
end
