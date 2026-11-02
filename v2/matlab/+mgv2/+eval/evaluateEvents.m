function R = evaluateEvents(xy, TargetTruth, rMatch)
%EVALUATEEVENTS Independent EVALUATOR: event-level TP/FP/FN against private truth (V2-004 §5). Not public.
%   R = mgv2.eval.evaluateEvents(xy, TargetTruth)          rMatch from mgv2.eval.splitManifest (1.0 m)
%   R = mgv2.eval.evaluateEvents(xy, TargetTruth, rMatch)
%   xy           N-by-2 FROZEN predicted event positions (x_est_m, y_est_m), or an event struct array
%   TargetTruth  evaluator-only truth from mgv2.eval.buildScenario
%   Unit: event level. One-to-one greedy assignment in increasing distance, a match only if distance <= rMatch.
%   TP = matched events; FP = unmatched events (duplicates on one target count as FP); FN = unmatched targets.
%   TN is UNDEFINED at event level (reported as NaN, never 0). Precision TP/(TP+FP), recall TP/(TP+FN):
%   NaN ("undefined / NA") when the denominator is zero, never coerced to 0 or 100 %.
%   Also reports FN split by surface signature (NONE = no observable effect, an expected blind spot) and the
%   localisation error of every match. A DEMO FIXTURE truth is flagged and must be excluded from accuracy
%   reports by the caller (R.demo_fixture).
if nargin < 3, rMatch = mgv2.eval.splitManifest().r_match_m; end
if isstruct(xy), xy = [[xy.x_est_m]' [xy.y_est_m]']; end
xy = reshape(xy, [], 2);
T = TargetTruth.targets; tx = [T.x_east_m T.y_north_m];
nE = size(xy, 1); nT = height(T);
D = hypot(xy(:,1) - tx(:,1)', xy(:,2) - tx(:,2)');
pairs = zeros(0, 3); usedE = false(nE, 1); usedT = false(nT, 1);
if nE > 0 && nT > 0
    [dd, ord] = sort(D(:)); [ie, it] = ind2sub(size(D), ord);
    for k = 1:numel(dd)
        if dd(k) > rMatch, break; end
        if ~usedE(ie(k)) && ~usedT(it(k)), usedE(ie(k)) = true; usedT(it(k)) = true; pairs(end+1, :) = [ie(k) it(k) dd(k)]; end %#ok<AGROW>
    end
end
TP = size(pairs, 1); FP = nE - TP; FN = nT - TP;
nd = @(a, b) a / b; if TP + FP == 0, prec = NaN; else, prec = nd(TP, TP + FP); end
if TP + FN == 0, rec = NaN; else, rec = nd(TP, TP + FN); end
sigNone = T.surface_signature == "NONE";
R = struct('group_id', TargetTruth.group_id, 'split', TargetTruth.split, 'family', TargetTruth.family, ...
    'demo_fixture', TargetTruth.demo_fixture, 'unit', "event", 'r_match_m', rMatch, 'n_events', nE, 'n_targets', nT, ...
    'TP', TP, 'FP', FP, 'FN', FN, 'TN', NaN, 'precision', prec, 'recall', rec, ...
    'FN_visible', nnz(~usedT & ~sigNone), 'FN_no_signature', nnz(~usedT & sigNone), ...
    'TP_no_signature', nnz(usedT & sigNone), 'match_error_m', pairs(:, 3)', 'matched_event_index', pairs(:, 1)');
end
