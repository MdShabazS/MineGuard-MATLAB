function tests = testV22FieldRun
%TESTV22FIELDRUN V22-T11: headless simulated survey of a drawn field (mgv22.field.runSurvey).
%   Builds the plan directly (no surveyPlan) for a 40 m x 30 m field and runs short, tick-limited simulations.
%   Outputs are SUSPECTED anomalies from simulation only; nothing here measures real detection capability.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2', 'matlab')));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_1', 'matlab')));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_2', 'matlab')));
P = makePlan();
calls = containers.Map('KeyType', 'char', 'ValueType', 'double'); calls('n') = 0;
tc.TestData.P = P;
tc.TestData.calls = calls;
tc.TestData.S = mgv22.field.runSurvey(P, TargetCount=6, Seed=1, MaxTicks=600, Progress=@(t, e) bump(calls));
end

function testShortRunPublicEventsAndTruthInField(tc)
S = tc.TestData.S; P = tc.TestData.P;
tc.verifyTrue(isstruct(S.events));
tc.verifyEqual(sort(string(fieldnames(S.events)))', sort(["event_id" "x_est_m" "y_est_m" "model_score" "lat" "lon"]));
mgv21.scenario.assertPublic(S.events, "events");
mgv21.scenario.assertPublic(S.coverage, "coverage");
tc.verifyEqual(S.ticks, 600);
tc.verifyTrue(S.stopped_early);
tl = S.evaluation.truth_ll;
tc.verifyEqual(height(tl), 6);
tc.verifyTrue(all(inpolygon(tl.x_east_m, tl.y_north_m, P.poly_enu(:, 1), P.poly_enu(:, 2))));
tc.verifyTrue(all(isfinite([tl.lat; tl.lon])));
end

function testCoverageCounted(tc)
C = tc.TestData.S.coverage;
tc.verifyEqual(size(C.count), [numel(C.y) numel(C.x)]);
tc.verifyGreaterThan(max(C.count(:)), 0);
tc.verifyGreaterThanOrEqual(C.frac_covered, 0);
tc.verifyLessThanOrEqual(C.frac_covered, 1);
tc.verifyEqual(size(C.low_mask), size(C.count));
tc.verifyFalse(any(C.low_mask(~C.in_field)));
end

function testZeroTargets(tc)
S = mgv22.field.runSurvey(tc.TestData.P, TargetCount=0, MaxTicks=50);
tc.verifyEqual(height(S.evaluation.truth_ll), 0);
tc.verifyTrue(all(isnan(S.evaluation.detection_ci)));
tc.verifyEqual(S.evaluation.n_visible, 0);
tc.verifyTrue(isstruct(S.evaluation.fa));
tc.verifyEqual(S.evaluation.fa.fp, S.evaluation.R.FP);
tc.verifyTrue(isfinite(S.evaluation.fa.hi_per_ha));
end

function testSeedDeterminesPlacement(tc)
a = mgv22.field.runSurvey(tc.TestData.P, TargetCount=6, Seed=1, MaxTicks=1);
b = mgv22.field.runSurvey(tc.TestData.P, TargetCount=6, Seed=2, MaxTicks=1);
tc.verifyEqual(a.evaluation.truth_ll(:, ["lat" "lon" "surface_signature"]), ...
    tc.TestData.S.evaluation.truth_ll(:, ["lat" "lon" "surface_signature"]));
tc.verifyNotEqual([a.evaluation.truth_ll.lat a.evaluation.truth_ll.lon], ...
    [b.evaluation.truth_ll.lat b.evaluation.truth_ll.lon]);
end

function testProgressCalled(tc)
tc.verifyGreaterThanOrEqual(tc.TestData.calls('n'), 6);
end

function testLabelWording(tc)
S = tc.TestData.S; w = mgv22.wording();
tc.verifyEqual(S.label, w.suspected);
tc.verifyEqual(S.no_detection_text, w.no_detection);
end

function P = makePlan()
s = mgv21.scenario.defaultSurvey("TRAINING_FIELD_A");
s.polygon_enu_m = [-20 -15; 20 -15; 20 15; -20 15];
s.boundary_kind = "POLYGON";
s.alt_agl_m = 10; s.line_spacing_m = 6; s.speed_mps = 4;
[pub, ~] = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", s);
P = struct('pub', pub, 'poly_enu', s.polygon_enu_m, 'area_m2', 1200, 'field_anchor_lla', [15.1682 76.8504 0]);
end

function bump(m)
m('n') = m('n') + 1; %#ok<NASGU> containers.Map is a handle: the update is kept
end
