function tests = testV22EvaluationStats
%TESTV22EVALUATIONSTATS V22-T10: exact binomial and Poisson intervals and the detection/false-alarm curve.
%   Base MATLAB only (no Statistics Toolbox). Reference values: closed forms for k=0/k=n and published
%   Clopper-Pearson bounds for 5 of 10. Counts are synthetic; nothing here measures real detection.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'matlab')));
end

function testZeroSuccessesUsesClosedForm(tc)
[lo, hi] = mgv22.evaluation.clopperPearson(0, 12);
tc.verifyEqual(lo, 0);
tc.verifyEqual(hi, 1 - 0.025^(1/12), 'AbsTol', 1e-12);
tc.verifyEqual(hi, 0.2646, 'AbsTol', 1e-4);
[~, hi9] = mgv22.evaluation.clopperPearson(0, 9);
tc.verifyEqual(hi9, 0.3363, 'AbsTol', 1e-4);
end

function testAllSuccessesUsesClosedForm(tc)
[lo, hi] = mgv22.evaluation.clopperPearson(12, 12);
tc.verifyEqual(lo, 0.025^(1/12), 'AbsTol', 1e-12);
tc.verifyEqual(hi, 1);
end

function testFiveOfTenMatchesReference(tc)
[lo, hi] = mgv22.evaluation.clopperPearson(5, 10);
tc.verifyEqual([lo hi], [0.187086 0.812914], 'AbsTol', 1e-5);
end

function testIntervalCoversPointEstimate(tc)
n = 20; k = 0:n;
[lo, hi] = mgv22.evaluation.clopperPearson(k, n);
tc.verifyTrue(all(lo <= k / n & k / n <= hi));
tc.verifyTrue(all(diff(lo) > 0));
tc.verifyTrue(all(diff(hi) > 0));
tc.verifyTrue(all(lo >= 0 & hi <= 1));
end

function testInvalidCountsError(tc)
tc.verifyError(@() mgv22.evaluation.clopperPearson(13, 12), 'mgv22:InvalidCounts');
tc.verifyError(@() mgv22.evaluation.clopperPearson(-1, 12), 'mgv22:InvalidCounts');
tc.verifyError(@() mgv22.evaluation.clopperPearson(2.5, 12), 'mgv22:InvalidCounts');
tc.verifyError(@() mgv22.evaluation.clopperPearson(2, 12, 1), 'mgv22:InvalidCounts');
tc.verifyError(@() mgv22.evaluation.clopperPearson(0, 0), 'mgv22:InvalidCounts');
tc.verifyError(@() mgv22.evaluation.falseAlarmRate(-1, 100), 'mgv22:InvalidCounts');
tc.verifyError(@() mgv22.evaluation.falseAlarmRate(1.5, 100), 'mgv22:InvalidCounts');
tc.verifyError(@() mgv22.evaluation.falseAlarmRate(1, 0), 'mgv22:InvalidCounts');
end

function testZeroFalseAlarmsStillHasUpperBound(tc)
R = mgv22.evaluation.falseAlarmRate(0, 10000);
tc.verifyEqual(R.per_ha, 0);
tc.verifyEqual(R.lo_per_ha, 0);
tc.verifyEqual(R.hi_per_ha, -log(0.025), 'AbsTol', 1e-4);
tc.verifyEqual(R.hi_per_ha, 3.6889, 'AbsTol', 1e-4);
tc.verifyEqual(R.area_ha, 1);
tc.verifyEqual(R.conf, 0.95);
end

function testManyFalseAlarmsBracketRate(tc)
R = mgv22.evaluation.falseAlarmRate(112, 4800);
tc.verifyEqual(R.per_ha, 112 / 0.48, 'AbsTol', 1e-9);
tc.verifyTrue(R.lo_per_ha < R.per_ha && R.per_ha < R.hi_per_ha);
tc.verifyEqual(R.fp, 112);
end

function testCurveIsMonotone(tc)
rng(7, 'twister');
scores = rand(60, 1); isTP = rand(60, 1) < 0.3;
C = mgv22.evaluation.detectionCurve(scores, isTP, 25, 2500);
tc.verifyEqual(C.threshold(1), Inf);
tc.verifyTrue(all(diff(C.threshold) < 0));
tc.verifyTrue(all(diff(C.detection) >= 0));
tc.verifyTrue(all(diff(C.fa_per_ha) >= 0));
tc.verifyEqual(C.n_tp(end), sum(isTP));
tc.verifyEqual(C.n_fp(end), sum(~isTP));
tc.verifyEqual(C.detection(end), sum(isTP) / 25, 'AbsTol', 1e-12);
end

function testAllFalseAlarmsGiveZeroDetection(tc)
scores = [0.9 0.4 0.7 0.1]; isTP = false(1, 4);
C = mgv22.evaluation.detectionCurve(scores, isTP, 5, 2000);
tc.verifyEqual(C.detection, zeros(5, 1));
tc.verifyTrue(all(diff(C.fa_per_ha) > 0));
tc.verifyEqual(C.fa_per_ha(end), 4 / 0.2, 'AbsTol', 1e-9);
end

function testNoTargetsGivesNaNDetection(tc)
C = mgv22.evaluation.detectionCurve([0.5 0.2], [false false], 0, 1e4);
tc.verifyTrue(all(isnan(C.detection)));
tc.verifyEqual(C.n_fp, [0; 1; 2]);
end

function testEmptyEventsGiveSinglePoint(tc)
C = mgv22.evaluation.detectionCurve([], false(0, 1), 3, 1e4);
tc.verifyEqual(C.threshold, Inf);
tc.verifyEqual(C.detection, 0);
tc.verifyEqual(C.fa_per_ha, 0);
tc.verifyEqual([C.n_tp C.n_fp], [0 0]);
end
