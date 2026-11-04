function pairs = greedyPairs(xy, tx, rMatch)
%GREEDYPAIRS [event target distance] rows of the one-to-one assignment, exactly as mgv2.eval.evaluateEvents.
%   Same distance matrix, same stable sort of D(:) (ties broken by linear index: lower event index, then lower
%   target index, as MATLAB sort is stable on column-major order), same "dd > rMatch -> stop" rule. evaluateRun
%   checks the event indices and distances against the V2 result, so the two can never silently disagree.
nE = size(xy, 1); nT = size(tx, 1);
pairs = zeros(0, 3); usedE = false(nE, 1); usedT = false(nT, 1);
if nE == 0 || nT == 0, return; end
D = hypot(xy(:,1) - tx(:,1)', xy(:,2) - tx(:,2)');
[dd, ord] = sort(D(:)); [ie, it] = ind2sub(size(D), ord);
for k = 1:numel(dd)
    if dd(k) > rMatch, break; end
    if ~usedE(ie(k)) && ~usedT(it(k)), usedE(ie(k)) = true; usedT(it(k)) = true; pairs(end+1, :) = [ie(k) it(k) dd(k)]; end %#ok<AGROW>
end
end
