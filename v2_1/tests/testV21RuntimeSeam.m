classdef testV21RuntimeSeam < matlab.unittest.TestCase
    %TESTV21RUNTIMESEAM V21-006: the V2 session seam for a chosen scene and PRIVATE surface features. SIMULATED.
    %   From the repository root:  runtests('v2_1/tests/testV21RuntimeSeam.m')
    %   Needs only V2 code: it exercises the seam that the V2.1 runtime uses, with hand-made private features.

    properties (Constant)
        Ticks = 120
    end
    properties (SetAccess = private)
        Root
    end

    methods (TestClassSetup)
        function paths(tc)
            here = fileparts(mfilename('fullpath')); repo = fileparts(fileparts(here));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repo, 'v2', 'matlab')));
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); tc.Root = string(f.Folder);
        end
    end

    methods (Static)
        function F = features()
            % two flat patches under the take-off pad, inside the first camera footprints
            F = struct('center_enu_m', {[-53 -48], [-57 -52]}, 'radius_m', 1.0, 'edge_m', 0.1, 'albedo_rgb', [0.6 0.5 0.36], ...
                'albedo_mix', 0.8, 'delta_T_K', 3, 'emissivity', NaN);
        end
        function sc = scene(), sc = mgv2.scene.defaultSceneConfig('seed', 4242, 'scene_id', "V21-SEAM-TEST"); end
        function bump(m, app)
            m('n') = m('n') + 1; m('tick') = double(app.Session.Engine.TickId); %#ok<NASGU> containers.Map is a handle
        end
        function s = fly(s, n)
            s.start(); for k = 1:n, s.step(); end
        end
    end

    methods (Test)
        function defaultSessionIsUnchangedV2(tc)
            a = tc.fly(mgv2.ui.MissionSession(), tc.Ticks); b = tc.fly(mgv2.ui.MissionSession(SceneConfig=mgv2.scene.defaultSceneConfig()), tc.Ticks);
            tc.verifyEqual(a.Sensors.Log.checksum, b.Sensors.Log.checksum);
            a.abortRun(); pkg = mgv2.run.verifyPackage(a.exportRun(tc.Root));
            tc.verifyEqual(string(pkg.manifest.schema_version), "mg-v2-runpkg/1.0");
            tc.verifyFalse(isfield(pkg.config, 'scene_config')); tc.verifyFalse(isfield(pkg.manifest, 'private_forward_model'));
            tc.verifyTrue(mgv2.run.reproduce(pkg).match);
        end

        function sceneConfigChangesTheActualWorld(tc)
            a = mgv2.ui.MissionSession(); b = mgv2.ui.MissionSession(SceneConfig=tc.scene());
            tc.verifyNotEqual(mgv2.run.digest(a.World), mgv2.run.digest(b.World));
            tc.verifyEqual(b.SceneConfig.seed, 4242);
        end

        function privateFeaturesReachOnlyRgbAndThermal(tc)
            s = tc.fly(mgv2.ui.MissionSession(SceneConfig=tc.scene(), SurfaceFeatures=tc.features()), tc.Ticks);
            r = tc.fly(mgv2.ui.MissionSession(SceneConfig=tc.scene()), tc.Ticks);
            L = s.Sensors.Log; R = r.Sensors.Log; same = @(id) isequal(L.checksum(L.sensor_id == id), R.checksum(R.sensor_id == id));
            tc.verifyFalse(same("RGB_NADIR")); tc.verifyFalse(same("THERMAL_LWIR"));
            tc.verifyTrue(same("LIDAR_TERRAIN"), 'flat features are invisible to LiDAR');
            tc.verifyTrue(same("VIRTUAL_GNSS_INS"));
        end

        function featuresAreNeverPublic(tc)
            s = tc.fly(mgv2.ui.MissionSession(SceneConfig=tc.scene(), SurfaceFeatures=tc.features()), tc.Ticks);
            tc.verifyFalse(any(strcmp(properties(s), 'PrivateFeatures')));
            mgv2.sensors.assertPublic(s.view(), "view"); mgv2.sensors.assertPublic(s.evidenceContext(), "context");
            s.abortRun(); f = s.exportRun(tc.Root); pkg = mgv2.run.verifyPackage(f);
            mgv2.sensors.assertPublic(pkg, "package");
            txt = "";
            for p = mgv2.run.listFiles(f)', if endsWith(p, [".json", ".csv"]), txt = txt + string(fileread(fullfile(f, p))); end, end
            tc.verifyFalse(contains(txt, "center_enu_m")); tc.verifyFalse(contains(txt, "albedo_mix"));
            tc.verifyFalse(contains(txt, "-53") || contains(txt, "-57"), 'no feature coordinate in any text file');
        end

        function privateRunExportsAsV11WithCommitment(tc)
            F = tc.features(); s = tc.fly(mgv2.ui.MissionSession(SceneConfig=tc.scene(), SurfaceFeatures=F), tc.Ticks);
            s.abortRun(); pkg = mgv2.run.verifyPackage(s.exportRun(tc.Root));
            tc.verifyEqual(string(pkg.manifest.schema_version), "mg-v2-runpkg/1.1");
            tc.verifyEqual(pkg.config.scene_config.seed, 4242);
            tc.verifyTrue(pkg.manifest.private_forward_model.used);
            tc.verifyEqual(string(pkg.manifest.private_forward_model.features_sha256), mgv2.run.digest(mgv2.sensors.validateSurfaceFeatures(F)));
        end

        function reproductionNeedsTheSamePrivateFeatures(tc)
            F = tc.features(); s = tc.fly(mgv2.ui.MissionSession(SceneConfig=tc.scene(), SurfaceFeatures=F), tc.Ticks);
            s.abortRun(); pkg = mgv2.run.verifyPackage(s.exportRun(tc.Root));
            tc.verifyError(@() mgv2.run.reproduce(pkg), 'mgv2:PrivateScenarioRequired');
            G = F; G(1).delta_T_K = 2;
            tc.verifyError(@() mgv2.run.reproduce(pkg, SurfaceFeatures=G), 'mgv2:PrivateScenarioRequired');
            tc.verifyTrue(mgv2.run.reproduce(pkg, SurfaceFeatures=F).match);
        end

        function replayNeedsTheSameWorldAndNoFeatures(tc)
            s = tc.fly(mgv2.ui.MissionSession(SceneConfig=tc.scene(), SurfaceFeatures=tc.features()), tc.Ticks);
            s.abortRun(); f = s.exportRun(tc.Root);
            r = mgv2.ui.MissionSession(SceneConfig=tc.scene()); r.loadReplay(f); r.start(); while r.step(), end
            tc.verifyTrue(r.replayCheck().match);
            tc.verifyError(@() mgv2.ui.MissionSession().loadReplay(f), 'mgv2:PackageInvalid');
        end

        function featuresSurviveResetAndScenarioChange(tc)
            s = mgv2.ui.MissionSession(SceneConfig=tc.scene(), SurfaceFeatures=tc.features());
            s.configure("Overcast", 2002); tc.fly(s, tc.Ticks); a = s.Sensors.Log.checksum;
            s.abortRun(); s.reset(); tc.fly(s, tc.Ticks);
            tc.verifyEqual(s.Sensors.Log.checksum, a, 'the same private scenario after a reset');
            r = mgv2.ui.MissionSession(SceneConfig=tc.scene()); r.configure("Overcast", 2002); tc.fly(r, tc.Ticks);
            tc.verifyNotEqual(r.Sensors.Log.checksum, a);
        end

        function onRunEndedFiresOncePerLiveRun(tc)
            app = mgv2.ui.MissionControlApp('Visible', "off", 'RealTime', 0, 'MaxTicksPerRun', 60, 'ExportRoot', tc.Root); c = onCleanup(@() delete(app));
            m = containers.Map({'n', 'tick'}, {0, NaN}); app.OnRunEnded = @(a) testV21RuntimeSeam.bump(m, a);
            app.command("start"); tc.verifyEqual(m('n'), 0, 'a paused run has not ended');
            app.command("abort"); tc.verifyEqual(m('n'), 1); tc.verifyEqual(m('tick'), 60);
            app.command("abort"); tc.verifyEqual(m('n'), 1, 'only once per run');
            app.command("reset"); app.command("start"); app.command("abort"); tc.verifyEqual(m('n'), 2, 'again for the next run');
            f = app.exportRun(); app.replay(f); app.command("start"); tc.verifyEqual(m('n'), 2, 'never for a replay');
        end
    end
end
