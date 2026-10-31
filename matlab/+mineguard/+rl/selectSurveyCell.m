function action = selectSurveyCell(observation, allowedCells, policy)
%SELECTSURVEYCELL Choose the next survey cell (frozen mg-contract/1.0 API, MG-013).
%   action = mineguard.rl.selectSurveyCell(observation, allowedCells, policy)
%   observation  - struct: schema_version "mg013-obs/1.0", scenario_id, layout_id, vector (2N+5 x 1)
%   allowedCells - table: cell_id (1..N, MG-005 order), x_center_m, y_center_m, is_legal,
%                  reachable_from_current, is_visited
%   policy       - struct: kind "ppo" (trained rlPPOAgent in policy.agent) or "untrained_test"
%                  (deterministic: lowest-ID reachable unvisited cell, else lowest-ID reachable),
%                  plus version, layout_id, n_cells, checksum and training_split provenance
%   action       - int32 cell ID. The policy's choice is returned UNCHANGED. If a PPO policy picks
%                  an unreachable cell, the environment (stepSurvey) rejects and penalises it;
%                  this function never silently swaps in a legal action.
%   No input may carry truth: any field named in mineguard.contract.truthFieldNames(), or any
%   nested table, is rejected (mineguard:InvalidPolicyInput). PPO uses the deterministic
%   (non-exploration) policy unless policy.use_exploration is true (seeded stochastic evaluation,
%   driven by the caller's RNG).
id = 'mineguard:InvalidPolicyInput';
if ~isstruct(observation) || ~isscalar(observation) || ~isempty(setxor(string(fieldnames(observation))', ...
        ["schema_version","scenario_id","layout_id","vector"]))
    error(id, 'MineGuard RL: observation must have exactly schema_version, scenario_id, layout_id, vector.');
end
if string(observation.schema_version) ~= "mg013-obs/1.0"
    error(id, 'MineGuard RL: unsupported observation schema_version.');
end
if ~istable(allowedCells) || ~isequal(string(allowedCells.Properties.VariableNames), ...
        ["cell_id","x_center_m","y_center_m","is_legal","reachable_from_current","is_visited"])
    error(id, 'MineGuard RL: allowedCells must be the 6-column allowed-cell table.');
end
if ~isstruct(policy) || ~isscalar(policy) || ~all(isfield(policy, {'kind','version','layout_id','n_cells'}))
    error(id, 'MineGuard RL: policy needs kind, version, layout_id and n_cells.');
end
leak = local_leak(policy, "policy");
if strlength(leak) == 0, leak = local_leak(observation, "observation"); end
if strlength(leak) > 0
    error(id, 'MineGuard RL: %s carries a truth field; PPO must never see hidden truth.', leak);
end
N = height(allowedCells);
v = observation.vector;
if ~isnumeric(v) || ~isequal(size(v), [2*N+5 1]) || any(~isfinite(v)) || any(v < 0 | v > 1)
    error(id, 'MineGuard RL: observation.vector must be a finite (2N+5)x1 vector in [0,1] (N = %d).', N);
end
if ~isequal(allowedCells.cell_id(:)', 1:N) || policy.n_cells ~= N || string(policy.layout_id) ~= string(observation.layout_id)
    error(id, 'MineGuard RL: cell order, cell count or layout_id does not match the policy.');
end
if ~isequal(double(allowedCells.is_visited(:)), v(3:N+2)) || ~isequal(double(allowedCells.reachable_from_current(:)), v(N+3:2*N+2))
    error(id, 'MineGuard RL: observation masks disagree with allowedCells.');
end
switch string(policy.kind)
    case "ppo"
        agent = policy.agent;
        agent.UseExplorationPolicy = isfield(policy, 'use_exploration') && policy.use_exploration;   % default: deterministic
        a = getAction(agent, {v});
        if iscell(a), a = a{1}; end
        action = int32(a);
    case "untrained_test"
        r = find(allowedCells.reachable_from_current & ~allowedCells.is_visited, 1);
        if isempty(r), r = find(allowedCells.reachable_from_current, 1); end
        if isempty(r)
            error(id, 'MineGuard RL: no reachable cell for the untrained test policy.');
        end
        action = int32(r);
    otherwise
        error(id, 'MineGuard RL: unknown policy kind "%s".', string(policy.kind));
end
end

function leak = local_leak(v, path)
leak = "";
if istable(v)
    leak = path + " (table)"; return
end
if iscell(v)
    for i = 1:numel(v)
        leak = local_leak(v{i}, path + "{" + i + "}"); if strlength(leak) > 0, return; end
    end
    return
end
if ~isstruct(v), return; end
f = string(fieldnames(v))';
bad = intersect(f, mineguard.contract.truthFieldNames());
if ~isempty(bad), leak = path + "." + bad(1); return; end
for k = 1:numel(f)
    if f(k) == "agent", continue; end     % the trained network object itself is not a struct of truth
    for i = 1:numel(v)
        leak = local_leak(v(i).(f(k)), path + "." + f(k)); if strlength(leak) > 0, return; end
    end
end
end
