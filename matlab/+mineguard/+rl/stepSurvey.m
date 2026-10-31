function [S, r, info] = stepSurvey(S, action, G, cfg)
%STEPSURVEY One decision of the MG-013 coverage environment (deterministic, observation-only).
%   [S, r, info] = mineguard.rl.stepSurvey(S, action, G, cfg)
%   action: the ID of the next survey cell (1..N). The rules, following MG-012 Section 3:
%     malformed (NaN, noninteger, out of 1..N) or unreachable (illegal cell, exclusion-crossing
%       leg, current cell): rejected, position unchanged, penalty w_bad, decision counted
%     a leg that would exceed the remaining D_max or T_max: NOT executed; terminates BUDGET_EXHAUSTED
%     legal leg: the vehicle moves along the precomputed MG-005 simulatePose samples. Every cell
%       touched by a sample becomes visited. A target cell that was already visited counts as a revisit.
%   Reward r = w_cov*dC - w_dist*dL - w_time*dT - w_visit*revisit - w_bad*invalid - w_step
%              - w_end*failure_termination,
%   with dC = new legal cells / N_legal, dL = leg length / D_max, dT = leg time / T_max.
%   info.components = [dC dL dT revisit invalid 1 failEnd r]; it is also appended to S.reward_log.
%   Termination reasons: COVERAGE_GOAL, BUDGET_EXHAUSTED, MAX_STEPS, NO_LEGAL_ACTION.
if S.done
    error('mineguard:EpisodeDone', 'MineGuard RL: step called after termination (%s); call resetSurvey.', S.reason);
end
w = cfg.w;
S.decisions = S.decisions + 1;
nLegal = nnz(G.legal);
dC = 0; dL = 0; dT = 0; revisit = 0; invalid = 0; failEnd = 0;
a = double(action);
valid = isscalar(a) && isfinite(a) && a == fix(a) && a >= 1 && a <= G.N;
if valid
    valid = G.reach(S.cell, a);
end
status = "MOVED";
if ~valid
    invalid = 1; S.invalid_actions = S.invalid_actions + 1; status = "REJECTED_INVALID";
elseif S.dist_m + G.leg_len(S.cell, a) > cfg.D_max_m + 1e-9 || S.t_s + G.leg_dur(S.cell, a) > cfg.T_max_s + 1e-9
    S.done = true; S.reason = "BUDGET_EXHAUSTED"; failEnd = 1; status = "REJECTED_BUDGET";
else
    revisit = double(S.visited(a));
    S.revisits = S.revisits + revisit;
    cells = G.leg_cells{S.cell, a};
    newCells = cells(~S.visited(cells) & G.legal(cells));
    dC = numel(newCells) / nLegal;
    S.visited(cells) = true;
    dL = G.leg_len(S.cell, a) / cfg.D_max_m;
    dT = G.leg_dur(S.cell, a) / cfg.T_max_s;
    S.pose_xy = [S.pose_xy; G.leg_xy{S.cell, a}];
    S.pose_t = [S.pose_t; S.t_s + G.leg_trel{S.cell, a}];
    S.dist_m = S.dist_m + G.leg_len(S.cell, a);
    S.t_s = S.t_s + G.leg_dur(S.cell, a);
    S.cell = a;
end
if ~S.done
    if all(S.visited(G.legal))
        S.done = true; S.reason = "COVERAGE_GOAL";
    elseif ~any(G.reach(S.cell, :))
        S.done = true; S.reason = "NO_LEGAL_ACTION"; failEnd = 1;
    elseif S.decisions >= cfg.max_decisions
        S.done = true; S.reason = "MAX_STEPS"; failEnd = 1;
    end
end
r = w.cov * dC - w.dist * dL - w.time * dT - w.visit * revisit - w.bad * invalid - w.step - w.end * failEnd;
comp = [dC dL dT revisit invalid 1 failEnd r];
S.reward_log(end+1, :) = comp;
info = struct('status', status, 'components', comp, 'reason', S.reason);
end
