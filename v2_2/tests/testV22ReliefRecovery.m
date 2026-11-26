function tests = testV22ReliefRecovery
%TESTV22RELIEFRECOVERY V22-T12: the relief layer recovers injected SYNTHETIC conflict features on the realistic
%   simulated LiDAR surface of TRAINING_FIELD_A (natural mound, gully, rocks and bushes), 0.5 m grid, and flags no
%   crater, trench or pit on the untouched surface. Prompt targets: crater depth within 10 %, centre within one cell;
%   trench classified as linear. The defaults were chosen with defaultFeatureSpec; heldOutSpec (positions picked
%   before running, never used for tuning) checks that they are not fitted to those positions.
%   Flies the survey once (~40 s) if no tempdir cache exists. Simulation only: says nothing about real ground.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
for p = {fullfile(root, 'v2', 'matlab'), fullfile(root, 'v2_1', 'matlab'), fullfile(root, 'v2_2', 'matlab')}
    tc.applyFixture(matlab.unittest.fixtures.PathFixture(p{1}));
end
tc.TestData.S = mgv22.cutfill.surveySurface(CellM=0.5);
end

function testDefaultFeaturesAreFound(tc)
checkRecovery(tc, mgv22.relief.defaultFeatureSpec(), "default");
end

function testHeldOutFeaturesAreFound(tc)
checkRecovery(tc, heldOutSpec(), "held-out");
end

function testUntouchedSimulatedSurfaceHasNoPits(tc)
% a DSM also shows bushes and rocks: those appear as berms and are reported, not hidden
S = tc.TestData.S;
F = mgv22.relief.findFeatures(mgv22.relief.reliefAnomaly(S), S);
fprintf("RELIEF_UNTOUCHED features %d: %s\n", height(F), summary(F));
verifyEqual(tc, nnz(F.type ~= "berm"), 0, 'no crater, trench, pit or large depression on the untouched simulated field');
end

function checkRecovery(tc, spec, name)
[S2, truth] = mgv22.relief.injectFeatures(tc.TestData.S, spec);
F = mgv22.relief.findFeatures(mgv22.relief.reliefAnomaly(S2), S2);
fprintf("RELIEF_%s features %d: %s\n", upper(name), height(F), summary(F));
for k = 1:height(truth)
    d = hypot(F.x_east_m - truth.x_east_m(k), F.y_north_m - truth.y_north_m(k));
    [dmin, j] = min(d);
    fprintf("  %s %s -> %.2f m, %s, depth %.2f m (true %.2f)\n", truth.id(k), truth.type(k), dmin, F.type(j), F.depth_m(j), truth.depth_m(k));
    tag = name + " " + truth.id(k) + " " + truth.type(k);
    switch truth.type(k)
        case "crater"
            verifyLessThanOrEqual(tc, dmin, S2.cell_m, tag + ": centre within one cell");
            verifyEqual(tc, F.type(j), "crater", tag);
            verifyEqual(tc, F.depth_m(j), truth.depth_m(k), 'RelTol', 0.10, tag + ": depth within 10 %");
        case "trench"
            verifyLessThanOrEqual(tc, dmin, 1, tag + ": found at its midpoint");
            verifyEqual(tc, F.type(j), "trench", tag + ": classified as linear");
        case "foxhole"
            verifyLessThanOrEqual(tc, dmin, 1, tag + ": found");
            verifyEqual(tc, F.type(j), "pit (foxhole-size)", tag);
    end
end
end

function spec = heldOutSpec()
c = @(x, y, dia, dep, t) struct('type', t, 'center_enu_m', [x y], 'diameter_m', dia, 'depth_m', dep, 'p1', [], 'p2', [], 'width_m', []);
spec = [c(30, -25, 5.9, 0.65, "crater"), c(-35, 15, 5.9, 0.65, "crater"), ...
    c(20, 25, 1.2, 0.7, "foxhole"), c(23, 26.5, 1.2, 0.7, "foxhole"), ...
    c(-25.25, -30.25, 1.2, 0.7, "foxhole"), c(35.75, 5.25, 1.2, 0.7, "foxhole"), ...   % centred on cell centres (review)
    struct('type', "trench", 'center_enu_m', [], 'diameter_m', [], 'depth_m', 0.8, 'p1', [10 32], 'p2', [42 30], 'width_m', 1)];
end

function s = summary(F)
if height(F) == 0, s = "none"; return; end
u = unique(F.type);
s = strjoin(arrayfun(@(t) sprintf("%s %d", t, nnz(F.type == t)), u), ", ");
end
