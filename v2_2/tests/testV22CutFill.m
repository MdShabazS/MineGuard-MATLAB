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
    verifyTrue(tc, contains(name, "VIRTUAL") || contains(name, "SIMULATED") || contains(name, "SIMULATION"), name);
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

function testColoursCutRedFillBlueCentredOnZero(tc)
v = openView(tc); v.setOutline(tc.TestData.poly);
cl = v.Axes.CLim; verifyEqual(tc, cl(1), -cl(2), 'AbsTol', 1e-12);
cmap = v.Axes.Colormap;
verifyGreaterThan(tc, cmap(end, 1), cmap(end, 3), 'positive depth (cut) is red');
verifyGreaterThan(tc, cmap(1, 3), cmap(1, 1), 'negative depth (fill) is blue');
D = v.results().R.D; verifyEqual(tc, sort(v.Overlay.CData(:)), sort(D(~isnan(D))), 'AbsTol', 1e-12);
end

function testCellsWithoutSurveyDataAreExcludedAndReported(tc)
S = tc.TestData.S; S.Z(30:35, 40:45) = NaN;
v = mgv22.cutfill.CutFillView(S, Visible="off", MetadataReader=@(~) struct('copyrightText', "Source: Test"));
tc.addTeardown(@() delete(v));
v.setOutline(tc.TestData.poly);
r = v.results();
verifyEqual(tc, r.nan_cells_inside, 36);
verifyEqual(tc, r.R.cells, 60 * 40 - 36);
verifySubstring(tc, string(v.StatusText.Text), "36 cells without survey data excluded");
end

function testLegendAndCellsFollowZoom(tc)
% needs a visible window: a hidden figure has no real pixel size to scale the cells from
v = mgv22.cutfill.CutFillView(tc.TestData.S, Visible="on", MetadataReader=@(~) struct('copyrightText', "Source: Test"));
tc.addTeardown(@() delete(v));
figure(v.Figure); drawnow; pause(0.5);      % bring it to the front so it is laid out on screen
v.setOutline(tc.TestData.poly); drawnow;
s0 = v.Overlay.SizeData;
verifyGreaterThan(tc, s0, 1, 'a visible window sizes cells from its pixels');
[la, lo] = geolimits(v.Axes);
geolimits(v.Axes, la(1) + [0 0.5] * diff(la), lo(1) + [0 0.5] * diff(lo)); drawnow;
verifyGreaterThan(tc, v.Overlay.SizeData, s0, 'zooming in enlarges the cells');
verifySubstring(tc, strjoin(string(v.LegendText.String), " "), "SIMULATED TERRAIN", 'the legend is the axes title and stays');
end

function testSurveyAreaIsShownAndOutsideOutlineExplained(tc)
v = openView(tc); S = tc.TestData.S;
verifyTrue(tc, isgraphics(v.SurveyAreaLine));
verifySubstring(tc, string(v.SurveyAreaLine.DisplayName), "SIMULATED survey area");
enu = mgv22.geo.wgs84ToEnu([v.SurveyAreaLine.LatitudeData(:) v.SurveyAreaLine.LongitudeData(:) zeros(5, 1)], v.Site.anchor_lla);
verifyEqual(tc, [min(enu(:, 1)) max(enu(:, 1)) min(enu(:, 2)) max(enu(:, 2))], [S.x(1) - 0.5, S.x(end) + 0.5, S.y(1) - 0.5, S.y(end) + 0.5], 'AbsTol', 0.01);
[la, lo] = geolimits(v.Axes);           % a hidden window has no real aspect ratio, so check framing, not size
lat = v.SurveyAreaLine.LatitudeData; lon = v.SurveyAreaLine.LongitudeData;
verifyTrue(tc, all(lat >= la(1) & lat <= la(2) & lon >= lo(1) & lon <= lo(2)), 'the whole survey area is in view');
verifyLessThan(tc, abs(mean(la) - mean([min(lat) max(lat)])), 0.25 * diff(la), 'the view is centred on the survey area');
verifyLessThan(tc, abs(mean(lo) - mean([min(lon) max(lon)])), 0.25 * diff(lo), 'the view is centred on the survey area');
verifyError(tc, @() v.setOutline([120 -10; 160 -10; 160 20; 120 20]), 'mgv22:TooFewCells');
verifySubstring(tc, string(v.StatusText.Text), "Draw inside the dashed SIMULATED survey area");
end

function testMapPansAndZoomsExceptWhileDrawing(tc)
v = openView(tc);
verifyEmpty(tc, v.Axes.ButtonDownFcn, 'no click handler outside draw mode, so drag-to-pan and scroll zoom work');
v.startDraw("area");
verifyNotEmpty(tc, v.Axes.ButtonDownFcn, 'clicks add points while drawing');
v.cancelDraw();
verifyEmpty(tc, v.Axes.ButtonDownFcn);
v.startDraw("area"); v.addVertex([-10 -10]); v.addVertex([10 -10]); v.addVertex([10 10]); v.finishDraw();
verifyEmpty(tc, v.Axes.ButtonDownFcn, 'finishing a drawing gives panning back');
end


function testReliefAndSoilLayers(tc)
% V22-T12: both layers draw, carry INDIRECT EVIDENCE / SIMULATION names, use no forbidden word, and switch back
[S2, ~] = mgv22.relief.injectFeatures(tc.TestData.S, struct('type', "crater", 'center_enu_m', [25 -20], ...
    'diameter_m', 5.9, 'depth_m', 0.65, 'p1', NaN(1, 2), 'p2', NaN(1, 2), 'width_m', NaN));
v = mgv22.cutfill.CutFillView(S2, Visible="off", MetadataReader=@(~) struct('copyrightText', "Source: Test"));
tc.addTeardown(@() delete(v));
verifyEqual(tc, v.Layer, "Cut/fill");
v.setLayer("Relief vs local trend");
verifyTrue(tc, isgraphics(v.ReliefLayer));
verifyEqual(tc, v.ReliefFeatures.type(hypot(v.ReliefFeatures.x_east_m - 25, v.ReliefFeatures.y_north_m + 20) <= 1), "crater");
verifyEqual(tc, string(v.FeatureMarks.MarkerFaceColor), "none", 'feature marks are hollow');
verifySubstring(tc, string(v.FeatureSummaryLabel.Text), "INDIRECT EVIDENCE");
v.setLayer("Soil movement");
verifyTrue(tc, isgraphics(v.SoilLayer));
verifySubstring(tc, string(v.SoilSummaryLabel.Text), "SIMULATION");
forbidden = lower(v.Site.forbidden_on_imagery);
h = findall(v.Figure, '-property', 'DisplayName'); names = string(get(h, 'DisplayName'));
t = findall(v.Figure, '-property', 'Text'); txt = string(cellfun(@(x) strjoin(string(x), " "), get(t, 'Text'), 'UniformOutput', false));
for s = [names(strlength(names) > 0); txt]'
    verifyFalse(tc, any(arrayfun(@(w) ~isempty(regexp(lower(s), "\<" + w + "\>", 'once')), forbidden)), s);
end
for n = names(strlength(names) > 0)'
    verifyTrue(tc, contains(n, "VIRTUAL") || contains(n, "SIMULATED") || contains(n, "SIMULATION"), n);
end
v.setLayer("Cut/fill");
verifyEqual(tc, v.Layer, "Cut/fill");
verifyError(tc, @() v.setLayer("Hazard"), 'mgv22:InvalidLayer');
end
