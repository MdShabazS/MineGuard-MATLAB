function lines = formatReport(R)
%FORMATREPORT Text lines for the post-run results panel; undefined ratios are shown as "undefined", never 0.
%   lines = mgv21.evaluation.formatReport(R)      R from mgv21.evaluation.evaluateRun
%   The placement seed is shown for RANDOM placement only.
pct = @(x) fmt(x, @(v) sprintf('%.1f %%', 100 * v));
mm = @(x) fmt(x, @(v) sprintf('%.2f m', v));
lines = [ ...
    string(R.notice)
    "SIMULATION ONLY - every event is a SUSPECTED anomaly; targets are private synthetic hypotheses."
    sprintf("Run ended: %s   placement: %s   match radius: %.2f m", R.run_state, placementText(R), R.r_match_m)
    sprintf("Suspected events: %d   synthetic targets: %d", R.n_events, R.n_targets)
    sprintf("TP %d   FP %d   FN %d   TN undefined at event level", R.TP, R.FP, R.FN)
    "Precision: " + pct(R.precision) + "   Recall: " + pct(R.recall)
    "Match distance: mean " + mm(R.mean_match_error_m) + ", max " + mm(R.max_match_error_m)
    sprintf("Missed targets with no observable signature (expected blind spot): %d", R.FN_no_signature)];
end

function s = placementText(R)
% The seed identifies a RANDOM layout; for NONE and MANUAL it has no meaning and is not shown.
s = string(R.placement_mode);
if s == "RANDOM", s = s + sprintf(" (seed %d)", R.placement_seed); end
end

function s = fmt(x, f)
if isnan(x), s = "undefined"; else, s = string(f(x)); end
end
