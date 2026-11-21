function [lo, hi] = clopperPearson(k, n, conf)
%CLOPPERPEARSON Exact (Clopper-Pearson) two-sided binomial confidence interval.
%   [lo, hi] = mgv22.evaluation.clopperPearson(k, n)          95% interval
%   [lo, hi] = mgv22.evaluation.clopperPearson(k, n, conf)    conf in (0,1)
%   V22-T10. k successes out of n trials (k may be a vector, n scalar or the same size). Base MATLAB only:
%   uses betaincinv, no Statistics Toolbox. The interval is conservative (coverage >= conf), so a small n gives
%   a wide interval: with 0 of 12 found the true rate may still be about 26%. Simulation counts only.
if nargin < 3 || isempty(conf), conf = 0.95; end
if ~isnumeric(k) || ~isnumeric(n) || ~isnumeric(conf) || isempty(k) || isempty(n) || ~isscalar(conf) ...
        || ~(conf > 0 && conf < 1) || any(~isfinite(k(:))) || any(~isfinite(n(:))) ...
        || any(k(:) ~= round(k(:))) || any(n(:) ~= round(n(:))) || any(n(:) < 1) || any(k(:) < 0) ...
        || ~(isscalar(n) || isequal(size(n), size(k)))
    error('mgv22:InvalidCounts', 'Need integers 0 <= k <= n, n >= 1 and 0 < conf < 1.');
end
k = double(k); n = double(n) + zeros(size(k));
if any(k(:) > n(:)), error('mgv22:InvalidCounts', 'Need integers 0 <= k <= n, n >= 1 and 0 < conf < 1.'); end
a2 = (1 - conf) / 2;
lo = zeros(size(k)); hi = ones(size(k));
z = k == 0; f = k == n; m = ~z & ~f;
hi(z) = 1 - a2 .^ (1 ./ n(z));
lo(f) = a2 .^ (1 ./ n(f));
lo(m) = betaincinv(a2, k(m), n(m) - k(m) + 1);
hi(m) = betaincinv(1 - a2, k(m) + 1, n(m) - k(m));
end
