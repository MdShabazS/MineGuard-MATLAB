classdef testV21Evaluation < matlab.unittest.TestCase
    %TESTV21EVALUATION V21-004: post-run INTERACTIVE SYNTHETIC DEMO evaluation (wraps mgv2.eval.evaluateEvents).
    %   Headless, no simulation. From the repository root: runtests('v2_1/tests/testV21Evaluation.m')
    %   Written on the Mac without execution (V21-008: Windows).

    methods (TestClassSetup)
        function setup(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2', 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_1', 'matlab')));
        end
    end

    methods (Static)
        function t = truth(xy, sig)
            n = size(xy, 1);
            if nargin < 2, sig = repmat("VISIBLE_DISTURBANCE", n, 1); end
            T = table('Size', [n 5], 'VariableTypes', ["string","double","double","string","double"], ...
                'VariableNames', ["target_id","x_east_m","y_north_m","surface_signature","burial_depth_m"]);
            if n > 0
                T.target_id = compose("V21-T%02d", (1:n)'); T.x_east_m = xy(:,1); T.y_north_m = xy(:,2);
                T.surface_signature = string(sig(:)); T.burial_depth_m = 0.1 * ones(n, 1);
            end
            t = struct('schema_version', "mg-v21-truth/1.0", 'mode', "MANUAL", 'seed', 1, 'generator', "mrg32k3a", ...
                'preset_id', "TRAINING_FIELD_A", 'polygon_enu_m', [-40 -30; 40 -30; 40 30; -40 30], 'targets', T);
        end
    end

    methods (Test)
        function perfectRunWithKnownOffsets(tc)
            T = testV21Evaluation.truth([10 5; -10 -5; 20 -15]);
            R = mgv21.evaluation.evaluateRun([10.3 5; -10 -5.4; 20 -15], T, "COMPLETE");
            tc.verifyEqual([R.TP R.FP R.FN], [3 0 0]);
            tc.verifyEqual([R.precision R.recall], [1 1]);
            tc.verifyTrue(isnan(R.TN));
            tc.verifyEqual(sort(R.match_error_m), [0 0.3 0.4], 'AbsTol', 1e-12);
            tc.verifyEqual(R.mean_match_error_m, 0.7 / 3, 'AbsTol', 1e-12);
            tc.verifyEqual(R.max_match_error_m, 0.4, 'AbsTol', 1e-12);
        end

        function falsePositivesAndMisses(tc)
            T = testV21Evaluation.truth([10 5; -10 -5; 20 -15]);
            R = mgv21.evaluation.evaluateRun([10 5.5; 0 0; 30 20], T, "ABORTED");
            tc.verifyEqual([R.TP R.FP R.FN], [1 2 2]);
            tc.verifyEqual(R.precision, 1/3, 'AbsTol', 1e-12); tc.verifyEqual(R.recall, 1/3, 'AbsTol', 1e-12);
            tc.verifyEqual(R.run_state, "ABORTED");
        end

        function matchRadiusIsAHardLimit(tc)
            T = testV21Evaluation.truth([0 0]);
            tc.verifyEqual(mgv21.evaluation.evaluateRun([1.2 0], T, "COMPLETE").TP, 0);
            R = mgv21.evaluation.evaluateRun([1.2 0], T, "COMPLETE", RMatch=1.5);
            tc.verifyEqual([R.TP R.r_match_m], [1 1.5]);
        end

        function duplicateEventsOnOneTargetAreFalsePositives(tc)
            R = mgv21.evaluation.evaluateRun([0 0.1; 0.2 0; 0 -0.3], testV21Evaluation.truth([0 0]), "COMPLETE");
            tc.verifyEqual([R.TP R.FP R.FN], [1 2 0]);
        end

        function undefinedRatiosAreNaNNotZero(tc)
            R = mgv21.evaluation.evaluateRun(zeros(0, 2), testV21Evaluation.truth([1 1; 5 5]), "COMPLETE");
            tc.verifyTrue(isnan(R.precision)); tc.verifyEqual(R.recall, 0);
            tc.verifyTrue(isnan(R.mean_match_error_m)); tc.verifyTrue(isnan(R.max_match_error_m));
            R = mgv21.evaluation.evaluateRun([1 1], testV21Evaluation.truth(zeros(0, 2)), "COMPLETE");
            tc.verifyTrue(isnan(R.recall)); tc.verifyEqual([R.precision R.FP R.n_targets], [0 1 0]);
            R = mgv21.evaluation.evaluateRun([], testV21Evaluation.truth(zeros(0, 2)), "FAILED");
            tc.verifyTrue(isnan(R.precision) && isnan(R.recall));
            txt = mgv21.evaluation.formatReport(R);
            tc.verifyTrue(any(contains(txt, "Precision: undefined")));
        end

        function noSignatureMissesAreReportedSeparately(tc)
            T = testV21Evaluation.truth([0 0; 10 10], ["VISIBLE_DISTURBANCE"; "NONE"]);
            R = mgv21.evaluation.evaluateRun([0 0], T, "COMPLETE");
            tc.verifyEqual([R.FN R.FN_no_signature R.FN_visible], [1 1 0]);
        end

        function structEventsAreAccepted(tc)
            ev = struct('event_id', {"SUS-1", "SUS-2"}, 'x_est_m', {0, 9}, 'y_est_m', {0, 9});
            R = mgv21.evaluation.evaluateRun(ev, testV21Evaluation.truth([0 0]), "COMPLETE");
            tc.verifyEqual([R.TP R.FP R.n_events], [1 1 2]);
            tc.verifyEqual(R.matched_event_index, 1);
        end

        function evaluationBeforeTheRunEndsIsRefused(tc)
            T = testV21Evaluation.truth([0 0]);
            for ph = ["CONFIGURED", "SURVEY", "RETURN_HOME", "LANDING", ""]
                tc.verifyError(@() mgv21.evaluation.evaluateRun([0 0], T, ph), 'mgv21:EvaluationTooEarly', ph);
            end
        end

        function badEventsAreRefused(tc)
            T = testV21Evaluation.truth([0 0]);
            tc.verifyError(@() mgv21.evaluation.evaluateRun([NaN 0], T, "COMPLETE"), 'mgv21:InvalidEvents');
            tc.verifyError(@() mgv21.evaluation.evaluateRun([1 2 3], T, "COMPLETE"), 'mgv21:InvalidEvents');
            tc.verifyError(@() mgv21.evaluation.evaluateRun(struct('x', 1), T, "COMPLETE"), 'mgv21:InvalidEvents');
            bad = T; bad.schema_version = "other";
            tc.verifyError(@() mgv21.evaluation.evaluateRun([0 0], bad, "COMPLETE"), 'mgv21:InvalidEvents');
        end

        function resultCarriesTheDemoNotice(tc)
            R = mgv21.evaluation.evaluateRun([0 0], testV21Evaluation.truth([0 0]), "COMPLETE");
            tc.verifyEqual(R.notice, "INTERACTIVE SYNTHETIC DEMO evaluation - not held-out scientific accuracy");
            tc.verifyEqual(R.schema_version, "mg-v21-eval/1.0");
            tc.verifyFalse(isfield(R, 'label'));
            txt = mgv21.evaluation.formatReport(R);
            tc.verifyEqual(txt(1), R.notice);
            tc.verifyTrue(any(contains(txt, "SUSPECTED")));
        end

        function endToEndWithPlacement(tc)
            pub = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", mgv21.scenario.defaultSurvey());
            W = struct('objects', table("ROCK-001", "rock", 0, 0, 0.5, 'VariableNames', {'object_id','kind','x_east_m','y_north_m','radius_m'}), ...
                'landmarks', struct('id', "LM-1", 'xy', [20 10], 'radius_m', 0.6));
            s = mgv21.placement.defaultPlacement("RANDOM"); s.seed = 11; s.count = 6;
            priv = mgv21.placement.lockScenario(s, pub, W);
            xy = [priv.truth.targets.x_east_m priv.truth.targets.y_north_m];
            R = mgv21.evaluation.evaluateRun(xy(1:4, :) + 0.2, priv.truth, "COMPLETE");
            tc.verifyEqual([R.TP R.FP R.FN R.n_targets], [4 0 2 6]);
            tc.verifyEqual([R.placement_mode R.placement_seed], ["RANDOM" "11"]);
        end
    end
end
