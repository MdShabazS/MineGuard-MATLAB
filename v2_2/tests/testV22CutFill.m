function tests = testV22CutFill
%TESTV22CUTFILL V22-T9: simulated LiDAR survey surface and the cut/fill view (hidden figures, injected credits).
%   The maths has its own suite (testV22CutFillMath). No network or map tile is needed.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
for p = {fullfile(root, 'v2', 'matlab'), fullfile(root, 'v2_1', 'matlab'), fullfile(root, 'v2_2', 'matlab')}
    tc.applyFixture(matlab.unittest.fixtures.PathFixture(p{1}));
end
tc.TestData.root = root;
[X, Y] = meshgrid(-49.5:1:49.5, -39.5:1:39.5);
Z = 0.02 * X - 0.01 * Y + 1.5 * exp(-((X - 10).^2 + (Y - 5).^2) / 60) - 1.2 * exp(-((X + 15).^2 + (Y + 8).^2) / 50);
tc.TestData.S = struct('x', -49.5:1:49.5, 'y', -39.5:1:39.5, 'Z', Z, 'cell_m', 1, 'source', "SIMULATED_LIDAR", ...
    'label', "SIMULATED TERRAIN (not BITM ground)");
tc.TestData.poly = [-30 -20; 30 -20; 30 20; -30 20];
end

function v = openView(tc)
v = mgv22.cutfill.CutFillView(tc.TestData.S, Visible="off", MetadataReader=@(~) struct('copyrightText', "Source: Test"));
tc.addTeardown(@() delete(v));
end

function testShortSimulatedSurveyGivesAGriddedSurface(tc)
S = mgv22.cutfill.surveySurface(MaxTicks=300, Cache=false);
verifyGreaterThan(tc, S.n_points, 1000);
verifyEqual(tc, S.source, "SIMULATED_LIDAR");
verifySubstring(tc, S.label, "SIMULATED TERRAIN");
verifyEqual(tc, size(S.Z), [numel(S.y) numel(S.x)]);
verifyTrue(tc, any(~isnan(S.Z(:))) && any(isnan(S.Z(:))), 'covered cells have data, uncovered cells stay NaN');
verifyEqual(tc, S.count(isnan(S.Z)), zeros(nnz(isnan(S.Z)), 1));
end

function testPanelMatchesTheMaths(tc)
v = openView(tc); S = tc.TestData.S;
v.setOutline(tc.TestData.poly);
mask = mgv22.cutfill.clipToPolygon(S, tc.TestData.poly); P = mgv22.cutfill.fitPlane(S, mask); R = mgv22.cutfill.volumes(S, mask, P);
r = v.results();
verifyEqual(tc, r.R.cut_m3, R.cut_m3, 'AbsTol', 1e-9); verifyEqual(tc, r.R.fill_m3, R.fill_m3, 'AbsTol', 1e-9);
verifySubstring(tc, string(v.CutLabel.Text), sprintf('%.1f', R.cut_m3));
verifySubstring(tc, string(v.AreaLabel.Text), sprintf('%.0f', R.area_m2));
verifyEqual(tc, v.SlopeField.Value, P.slope_pct, 'AbsTol', 0.01);
end

function testSlopeHeadingAndBestFit(tc)
v = openView(tc); v.setOutline(tc.TestData.poly);
best = v.results().R.cut_m3;
v.setSlope(0); v.setHeading(45);
flat = v.results();
verifyEqual(tc, flat.P.slope_pct, 0, 'AbsTol', 1e-9);
verifyNotEqual(tc, flat.R.cut_m3, best);
v.bestFit();
verifyEqual(tc, v.results().R.cut_m3, best, 'AbsTol', 1e-9);
verifyError(tc, @() v.setSlope(-1), 'mgv22:InvalidSlope');
end

function testOverlayContoursAndProfileControls(tc)
v = openView(tc); v.setOutline(tc.TestData.poly);
v.setAlpha(0.3); verifyEqual(tc, v.Overlay.MarkerFaceAlpha, 0.3, 'AbsTol', 1e-12);
v.setOverlayVisible(false); verifyFalse(tc, logical(v.Overlay.Visible));
v.setOverlayVisible(true); verifyTrue(tc, logical(v.Overlay.Visible));
v.setContourInterval(0.2); n02 = numel(v.ExistingContours);
v.setContourInterval(1); verifyLessThan(tc, numel(v.ExistingContours), n02, 'a wider interval gives fewer contour lines');
v.setContoursVisible(false, true);
verifyTrue(tc, all(arrayfun(@(h) ~logical(h.Visible), v.ExistingContours)));
F = v.profile([-25 0], [25 0]);
verifyEqual(tc, F.dist_m(end), 50, 'AbsTol', 1e-9);
verifyTrue(tc, isgraphics(v.ProfileLine));
end

function testDrawToolAndInvalidOutline(tc)
v = openView(tc);
v.startDraw("area"); v.addVertex([-10 -10]); v.addVertex([10 -10]); v.addVertex([50 50]); v.undoVertex(); v.addVertex([10 10]); v.addVertex([-10 10]);
v.finishDraw();
verifyEqual(tc, v.results().R.area_m2, 400, 'AbsTol', 1e-9);
verifyError(tc, @() v.setOutline([0 0; 10 10; 10 0; 0 10]), 'mgv22:InvalidOutline');
verifySubstring(tc, string(v.StatusText.Text), "rejected");
verifyEqual(tc, v.results().R.area_m2, 400, 'AbsTol', 1e-9, 'a rejected outline keeps the previous one');
end

function testZoomFramesTheField(tc)
v = openView(tc); v.setOutline(tc.TestData.poly);
[la, lo] = geolimits(v.Axes); s = v.Site;
ll = mgv22.geo.enuToWgs84([tc.TestData.poly zeros(4, 1)], s.anchor_lla);
verifyTrue(tc, all(ll(:, 1) >= la(1) & ll(:, 1) <= la(2) & ll(:, 2) >= lo(1) & ll(:, 2) <= lo(2)), 'the whole outline is in view');
verifyLessThan(tc, diff(la), diff(s.view_window.lat), 'zoomed in from the campus window');
end

function testLabelsAreSimulatedAndNothingForbidden(tc)
v = openView(tc); v.setOutline(tc.TestData.poly); v.profile([-25 0], [25 0]);
verifySubstring(tc, string(v.Banner.Text), "SIMULATED TERRAIN");
verifySubstring(tc, strjoin(string(v.LegendText.String), " "), "SIMULATED");
forbidden = lower(v.Site.forbidden_on_imagery);
kids = findall(v.Axes, '-property', 'DisplayName');
for k = 1:numel(kids)
    name = string(kids(k).DisplayName);
    if strlength(name) == 0, continue; end
    verifyTrue(tc, contains(name, "VIRTUAL") || contains(name, "SIMULATED"), name);
    verifyFalse(tc, any(arrayfun(@(w) contains(lower(name), w), forbidden)), name);
end
verifyTrue(tc, startsWith(string(v.Credits.Text), "Basemap: satellite | Powered by Esri"));
end

function testTenOpenCloseCyclesLeaveNothingBehind(tc)
figs0 = numel(findall(groot, 'Type', 'figure'));
for k = 1:10
    v = mgv22.cutfill.CutFillView(tc.TestData.S, Visible="off", MetadataReader=@(~) struct('copyrightText', "Source: Test"));
    v.setOutline(tc.TestData.poly); v.close();
    verifyFalse(tc, v.isOpen()); delete(v);
end
verifyEqual(tc, numel(findall(groot, 'Type', 'figure')), figs0);
end

function testComputeAndRedrawTime(tc)
v = openView(tc); v.setOutline(tc.TestData.poly);
t0 = tic; for k = 1:5, v.setSlope(1 + k / 10); end; dt = toc(t0) / 5;
fprintf("CUTFILL_RECOMPUTE_MS %.1f\n", 1000 * dt);
verifyLessThan(tc, dt, 1, 'a slope change recomputes and redraws in under a second');
end

function testNoImageryFilesInV22(tc)
for ext = ["png", "jpg", "jpeg", "tif", "tiff", "mbtiles"]
    verifyEmpty(tc, dir(fullfile(tc.TestData.root, 'v2_2', '**', "*." + ext)));
end
end
