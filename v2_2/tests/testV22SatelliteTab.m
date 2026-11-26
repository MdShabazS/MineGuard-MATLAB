function tests = testV22SatelliteTab
%TESTV22SATELLITETAB V22-T6: optional BITM views in the V2.1 mission-control app (hidden windows, injected credits).
%   Buttons in Mission Setup open the views only on request; an unreachable imagery service gives the ENH-009
%   schematic; the satellite overlay follows reset and a new run; repeated open/close leaves no figure or timer.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
for p = {fullfile(root, 'v2', 'matlab'), fullfile(root, 'v2', 'enhancements'), fullfile(root, 'v2_1', 'matlab'), fullfile(root, 'v2_2', 'matlab')}
    tc.applyFixture(matlab.unittest.fixtures.PathFixture(p{1}));
end
f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); tc.TestData.export = string(f.Folder);
tc.TestData.okReader = @(~) struct('copyrightText', "Source: Test");
end

function L = launch(tc, varargin)
opts = {'MetadataReader', tc.TestData.okReader, varargin{:}};
L = mgv21.ui.Launcher('Visible', "off", 'RealTime', 0, 'MaxTicksPerRun', 120, 'ExportRoot', tc.TestData.export, ...
    'SiteViewsOptions', opts);
tc.addTeardown(@() delete(L));
end

function n = leftovers()
n = numel(findall(groot, 'Type', 'figure')) + numel(timerfindall('Tag', 'mgv22_site_views_follow'));
end

function push(b)
cb = b.ButtonPushedFcn; cb(b, []);
end

function testButtonsInSetupAndNothingOpensAtStart(tc)
n0 = leftovers();
L = launch(tc);
sv = L.SiteViews;
verifyClass(tc, sv, 'mgv22.ui.SiteViews');
verifyEqual(tc, sv.openCount(), 0, 'no V2.2 view opens at app start');
verifyEmpty(tc, timerfindall('Tag', 'mgv22_site_views_follow'));
verifyEqual(tc, ancestor(sv.Buttons.satellite, 'figure'), L.Setup.Figure, 'the buttons live in the V2.1 Mission Setup window');
verifyEqual(tc, string({sv.Buttons.satellite.Text, sv.Buttons.field.Text, sv.Buttons.cutfill.Text, sv.Buttons.relief.Text}), ...
    ["Satellite view (BITM)", "Field survey (BITM)", "Cut/fill map (BITM)", "Relief map (BITM)"]);
push(sv.Buttons.satellite);
verifyTrue(tc, sv.Satellite.isOpen());
verifyNotEmpty(tc, sv.Overlay, 'the VIRTUAL route of the Mission Setup survey is drawn before a run');
verifyNumElements(tc, timerfindall('Tag', 'mgv22_site_views_follow'), 1);
push(sv.Buttons.field);
verifyTrue(tc, sv.FieldSurvey.isOpen());
verifyEqual(tc, string(sv.FieldSurvey.Watermark.String), "SIMULATION — NOT A HAZARD MAP");
sv.closeAll();
verifyEqual(tc, sv.openCount(), 0);
delete(L);
verifyEqual(tc, leftovers(), n0, 'closing the app leaves no figures or timers');
end

function testOfflineFallbackOnBasemapFailure(tc)
L = launch(tc, 'MetadataReader', @(~) error('test:offline', 'no network'));
sv = L.SiteViews;
push(sv.Buttons.satellite);
verifyEmpty(tc, sv.Satellite, 'no possibly blank satellite map is shown');
verifyTrue(tc, isgraphics(sv.Fallback));
txt = strjoin(string(get(findall(sv.Fallback, '-property', 'String'), 'String')), " ");
verifySubstring(tc, txt, "ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT");
verifySubstring(tc, txt, "satellite imagery unavailable");
push(sv.Buttons.cutfill);
verifyEmpty(tc, sv.CutFill, 'other views fall back the same way');
verifyNumElements(tc, findall(groot, 'Tag', 'mgv22_offline_fallback'), 1, 'one schematic, reused');
L2 = launch(tc, 'Offline', true);
push(L2.SiteViews.Buttons.field);
verifyTrue(tc, isgraphics(L2.SiteViews.Fallback)); verifyEmpty(tc, L2.SiteViews.FieldSurvey);
end

function testOverlayFollowsResetAndNewRun(tc)
L = launch(tc);
verifyTrue(tc, L.Setup.lockAndStart());
app = L.Controller.App;
sv = L.SiteViews; sv.openSatellite();
app.command("start"); sv.poll();
t1 = sv.Overlay.LastTick;
verifyGreaterThan(tc, t1, 0, 'the drone follows the running session');
verifyGreaterThan(tc, size(sv.Overlay.TrailLLA, 1), 0);
mgv21.scenario.assertPublic(struct('trail', sv.Overlay.TrailLLA), "overlay");
g = app.Session.evidenceContext().generation; r0 = sv.Restarts;
app.command("abort"); app.command("reset"); sv.poll();
verifyEqual(tc, app.Session.evidenceContext().generation, g + 1);
verifyEqual(tc, sv.Restarts, r0 + 1, 'the overlay noticed the new engine');
verifyTrue(tc, sv.FollowedEngine == app.Session.Engine);
verifyLessThanOrEqual(tc, size(sv.Overlay.TrailLLA, 1), 1, 'reset starts a new trail');
verifyLessThan(tc, sv.Overlay.LastTick, t1);
app.command("start"); sv.poll();
verifyGreaterThan(tc, sv.Overlay.LastTick, 0, 'the new run is followed');
end

function testCutFillAndReliefButtons(tc)
L = launch(tc);
sv = L.SiteViews;
push(sv.Buttons.cutfill);
verifyTrue(tc, sv.CutFill.isOpen()); verifyEqual(tc, sv.CutFill.Layer, "Cut/fill");
push(sv.Buttons.relief);
verifyTrue(tc, sv.Relief.isOpen()); verifyEqual(tc, sv.Relief.Layer, "Relief vs local trend");
verifyEqual(tc, sv.Relief.Surface.cell_m, 0.5);
verifyGreaterThan(tc, height(sv.Relief.ReliefFeatures), 0);
sv.closeAll(); verifyEqual(tc, sv.openCount(), 0);
end

function testTenOpenCloseCyclesLeaveNothing(tc)
n0 = leftovers();
for k = 1:10
    L = mgv21.ui.Launcher('Visible', "off", 'RealTime', 0, 'ExportRoot', tc.TestData.export, ...
        'SiteViewsOptions', {'MetadataReader', tc.TestData.okReader});
    L.SiteViews.openSatellite(); L.SiteViews.openFieldSurvey();
    if mod(k, 2), L.SiteViews.closeAll(); end
    delete(L);
end
verifyEqual(tc, leftovers(), n0);
end
