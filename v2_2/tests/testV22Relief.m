function tests = testV22Relief
%TESTV22RELIEF V22-T12: relief-anomaly layer (local trend, anomaly, connected features, labels).
%   Synthetic surfaces only, core MATLAB, no graphics. Features are INDIRECT EVIDENCE from simulation only.
%   Shared file: injected-feature and soil-movement tests are added below the relief-maths tests.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))),'matlab')));
end

function S = makeS(fn)
% 0.5 m grid, cell centres over [-40 40] x [-30 30], elevation fn(X,Y).
x = -40:0.5:40; y = -30:0.5:30;
[X, Y] = meshgrid(x, y);
S = struct('x', x, 'y', y, 'Z', fn(X, Y), 'cell_m', 0.5, 'source', "synthetic", 'label', "test");
end

%% Relief maths (localTrend, reliefAnomaly, findFeatures)

function testReliefTiltedPlaneNoiseHasNoAnomaly(tc)
rs = RandStream('mt19937ar', 'Seed', 12);
N = 0.02 * randn(rs, 121, 161);
S = makeS(@(X, Y) 3 + 0.02*X + 0.01*Y + N);
A = mgv22.relief.reliefAnomaly(S);
b = round(A.radius_m / S.cell_m);
inner = A.D(b+1:end-b, b+1:end-b);
verifyLessThan(tc, max(abs(inner(:))), 0.1);
verifyEqual(tc, height(mgv22.relief.findFeatures(A, S)), 0);
end

function testReliefFlatPlaneNoFeatures(tc)
S = makeS(@(X, Y) 5 + 0*X);
F = mgv22.relief.findFeatures(mgv22.relief.reliefAnomaly(S), S);
verifyEqual(tc, height(F), 0);
verifyEqual(tc, F.Properties.VariableNames, {'id', 'type', 'x_east_m', 'y_north_m', 'area_m2', 'depth_m', ...
    'length_m', 'width_m', 'label'});
end

function testReliefCraterFound(tc)
S = makeS(@(X, Y) 0.01*X + 0.005*Y - 0.65*max(0, 1 - ((X - 10).^2 + (Y - 5).^2)/9));
F = mgv22.relief.findFeatures(mgv22.relief.reliefAnomaly(S), S);
verifyEqual(tc, height(F), 1);
verifyEqual(tc, F.type(1), "crater");
verifyLessThanOrEqual(tc, hypot(F.x_east_m(1) - 10, F.y_north_m(1) - 5), S.cell_m);
verifyGreaterThanOrEqual(tc, F.depth_m(1), 0.5);
verifyLessThanOrEqual(tc, F.depth_m(1), 0.75);
end

function testReliefTrenchIsLinear(tc)
S = makeS(@(X, Y) 0.01*X - 0.7*(abs(Y) <= 0.5 & abs(X) <= 15));
F = mgv22.relief.findFeatures(mgv22.relief.reliefAnomaly(S), S);
verifyEqual(tc, height(F), 1);
verifyEqual(tc, F.type(1), "trench");
verifyGreaterThanOrEqual(tc, F.length_m(1), 25);
end

function testReliefSmallPitIsFoxholeSize(tc)
S = makeS(@(X, Y) 0.01*Y - 0.7*(hypot(X + 20, Y + 10) <= 0.5));
F = mgv22.relief.findFeatures(mgv22.relief.reliefAnomaly(S), S);
verifyEqual(tc, height(F), 1);
verifyEqual(tc, F.type(1), "pit (foxhole-size)");
verifyEqual(tc, [F.x_east_m(1) F.y_north_m(1)], [-20 -10], 'AbsTol', S.cell_m);
end

function testReliefRaisedRidgeIsBerm(tc)
S = makeS(@(X, Y) 0.01*X + 0.6*(abs(Y - 10) <= 0.5 & abs(X) <= 10));
F = mgv22.relief.findFeatures(mgv22.relief.reliefAnomaly(S), S);
verifyEqual(tc, height(F), 1);
verifyEqual(tc, F.type(1), "berm");
end

function testReliefNaNCellsStayNaN(tc)
S = makeS(@(X, Y) 0.02*X);
[X, Y] = meshgrid(S.x, S.y);
hole = X >= 0 & X <= 5 & Y >= 0 & Y <= 5;
S.Z(hole) = NaN;
A = mgv22.relief.reliefAnomaly(S);
verifyTrue(tc, all(isnan(A.D(hole))));
verifyTrue(tc, all(isnan(A.trend(hole))));
verifyTrue(tc, all(isfinite(A.D(~hole))));
verifyEqual(tc, height(mgv22.relief.findFeatures(A, S)), 0);
end

function testReliefRadiusMustExceedCell(tc)
S = makeS(@(X, Y) 0*X);
verifyError(tc, @() mgv22.relief.localTrend(S, 0.5), 'mgv22:InvalidRelief');
verifyError(tc, @() mgv22.relief.reliefAnomaly(S, 0.3), 'mgv22:InvalidRelief');
end

function testReliefLabelsSayIndirectEvidenceSimulation(tc)
S = makeS(@(X, Y) -0.65*max(0, 1 - (X.^2 + Y.^2)/9));
A = mgv22.relief.reliefAnomaly(S);
F = mgv22.relief.findFeatures(A, S);
verifyGreaterThan(tc, height(F), 0);
for t = [A.label; F.label]'
    verifyTrue(tc, contains(t, "INDIRECT EVIDENCE") && contains(t, "SIMULATION"), t);
end
verifyEqual(tc, F.id(1), "RF-01");
end
