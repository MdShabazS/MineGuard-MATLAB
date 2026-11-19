function tests = testV22CutFillMath
%TESTV22CUTFILLMATH V22-T9: pure-math tests for mgv22.cutfill (outline, clip, plane fit, volumes, profile).
%   Synthetic surfaces only, core MATLAB, no graphics. Volumes are simulation arithmetic, not survey results.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))),'matlab')));
end

function S = makeSurface(xEdges, yEdges, cellM, fn)
% Cell-centred grid covering [xEdges] x [yEdges] with elevation fn(X,Y).
x = xEdges(1)+cellM/2 : cellM : xEdges(2)-cellM/2;
y = yEdges(1)+cellM/2 : cellM : yEdges(2)-cellM/2;
[X, Y] = meshgrid(x, y);
S = struct('x', x, 'y', y, 'Z', fn(X, Y), 'cell_m', cellM, 'source', "synthetic", 'label', "test");
end

function m = allCells(S)
m = true(size(S.Z));
end

function testFitPlaneRecoversTiltedPlane(tc)
S = makeSurface([0 30], [0 20], 1, @(X,Y) 2 + 0.03*X - 0.01*Y);
P = mgv22.cutfill.fitPlane(S, allCells(S));
verifyEqual(tc, [P.a P.b P.c], [2 0.03 -0.01], 'AbsTol', 1e-9);
verifyEqual(tc, P.slope_pct, 100*hypot(0.03, 0.01), 'AbsTol', 1e-9);
verifyEqual(tc, P.heading_deg, mod(atan2d(-0.03, 0.01), 360), 'AbsTol', 1e-9);
end

function testPlaneFromSlopeRoundTrip(tc)
P0 = mgv22.cutfill.planeFromSlope(915, 5, 7, 1.5, 225);
S = makeSurface([0 25], [0 25], 1, @(X,Y) P0.a + P0.b*X + P0.c*Y);
P = mgv22.cutfill.fitPlane(S, allCells(S));
verifyEqual(tc, [P.a P.b P.c], [P0.a P0.b P0.c], 'AbsTol', 1e-9);
verifyEqual(tc, P.slope_pct, 1.5, 'AbsTol', 1e-9);
verifyEqual(tc, P.heading_deg, 225, 'AbsTol', 1e-9);
verifyEqual(tc, P0.a + P0.b*5 + P0.c*7, 915, 'AbsTol', 1e-9);
end

function testFlatRectangleCut(tc)
S = makeSurface([-5 25], [-5 15], 1, @(X,Y) ones(size(X)));
[mask, info] = mgv22.cutfill.clipToPolygon(S, [0 0; 20 0; 20 10; 0 10]);
verifyEqual(tc, info.cells_inside, 200);
R = mgv22.cutfill.volumes(S, mask, mgv22.cutfill.planeFromSlope(0, 0, 0, 0, 0));
verifyEqual(tc, R.cut_m3, 200, 'AbsTol', 1e-9);
verifyEqual(tc, R.fill_m3, 0);
verifyEqual(tc, R.ratio, Inf);
verifyEqual(tc, R.area_m2, 200);
verifyEqual(tc, R.cut_per_ha, 200/0.02, 'AbsTol', 1e-6);
verifyEqual(tc, R.max_cut_m, 1, 'AbsTol', 1e-12);
verifyTrue(tc, all(isnan(R.D(~mask))));
end

function testConeVolume(tc)
h = 2; r = 10;
S = makeSurface([-12 12], [-12 12], 0.25, @(X,Y) max(0, h*(1 - hypot(X,Y)/r)));
mask = mgv22.cutfill.clipToPolygon(S, [-12 -12; 12 -12; 12 12; -12 12]);
R = mgv22.cutfill.volumes(S, mask, mgv22.cutfill.planeFromSlope(0, 0, 0, 0, 0));
verifyEqual(tc, R.cut_m3, pi*r^2*h/3, 'RelTol', 0.02);
verifyEqual(tc, R.fill_m3, 0);
end

function testBumpAndDipBalance(tc)
g = @(X,Y,xc) max(0, 3 - hypot(X - xc, Y - 10));
S = makeSurface([0 40], [0 20], 1, @(X,Y) g(X,Y,10) - g(X,Y,30));
R = mgv22.cutfill.volumes(S, allCells(S), mgv22.cutfill.planeFromSlope(0, 0, 0, 0, 0));
verifyGreaterThan(tc, R.cut_m3, 0);
verifyEqual(tc, R.cut_m3, R.fill_m3, 'RelTol', 1e-9);
verifyEqual(tc, R.net_m3, 0, 'AbsTol', 1e-9);
verifyEqual(tc, R.ratio, 1, 'RelTol', 1e-9);
end

function testClipConcaveLShapeAndNaN(tc)
S = makeSurface([0 10], [0 10], 1, @(X,Y) zeros(size(X)));
L = [0 0; 10 0; 10 4; 4 4; 4 10; 0 10];
[mask, info] = mgv22.cutfill.clipToPolygon(S, L);
verifyEqual(tc, nnz(mask), 4*10 + 6*4);
verifyEqual(tc, info.nan_cells_inside, 0);
S.Z(S.y == 8.5, S.x == 1.5) = NaN;   % inside the L
S.Z(S.y == 8.5, S.x == 8.5) = NaN;   % outside the L
[mask, info] = mgv22.cutfill.clipToPolygon(S, L);
verifyEqual(tc, nnz(mask), 63);
verifyEqual(tc, info.cells_inside, 63);
verifyEqual(tc, info.nan_cells_inside, 1);
verifyFalse(tc, mask(S.y == 8.5, S.x == 1.5));
end

function testValidateOutlineErrors(tc)
verifyError(tc, @() mgv22.cutfill.validateOutline([0 0; 1 1]), 'mgv22:InvalidOutline');
verifyError(tc, @() mgv22.cutfill.validateOutline([0 0; 10 10; 10 0; 0 10]), 'mgv22:InvalidOutline');
verifyError(tc, @() mgv22.cutfill.validateOutline([0 0; 5 0; 10 0]), 'mgv22:InvalidOutline');
verifyError(tc, @() mgv22.cutfill.validateOutline([0 0; 10 0; NaN 10]), 'mgv22:InvalidOutline');
end

function testValidateOutlineOrientationAndClosing(tc)
cw = [0 0; 0 10; 10 10; 10 0];
p = mgv22.cutfill.validateOutline(cw);
q = circshift(p, -1, 1);
verifyGreaterThan(tc, sum(p(:,1).*q(:,2) - q(:,1).*p(:,2)), 0);
verifyEqual(tc, sortrows(p), sortrows(cw));
closed = [0 0; 10 0; 10 10; 0 10; 0 0];
p = mgv22.cutfill.validateOutline(closed);
verifyEqual(tc, p, closed(1:4, :));
end

function testProfileOnTiltedPlane(tc)
P = mgv22.cutfill.planeFromSlope(100, 0, 0, 2, 60);
S = makeSurface([0 30], [0 30], 1, @(X,Y) P.a + P.b*X + P.c*Y);
p1 = [2 3]; p2 = [25 20];
F = mgv22.cutfill.profileLine(S, P, p1, p2, 50);
verifyEqual(tc, numel(F.dist_m), 50);
verifyEqual(tc, F.existing_m, F.design_m, 'AbsTol', 1e-9);
verifyEqual(tc, F.dist_m(1), 0);
verifyEqual(tc, F.dist_m(end), hypot(23, 17), 'AbsTol', 1e-9);
verifyEqual(tc, F.xy([1 end], :), [p1; p2], 'AbsTol', 1e-12);
verifyEqual(tc, numel(mgv22.cutfill.profileLine(S, P, p1, p2).dist_m), 100);
verifyError(tc, @() mgv22.cutfill.profileLine(S, P, p1, p1), 'mgv22:InvalidProfile');
end

function testFitPlaneTooFewCells(tc)
S = makeSurface([0 10], [0 10], 1, @(X,Y) X + Y);
m = false(size(S.Z)); m(1, 1:2) = true;
verifyError(tc, @() mgv22.cutfill.fitPlane(S, m), 'mgv22:TooFewCells');
m(1, 3) = true;   % three collinear cells are rank-deficient
verifyError(tc, @() mgv22.cutfill.fitPlane(S, m), 'mgv22:TooFewCells');
end
