function tests = testV22ReliefFeatures
%TESTV22RELIEFFEATURES V22-T12: SYNTHETIC conflict features and SIMULATED soil movement (mgv22.relief).
%   Synthetic surfaces only, core MATLAB, no graphics. Nothing here is survey data or a detection result.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))),'matlab')));
end

function S = makeS()
% 0.5 m grid over [-40 40] x [-30 30] (cell centres on the 0.5 m lattice), tilted plane plus small smooth relief.
x = -40:0.5:40; y = -30:0.5:30;
[X, Y] = meshgrid(x, y);
S = struct('x', x, 'y', y, 'Z', 0.02*X - 0.01*Y + 0.05*sin(X/7).*cos(Y/5), 'cell_m', 0.5, ...
    'source', "synthetic", 'label', "test surface");
end

function v = zAt(S, Z, x, y)
v = Z(abs(S.y - y) < 1e-9, abs(S.x - x) < 1e-9);
end

function testInjectDefaultSpec(tc)
S = makeS(); spec = mgv22.relief.defaultFeatureSpec();
[S2, truth] = mgv22.relief.injectFeatures(S, spec);
tc.verifyEqual(height(truth), 6);
tc.verifyEqual(truth.id(1), "CF-01");
tc.verifyEqual(sum(truth.type == "trench"), 1);
tc.verifyEqual(zAt(S, S.Z, 15, 10) - zAt(S, S2.Z, 15, 10), 0.65, 'AbsTol', 1e-9);
tc.verifyEqual(zAt(S, S2.Z, 35, -25), zAt(S, S.Z, 35, -25), 'AbsTol', 1e-12);
tc.verifyEqual(S2.source, S.source);
tc.verifySubstring(char(S2.label), 'SYNTHETIC');
end

function testInjectKeepsNaN(tc)
S = makeS(); S.Z(S.y == 10, S.x == 15) = NaN; S.Z(1, 1) = NaN;
S2 = mgv22.relief.injectFeatures(S, mgv22.relief.defaultFeatureSpec());
tc.verifyEqual(isnan(S2.Z), isnan(S.Z));
end

function testInjectInvalidType(tc)
spec = mgv22.relief.defaultFeatureSpec(); spec(1).type = "bunker";
tc.verifyError(@() mgv22.relief.injectFeatures(makeS(), spec), 'mgv22:InvalidRelief');
spec = mgv22.relief.defaultFeatureSpec(); spec(2).depth_m = NaN;
tc.verifyError(@() mgv22.relief.injectFeatures(makeS(), spec), 'mgv22:InvalidRelief');
end

function testSoilMovementChangeAndAreas(tc)
S = makeS();
[before, after] = mgv22.relief.simulateSoilMovement(S);
tc.verifyEqual(before.Z, S.Z);
tc.verifyGreaterThan(max(abs(after.Z(:) - before.Z(:))), 0);
C = mgv22.relief.surfaceChange(before, after);
tc.verifyGreaterThan(C.eroded_area_m2, 0);
tc.verifyGreaterThan(C.deposited_area_m2, 0);
tc.verifyEqual(C.moved_area_m2, C.eroded_area_m2 + C.deposited_area_m2, 'AbsTol', 1e-9);
tc.verifySubstring(char(after.label), 'SIMULATED');
tc.verifySubstring(char(C.label), 'SIMULATION');
tc.verifySubstring(char(C.label), 'INDIRECT EVIDENCE');
end

function testSoilMovementDeterministic(tc)
S = makeS();
[~, a1] = mgv22.relief.simulateSoilMovement(S, Seed=7);
[~, a2] = mgv22.relief.simulateSoilMovement(S, Seed=7);
tc.verifyEqual(a1.Z, a2.Z);
end

function testSurfaceChangeIdentical(tc)
S = makeS();
C = mgv22.relief.surfaceChange(S, S);
tc.verifyEqual(nnz(C.moved), 0);
tc.verifyEqual(C.moved_area_m2, 0);
end

function testSurfaceChangeSizeMismatch(tc)
S = makeS(); T = S; T.Z = T.Z(1:end-1, :); T.y = T.y(1:end-1);
tc.verifyError(@() mgv22.relief.surfaceChange(S, T), 'mgv22:InvalidRelief');
end
