classdef testV21RunController < matlab.uitest.TestCase
    %TESTV21RUNCONTROLLER V21-006: a LOCKED V2.1 scenario flies in the real V2 dashboard and is evaluated after the run.
    %   From the repository root:  runtests('v2_1/tests/testV21RunController.m')     SIMULATED; needs V21-002..004.
    %   Runs are unpaced (RealTime 0). Detection results are whatever the frozen V2-006 detector produces: no
    %   assertion expects a target to be found.

    properties (SetAccess = private)
        Root
    end
    properties
        Ctl
    end

    methods (TestClassSetup)
        function paths(tc)
            here = fileparts(mfilename('fullpath')); repo = fileparts(fileparts(here));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repo, 'v2', 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repo, 'v2_1', 'matlab')));
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); tc.Root = string(f.Folder);
        end
    end
    methods (TestMethodTeardown)
        function closeAll(tc)
            if ~isempty(tc.Ctl) && isvalid(tc.Ctl), delete(tc.Ctl); end
            tc.Ctl = [];
        end
    end

    methods (Access = private)
        function [pub, world, priv] = scenario(~, preset, mode, varargin)
            s = mgv21.scenario.defaultSurvey(preset);
            [pub, ~] = mgv21.scenario.buildPublicMission(preset, s);
            world = mgv21.scenario.buildWorld(pub);
            spec = mgv21.placement.defaultPlacement(mode);
            switch mode
                case "MANUAL"
                    P = pub.mission.survey_polygon_enu_m; c = mean(P, 1); d = 0.25 * (max(P) - min(P));
                    cand = [c; c + [d(1) 0]; c - [d(1) 0]; c + [0 d(2)]; c - [0 d(2)]];
                    sigs = ["VISIBLE_DISTURBANCE", "VISIBLE_DISTURBANCE", "NONE", "VISIBLE_DISTURBANCE", "VISIBLE_DISTURBANCE"];
                    for k = 1:size(cand, 1)
                        [ok, ~] = mgv21.placement.checkLocation(spec, pub, world, cand(k, :));
                        if ok, spec = mgv21.placement.addTarget(spec, cand(k, :), sigs(k), 0.05); end
                    end
                case "RANDOM"
                    spec.count = varargin{1}; spec.seed = varargin{2};
            end
            priv = mgv21.placement.lockScenario(spec, pub, world);
        end
        function ctl = fly(tc, pub, world, priv, maxTicks)
            ctl = mgv21.ui.RunController(pub, world, priv, 'RealTime', 0, 'Visible', "off", 'MaxTicksPerRun', maxTicks, 'ExportRoot', tc.Root);
            tc.Ctl = ctl; ctl.App.command("start");
        end
    end

    methods (Test)
        function sessionUsesTheLockedPublicScenario(tc)
            [pub, world, priv] = tc.scenario("ROCKY_UPLAND", "MANUAL");
            ctl = tc.fly(pub, world, priv, 10); s = ctl.App.Session;
            tc.verifyEqual(mgv2.run.digest(s.World), mgv2.run.digest(world));
            tc.verifyEqual(s.MissionConfig.survey_polygon_enu_m, pub.mission.survey_polygon_enu_m);
            tc.verifyEqual(s.SceneConfig.scene_id, pub.scene_config.scene_id);
            tc.verifyClass(s.Source, 'mgv2.bridge.V2006AnomalySource');
        end

        function noTruthReachesThePublicSide(tc)
            [pub, world, priv] = tc.scenario("TRAINING_FIELD_A", "MANUAL");
            ctl = tc.fly(pub, world, priv, 200); s = ctl.App.Session;
            mgv21.scenario.assertPublic(s.view(), "view"); mgv21.scenario.assertPublic(s.evidenceContext(), "context");
            mgv21.scenario.assertPublic(ctl.App.Perf, "Perf"); mgv21.scenario.assertPublic(ctl.App.LastReplay, "LastReplay");   % the app's data structs (Panels holds UI objects)
            tc.verifyFalse(any(ismember(["Priv", "Truth"], string(properties(ctl)))));
            ctl.App.command("abort"); f = ctl.App.exportRun(); pkg = mgv2.run.verifyPackage(f);
            mgv21.scenario.assertPublic(rmfield(pkg, 'samples'), "package");
            T = priv.truth.targets; txt = "";
            for q = mgv2.run.listFiles(f)', if endsWith(q, [".json", ".csv"]), txt = txt + string(fileread(fullfile(f, q))); end, end
            for k = 1:height(T)
                tc.verifyFalse(contains(txt, sprintf('%.4f', T.x_east_m(k))) && contains(txt, sprintf('%.4f', T.y_north_m(k))), 'no target coordinate in the export');
            end
            tc.verifyEqual(string(pkg.manifest.schema_version), "mg-v2-runpkg/1.1");
            tc.verifyEqual(pkg.manifest.private_forward_model.used, numel(priv.surface_features) > 0);
        end

        function abortedRunIsEvaluatedOnceAndShown(tc)
            [pub, world, priv] = tc.scenario("TRAINING_FIELD_A", "MANUAL");
            ctl = tc.fly(pub, world, priv, 300);
            tc.verifyEmpty(ctl.LastEvaluation, 'not evaluated while the run is only paused');
            ctl.App.command("abort"); R = ctl.LastEvaluation;
            tc.verifyEqual(string(R.run_state), "ABORTED"); tc.verifyEqual(R.n_targets, height(priv.truth.targets));
            tc.verifyEqual(R.TP + R.FN, R.n_targets); tc.verifyEqual(R.TP + R.FP, R.n_events);
            tc.verifyEqual(numel(ctl.Views), 1); v = ctl.Views{1};
            tc.verifySubstring(string(v.Figure.Name), "EVALUATION VIEW"); tc.verifyEqual(v.Counts.n_targets, R.n_targets);
            ctl.App.command("abort"); tc.verifyEqual(numel(ctl.Views), 1, 'only once per run');
        end

        function targetFreeRunHasUndefinedRecall(tc)
            [pub, world, priv] = tc.scenario("DRY_FLATS", "NONE");
            ctl = tc.fly(pub, world, priv, 300); ctl.App.command("abort"); R = ctl.LastEvaluation;
            tc.verifyEqual(R.n_targets, 0); tc.verifyEqual(R.TP, 0); tc.verifyEqual(R.FN, 0);
            tc.verifyTrue(isnan(R.recall), 'recall is undefined without targets, never 0 or 100 %');
            tc.verifyEqual(R.FP, R.n_events);
        end

        function seededRandomPlacementIsReproducible(tc)
            [~, ~, a] = tc.scenario("ROCKY_UPLAND", "RANDOM", 6, 77); [~, ~, b] = tc.scenario("ROCKY_UPLAND", "RANDOM", 6, 77);
            [~, ~, c] = tc.scenario("ROCKY_UPLAND", "RANDOM", 6, 78);
            tc.verifyEqual(a.truth.targets, b.truth.targets); tc.verifyNotEqual(a.truth.targets, c.truth.targets);
            tc.verifyEqual(height(a.truth.targets), 6);
        end

        function replayIsNeverEvaluated(tc)
            [pub, world, priv] = tc.scenario("TRAINING_FIELD_A", "NONE");
            ctl = tc.fly(pub, world, priv, 100); ctl.App.command("abort"); n = numel(ctl.Views);
            f = ctl.App.exportRun(); ctl.App.replay(f); ctl.App.command("start");
            tc.verifyEqual(ctl.App.Session.Mode, "REPLAY"); tc.verifyEqual(numel(ctl.Views), n);
            tc.verifyTrue(ctl.App.LastReplay.match, ctl.App.LastReplay.detail);
        end

        function refusesAWorldThatPubDoesNotBuild(tc)
            [pub, ~, priv] = tc.scenario("TRAINING_FIELD_A", "NONE");
            other = mgv2.scene.buildWorld(mgv2.scene.defaultSceneConfig('seed', 1));
            tc.verifyError(@() mgv21.ui.RunController(pub, other, priv, 'Visible', "off"), 'mgv21:InvalidScenario');
        end

        function privateEvaluationFileIsSeparateAndOnRequest(tc)
            [pub, world, priv] = tc.scenario("TRAINING_FIELD_A", "MANUAL");
            ctl = tc.fly(pub, world, priv, 150);
            tc.verifyError(@() ctl.savePrivateEvaluation(tc.Root), 'mgv21:EvaluationTooEarly');
            ctl.App.command("abort"); pkgDir = ctl.App.exportRun();
            before = mgv2.run.listFiles(pkgDir);
            tc.verifyError(@() ctl.savePrivateEvaluation(pkgDir), 'mgv21:PrivateFileRefused', 'never inside a package');
            f = ctl.savePrivateEvaluation(fullfile(tc.Root, "private"));
            tc.verifyTrue(isfile(f)); tc.verifySubstring(f, "_PRIVATE_EVALUATION.mat");
            tc.verifyFalse(startsWith(f, pkgDir));
            L = load(f); pe = L.private_evaluation;
            tc.verifyEqual(pe.truth.targets, priv.truth.targets); tc.verifyEqual(pe.evaluation, ctl.LastEvaluation);
            pkg = mgv2.run.verifyPackage(pkgDir);
            tc.verifyEqual(string(pe.features_sha256), string(pkg.manifest.private_forward_model.features_sha256));
            tc.verifyTrue(mgv2.run.reproduce(pkg, SurfaceFeatures=pe.surface_features, CommitmentSalt=pe.commitment_salt).match, ...
                'the private file holds exactly what reproduction needs');
            tc.verifyError(@() mgv2.run.reproduce(pkg, SurfaceFeatures=pe.surface_features), 'mgv2:PrivateScenarioRequired');
            tc.verifyEqual(mgv2.run.listFiles(pkgDir), before, 'the operator package is unchanged');
            tc.verifyError(@() ctl.savePrivateEvaluation(fullfile(tc.Root, "private")), 'mgv21:PrivateFileRefused', 'no overwrite');
        end

        function originalV2EntryPointIsUnchanged(tc)
            app = mgv2MissionControl('RealTime', 0, 'Visible', "off", 'MaxTicksPerRun', 40, 'ExportRoot', tc.Root); c = onCleanup(@() delete(app));
            tc.verifyEqual(app.Session.SceneConfig, mgv2.scene.defaultSceneConfig());
            tc.verifyEqual(app.Session.MissionConfig.run_id, "V2RUN-NOMINAL-0001"); tc.verifyEmpty(app.OnRunEnded);
            app.command("start"); app.command("abort"); f = app.exportRun();
            tc.verifyEqual(string(mgv2.run.verifyPackage(f).manifest.schema_version), "mg-v2-runpkg/1.0");
        end
    end
end
