function R = falseAlarmRate(fp, area_m2, conf)
%FALSEALARMRATE False alarms per hectare with an exact Poisson confidence interval on the count.
%   R = mgv22.evaluation.falseAlarmRate(fp, area_m2)          95% interval
%   R = mgv22.evaluation.falseAlarmRate(fp, area_m2, conf)
%   V22-T10. fp is the number of false "suspected anomaly" marks over a surveyed area of area_m2 square metres.
%   Base MATLAB only (gammaincinv). Zero false alarms still has an upper bound: -log(0.025) = 3.69 per hectare
%   when 1 ha was surveyed. Fields: per_ha, lo_per_ha, hi_per_ha, fp, area_ha, conf. Simulation counts only.
if nargin < 3 || isempty(conf), conf = 0.95; end
if ~isnumeric(fp) || ~isscalar(fp) || ~isfinite(fp) || fp < 0 || fp ~= round(fp) ...
        || ~isnumeric(area_m2) || ~isscalar(area_m2) || ~isfinite(area_m2) || area_m2 <= 0 ...
        || ~isnumeric(conf) || ~isscalar(conf) || ~(conf > 0 && conf < 1)
    error('mgv22:InvalidCounts', 'Need an integer fp >= 0, area_m2 > 0 and 0 < conf < 1.');
end
fp = double(fp); area_ha = double(area_m2) / 1e4; a2 = (1 - conf) / 2;
if fp == 0, lo = 0; else, lo = gammaincinv(a2, fp); end
hi = gammaincinv(1 - a2, fp + 1);
R = struct('per_ha', fp / area_ha, 'lo_per_ha', lo / area_ha, 'hi_per_ha', hi / area_ha, ...
    'fp', fp, 'area_ha', area_ha, 'conf', conf);
end
