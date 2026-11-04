classdef testV21EvaluationView < matlab.unittest.TestCase
    %TESTV21EVALUATIONVIEW V21-006: the post-run view colours each target from the evaluator's own match, never its own.
    %   From the repository root:  runtests('v2_1/tests/testV21EvaluationView.m')     SIMULATED; no flight is run.
    %   Events are placed by hand near chosen targets so the evaluator's result is known in advance.

    properties
        View
    end

    methods (TestClassSetup)
        function paths(tc)
            here = fileparts(mfilename('fullpath')); repo = fileparts(fileparts(here));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repo, 'v2', 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repo, 'v2_1', 'matlab')));
        end
    end
    methods (TestMethodTeardown)
        function closeView(tc)
            if ~isempty(tc.View) && isvalid(tc.View), delete(tc.View); end
        end
    end

    methods (Static)
        function [pub, world, truth] = scenario()
            id = "TRAINING_FIELD_A"; [pub, ~] = mgv21.scenario.buildPublicMission(id, mgv21.scenario.defaultSurvey(id));
            world = mgv21.scenario.buildWorld(pub); spec = mgv21.placement.defaultPlacement("MANUAL");
            P = pub.mission.survey_polygon_enu_m; c = mean(P, 1); d = 0.25 * (max(P) - min(P));
            xy = [c; c + [d(1) 0]; c - [d(1) 0]; c + [0 d(2)]]; sig = ["VISIBLE_DISTURBANCE", "VISIBLE_DISTURBANCE", "NONE", "NONE"];
            for k = 1:4, spec = mgv21.placement.addTarget(spec, xy(k, :), sig(k), 0.05); end
            priv = mgv21.placement.lockScenario(spec, pub, world); truth = priv.truth;
        end
        function ev = events(xy)
            ev = struct('x_est_m', num2cell(xy(:, 1)), 'y_est_m', num2cell(xy(:, 2)));
        end
        function poses = poses(pub)
            h = pub.mission.home_enu_m; poses = table([h 0; h + 1 0], 'VariableNames', {'position_enu_m'});
        end
    end

    methods (Test)
        function coloursComeFromTheEvaluatorMatch(tc)
            [pub, world, truth] = tc.scenario(); T = [truth.targets.x_east_m truth.targets.y_north_m];
            % event 1 on target 2 (0.3 m), event 2 on target 3 (NONE signature, 0.2 m), event 3 a false alarm far away
            ev = tc.events([T(2, :) + [0.3 0]; T(3, :) + [0 0.2]; T(1, :) + [6 6]]);
            R = mgv21.evaluation.evaluateRun(ev, truth, "COMPLETE");
            tc.View = mgv21.ui.EvaluationView(world, pub, tc.poses(pub), ev, truth, R, 'Visible', "off");
            S = tc.View.TargetSets; E = tc.View.EventSets;
            tc.verifyTrue(tc.View.Counts.matched_targets_known);
            tc.verifyEqual(sort(S.matched), sort(R.matched_target_index), 'matched targets are exactly the evaluator''s');
            tc.verifyEqual(sort(E.matched), sort(R.matched_event_index));
            tc.verifyEqual(sort([S.matched S.missed S.missed_no_signature]), 1:height(truth.targets), 'every target drawn once');
            none = find(truth.targets.surface_signature == "NONE")';
            tc.verifyEmpty(intersect(S.missed, none)); tc.verifyEqual(sort(S.missed_no_signature), sort(setdiff(none, S.matched)));
            tc.verifyEqual(numel(S.matched), R.TP); tc.verifyEqual(numel(E.false_alarm), R.FP);
            tc.verifyEqual(numel(S.missed) + numel(S.missed_no_signature), R.FN);
        end

        function zeroEventsAllMissed(tc)
            [pub, world, truth] = tc.scenario(); R = mgv21.evaluation.evaluateRun(zeros(0, 2), truth, "ABORTED");
            tc.View = mgv21.ui.EvaluationView(world, pub, tc.poses(pub), struct([]), truth, R, 'Visible', "off");
            tc.verifyEmpty(tc.View.TargetSets.matched); tc.verifyEqual(tc.View.Counts.n_events, 0);
            tc.verifySubstring(strjoin(string(tc.View.ReportArea.Value), " "), "undefined", 'precision undefined, not 0');
        end

        function manualReportOmitsTheSeed(tc)
            [pub, world, truth] = tc.scenario(); R = mgv21.evaluation.evaluateRun(zeros(0, 2), truth, "COMPLETE");
            tc.View = mgv21.ui.EvaluationView(world, pub, tc.poses(pub), struct([]), truth, R, 'Visible', "off");
            txt = strjoin(string(tc.View.ReportArea.Value), " ");
            tc.verifySubstring(txt, "MANUAL"); tc.verifyFalse(contains(txt, "seed"), 'no seed shown for MANUAL');
        end

        function viewNeverRematches(tc)
            % a falsified R (no match) must be drawn as given, even though an event sits on a target
            [pub, world, truth] = tc.scenario(); T = [truth.targets.x_east_m truth.targets.y_north_m];
            ev = tc.events(T(1, :)); R = mgv21.evaluation.evaluateRun(ev, truth, "COMPLETE");
            R.matched_target_index = zeros(1, 0); R.matched_event_index = zeros(1, 0);
            tc.View = mgv21.ui.EvaluationView(world, pub, tc.poses(pub), ev, truth, R, 'Visible', "off");
            tc.verifyEmpty(tc.View.TargetSets.matched); tc.verifyEqual(tc.View.EventSets.false_alarm, 1);
        end
    end
end
