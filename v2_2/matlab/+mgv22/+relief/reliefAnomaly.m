function A = reliefAnomaly(S, radius_m, varargin)
%RELIEFANOMALY Surface minus its local trend: relief anomaly as INDIRECT EVIDENCE (V22-T12).
%   A = mgv22.relief.reliefAnomaly(S)            radius_m = 5 m (window 10 m, wider than a 5.9 m crater, HALO Angola)
%   A = mgv22.relief.reliefAnomaly(S, radius_m, Iterations=3, RobustM=0.15)   options go to mgv22.relief.localTrend
%   The defaults were chosen on the simulated TRAINING_FIELD_A surface (0.5 m grid) and checked on held-out feature
%   positions (testV22ReliefRecovery); they are not tuned on any real ground.
%   Fields: D (S.Z - trend, ny-by-nx; negative = below trend, NaN where no data), trend, radius_m, label.
%   A relief anomaly is indirect evidence of ground disturbance in a simulated surface, never a detection.
if nargin < 2 || isempty(radius_m), radius_m = 5; end
T = mgv22.relief.localTrend(S, radius_m, varargin{:});
D = S.Z - T;
D(isnan(S.Z)) = NaN;
A = struct('D', D, 'trend', T, 'radius_m', radius_m, ...
    'label', "INDIRECT EVIDENCE – relief anomaly (SIMULATION)");
end
