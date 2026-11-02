function state = advanceStoryboard(state, action)
%ADVANCESTORYBOARD Pure, deterministic presentation state machine.
%   CITY_CONTEXT -> CAMPUS_CONTEXT -> SIMULATION_HANDOFF.
%   Handoff is a title card; it does not start or change a mission.
stages = ["CITY_CONTEXT", "CAMPUS_CONTEXT", "SIMULATION_HANDOFF"];
if nargin < 1 || isempty(state), state = stages(1); end
state = string(state); action = string(action);
if ~isscalar(state) || ~any(state == stages) || ~isscalar(action) || ~any(action == ["NEXT", "BACK", "RESET"])
    error('mgenh010:InvalidStoryboard', 'Use a known stage and NEXT, BACK or RESET.');
end
if action == "RESET", state = stages(1); return; end
idx = find(stages == state, 1);
if action == "NEXT", idx = min(idx+1, numel(stages)); else, idx = max(idx-1, 1); end
state = stages(idx);
end
