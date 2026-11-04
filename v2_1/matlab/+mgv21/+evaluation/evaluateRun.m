function R = evaluateRun(events, truth, runState, opts)
%EVALUATERUN Post-mission INTERACTIVE SYNTHETIC DEMO evaluation of frozen suspected events against private truth.
%   R = mgv21.evaluation.evaluateRun(events, truth, runState)
%   R = mgv21.evaluation.evaluateRun(events, truth, runState, RMatch=1.0)
%   events    FROZEN final event positions: struct array with x_est_m, y_est_m, or N-by-2 [x y] ENU metres
%   truth     PrivateTargetTruth (mgv21.placement.placeTargets / lockScenario(...).truth)
%   runState  the engine phase; must be terminal (COMPLETE, ABORTED, FAILED), else mgv21:EvaluationTooEarly
%   Metrics are mgv2.eval.evaluateEvents unchanged: one-to-one greedy match within RMatch (default 1.0 m, as V2);
%   TP matched events, FP unmatched events (a duplicate on one target is FP), FN unmatched targets, TN NaN
%   (undefined at event level), precision/recall NaN when the denominator is 0. Adds mean/max match distance
%   (NaN with no match), matched_target_index (row k of truth.targets matched by event matched_event_index(k):
%   the SAME one-to-one pairs, 1-by-0 when there is no match; a target is missed iff its row is absent) and the
%   notice: this is NOT held-out scientific accuracy. placement_seed is meaningful only for RANDOM placement. No sealed V1/V2 TEST group is
%   touched (evaluateEvents is called with an explicit RMatch and a V2.1 truth only).
arguments
    events
    truth struct
    runState
    opts.RMatch (1,1) double {mustBePositive, mustBeFinite} = mgv21.contract().r_match_m
end
c = mgv21.contract();
runState = string(runState);
if ~(isscalar(runState) && ismember(runState, c.terminal_phases))
    error('mgv21:EvaluationTooEarly', 'Evaluation runs only after the mission ends (COMPLETE, ABORTED or FAILED); phase is "%s".', strjoin(runState, ","));
end
if isstruct(events)
    if ~isempty(events) && ~all(isfield(events, {'x_est_m', 'y_est_m'})), error('mgv21:InvalidEvents', 'Event structs need x_est_m and y_est_m.'); end
    if isempty(events), xy = zeros(0, 2); else, xy = [[events.x_est_m]' [events.y_est_m]']; end
elseif isnumeric(events) && (isempty(events) || size(events, 2) == 2)
    xy = reshape(double(events), [], 2);
else
    error('mgv21:InvalidEvents', 'events must be an N-by-2 matrix or a struct array with x_est_m, y_est_m.');
end
if ~all(isfinite(xy), 'all'), error('mgv21:InvalidEvents', 'Event positions must be finite.'); end
if ~(isfield(truth, 'schema_version') && truth.schema_version == c.schemas.truth)
    error('mgv21:InvalidEvents', 'truth must be a PrivateTargetTruth (%s).', c.schemas.truth);
end
TT = struct('group_id', "V21-INTERACTIVE", 'split', "V21-DEMO", 'family', "V21-" + truth.preset_id, 'demo_fixture', false, ...
    'targets', truth.targets);
E = mgv2.eval.evaluateEvents(xy, TT, opts.RMatch);             % the V2 evaluator, unchanged
pairs = greedyPairs(xy, [truth.targets.x_east_m truth.targets.y_north_m], E.r_match_m);
if ~(isequal(pairs(:, 1)', E.matched_event_index) && isequal(pairs(:, 3)', E.match_error_m))
    error('mgv21:EvaluationMismatch', 'Target assignment disagrees with mgv2.eval.evaluateEvents; refusing to report.');
end
me = E.match_error_m;
if isempty(me), mean_e = NaN; max_e = NaN; else, mean_e = mean(me); max_e = max(me); end
R = struct('schema_version', c.schemas.eval, 'notice', c.eval_label, 'run_state', runState, 'r_match_m', E.r_match_m, ...
    'n_events', E.n_events, 'n_targets', E.n_targets, 'TP', E.TP, 'FP', E.FP, 'FN', E.FN, 'TN', E.TN, ...
    'precision', E.precision, 'recall', E.recall, 'FN_visible', E.FN_visible, 'FN_no_signature', E.FN_no_signature, ...
    'TP_no_signature', E.TP_no_signature, 'match_error_m', me, 'mean_match_error_m', mean_e, 'max_match_error_m', max_e, ...
    'matched_event_index', E.matched_event_index, 'matched_target_index', pairs(:, 2)', ...
    'placement_mode', truth.mode, 'placement_seed', truth.seed);
end
