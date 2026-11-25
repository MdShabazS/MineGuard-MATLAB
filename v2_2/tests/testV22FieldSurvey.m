function tests = testV22FieldSurvey
%TESTV22FIELDSURVEY V22-T11: the field-survey window end to end (hidden figure, injected credits, one small full flight).
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
for p = {fullfile(root, 'v2', 'matlab'), fullfile(root, 'v2_1', 'matlab'), fullfile(root, 'v2_2', 'matlab')}
    tc.applyFixture(matlab.unittest.fixtures.PathFixture(p{1}));
end
tc.TestData.root = root;
s = mgv22.siteConfig(); tc.TestData.site = s;
tc.TestData.toLL = @(enu) subsref(mgv22.geo.enuToWgs84([enu zeros(size(enu, 1), 1)], s.anchor_lla), struct('type', '()', 'subs', {{':', 1:2}}));
end

function v = openView(tc)
v = mgv22.field.FieldSurveyView(Visible="off", MetadataReader=@(~) struct('copyrightText', "Source: Test"));
tc.addTeardown(@() delete(v));
end

function drawField(v, ll)
v.startDraw(); for k = 1:size(ll, 1), v.addVertex(ll(k, :)); end; v.finishDraw();
end

function testPlanFromADrawnFieldAndPanZoomOutsideDrawing(tc)
v = openView(tc);
verifyEmpty(tc, v.Axes.ButtonDownFcn, 'no click handler outside draw mode, so the map pans and zooms');
drawField(v, tc.TestData.toLL([70 -95; 105 -95; 105 -70; 70 -70]));
verifyEmpty(tc, v.Axes.ButtonDownFcn);
r = v.results();
verifyEqual(tc, r.plan.area_m2, 875, 'RelTol', 1e-6);
verifyGreaterThanOrEqual(tc, r.plan.alt_m, 6);
verifyTrue(tc, isgraphics(v.FieldLine) && isgraphics(v.RouteLine));
verifySubstring(tc, string(v.StatusText.Text), "Planned");
end

function testNonConvexAndTooLargeFieldsAreExplained(tc)
v = openView(tc); toLL = tc.TestData.toLL;
L = toLL([0 -120; 40 -120; 40 -100; 20 -100; 20 -80; 0 -80]);
try drawField(v, L); catch, end
verifySubstring(tc, lower(string(v.StatusText.Text)), "convex");
v.AllowHullCheck.Value = true; v.plan(L);
verifyTrue(tc, v.results().plan.hull_used);
try v.plan(toLL([-60 -200; 100 -200; 100 -120; -60 -120])); catch, end
verifySubstring(tc, lower(string(v.StatusText.Text)), "limit");
end

function testFullSmallSurveyShowsHollowSuspectedMarksAndHidesTruth(tc)
v = openView(tc);
drawField(v, tc.TestData.toLL([70 -95; 92 -95; 92 -75; 70 -75]));     % 22 x 20 m, a short full flight
v.TargetsField.Value = 4; v.SeedField.Value = 2;
S = v.run();
verifyEqual(tc, S.phase, "COMPLETE");
verifyFalse(tc, isfield(S, 'evaluation'), 'run() returns only the public part');
r = v.results();
verifyFalse(tc, isfield(r.survey, 'evaluation'));
verifyEqual(tc, string(v.Watermark.String), "SIMULATION — NOT A HAZARD MAP");
if ~isempty(S.events)
    verifyEqual(tc, string(v.SuspectedMarks.MarkerFaceColor), "none", 'suspected marks are hollow');
    verifySubstring(tc, string(v.SuspectedMarks.DisplayName), "SUSPECTED anomaly (SIMULATION)");
end
verifyFalse(tc, shown(v.SyntheticTargets), 'synthetic targets hidden until evaluation');
v.setEvaluation(true);
verifyTrue(tc, shown(v.SyntheticTargets));
verifyEqual(tc, sum(arrayfun(@(h) numel(h.LatitudeData), v.SyntheticTargets)), 4);
verifySubstring(tc, string(v.SyntheticTargets(1).DisplayName), "evaluation only");
v.setEvaluation(false);
verifyFalse(tc, shown(v.SyntheticTargets), 'hidden or removed again');
end

function testLabelsWordingAndNoExport(tc)
v = openView(tc); drawField(v, tc.TestData.toLL([70 -95; 105 -95; 105 -70; 70 -70]));
kids = findall(v.Axes, '-property', 'DisplayName');
for k = 1:numel(kids)
    n = string(kids(k).DisplayName); if strlength(n) == 0, continue; end
    verifyTrue(tc, contains(n, "VIRTUAL") || contains(n, "SIMULATION") || contains(n, "evaluation only"), n);
end
m = lower(string(methods(v)));
verifyFalse(tc, any(contains(m, ["export", "save", "write"])), 'no way to export coordinates as findings');
w = mgv22.wording();
vals = get(findall(v.Figure, '-property', 'Text'), 'Text'); vals = cellfun(@(x) strjoin(string(x), " "), vals, 'UniformOutput', false);
txt = lower(strjoin(string(vals), " "));
verifyFalse(tc, any(arrayfun(@(f) ~isempty(regexp(txt, "\<" + f + "\>", 'once')), w.forbidden)));
verifyTrue(tc, contains(txt, lower(w.suspected)), 'the standard suspected wording is shown');
end

function testNoImageryFilesInV22(tc)
for ext = ["png", "jpg", "jpeg", "tif", "tiff", "mbtiles"]
    verifyEmpty(tc, dir(fullfile(tc.TestData.root, 'v2_2', '**', "*." + ext)));
end
end

function tf = shown(h)
% true when any handle is a live graphics object that is visible
tf = false;
for k = 1:numel(h)
    if isgraphics(h(k)) && strcmp(h(k).Visible, 'on'), tf = true; return; end
end
end

