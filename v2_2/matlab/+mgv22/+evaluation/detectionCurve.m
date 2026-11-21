function C = detectionCurve(scores, isTP, nTargets, area_m2)
%DETECTIONCURVE Detection fraction against false alarms per hectare as the score threshold is lowered.
%   C = mgv22.evaluation.detectionCurve(scores, isTP, nTargets, area_m2)
%   V22-T10. scores: N event scores; isTP: N logicals (event matched a placed target); nTargets: targets placed;
%   area_m2: surveyed area. Thresholds are +Inf then the unique scores in descending order; at each threshold t
%   the events with score >= t are kept. Fields (column vectors): threshold, detection (= n_tp/nTargets, NaN when
%   nTargets is 0), fa_per_ha, n_tp, n_fp. Both curves are non-decreasing as t falls. Simulation counts only.
scores = double(scores(:)); isTP = logical(isTP(:));
if numel(isTP) ~= numel(scores) || any(isnan(scores))
    error('mgv22:InvalidCounts', 'scores and isTP must have the same length and no NaN scores.');
end
if ~isnumeric(nTargets) || ~isscalar(nTargets) || ~isfinite(nTargets) || nTargets < 0 || nTargets ~= round(nTargets) ...
        || ~isnumeric(area_m2) || ~isscalar(area_m2) || ~isfinite(area_m2) || area_m2 <= 0
    error('mgv22:InvalidCounts', 'Need an integer nTargets >= 0 and area_m2 > 0.');
end
t = [Inf; flip(reshape(unique(scores(scores < Inf)), [], 1))];
n_tp = zeros(numel(t), 1); n_fp = n_tp;
for i = 1:numel(t)
    keep = scores >= t(i);
    n_tp(i) = sum(keep & isTP); n_fp(i) = sum(keep & ~isTP);
end
if nTargets == 0, detection = nan(size(n_tp)); else, detection = n_tp / double(nTargets); end
C = struct('threshold', t, 'detection', detection, 'fa_per_ha', n_fp / (double(area_m2) / 1e4), ...
    'n_tp', n_tp, 'n_fp', n_fp);
end
