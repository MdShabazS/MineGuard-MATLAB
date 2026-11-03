classdef testV2005QualityContract < matlab.unittest.TestCase
    %TESTV2005QUALITYCONTRACT Issue #69: exact sample.quality schema at the public sensor boundary. SIMULATED.
    %   Headless. Injected values are disposable test inputs and never reach a study, dataset or evidence record.
    %   From the repository root: addpath('v2/matlab'); runtests('v2/matlab/tests/testV2005QualityContract.m')

    properties (TestParameter)
        sensor = {"RGB_NADIR", "THERMAL_LWIR", "LIDAR_TERRAIN", "VIRTUAL_GNSS_INS"}
    end
    properties
        W; Mc; Run; Drop
    end

    methods (TestClassSetup)
        function setup(tc)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(here))); tc.applyFixture(matlab.unittest.fixtures.PathFixture(here));
            tc.W = mgv2.scene.buildWorld(); tc.Mc = mgv2.mission.defaultConfig();
            tc.Run = testV2005QualityContract.fly(tc.W, tc.Mc, mgv2.sensors.defaultSensorConfig(), 300);
            c = mgv2.sensors.defaultSensorConfig();
            for id = ["RGB_NADIR", "THERMAL_LWIR", "LIDAR_TERRAIN", "VIRTUAL_GNSS_INS"], c.(id).dropout_model.intervals_s = [5 8]; end
            tc.Drop = testV2005QualityContract.fly(tc.W, tc.Mc, c, 200);
        end
    end

    methods (Static)
        function S = fly(W, Mc, cfg, ticks)
            sys = mgv2.sensors.SensorSystem(W, Mc, SensorConfig=cfg, KeepFrames=5000);
            eng = mgv2.engine.MissionEngine(Mc, mgv2.scene.terrainProvider(W)); S = struct('sys', sys, 'eng', eng);
            sys.attach(eng); eng.start();
            while eng.TickId < ticks && ~eng.isTerminal(), eng.step(); end
        end
    end

    methods (Access = private)
        function s = valid(tc, id)
            s = tc.Run.sys.latest(id); tc.assertTrue(s.valid);
        end
        function rejects(tc, x, varargin)
            tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:InvalidSample', varargin{:});
        end
    end

    methods (Test)
        function everyProducedSampleKeepsItsExactFields(tc, sensor)
            c = mgv2.sensors.contract().quality_fields.(char(sensor)); s = tc.valid(sensor);
            tc.verifyEmpty(setxor(string(fieldnames(s.quality)), [c.always c.stats]));
            for R = {tc.Run, tc.Drop}      % all kept frames were validated by SensorSystem; prove it directly too
                n = 0;
                for h = R{1}.sys.samplesAt(0), n = n + 1; mgv2.sensors.validateSample(h{1}); end
                tc.verifyGreaterThan(n, 0);
            end
            mgv2.sensors.validateSample(s);
        end

        function issue69FieldIsRefusedEverywhere(tc)
            x = tc.valid("RGB_NADIR"); x.quality.mine_location = [1 2];
            tc.rejects(x, 'the name is not on the forbidden list, so only the schema can stop it');
            d = mgv2.detect.AnomalyDetector(tc.W, tc.Mc); tc.verifyError(@() d.ingest(x), 'mgv2:InvalidSample');
            m = mgv2.map.MissionMap(tc.W, tc.Mc); tc.verifyError(@() m.addSample(x), 'mgv2:InvalidSample');
        end

        function unknownFieldIsRefusedWhateverItsName(tc, sensor)
            for name = ["note", "x", "calibration", "mine_location", "valid_pixel_fractions", "Stats_Available"]
                x = tc.valid(sensor); x.quality.(name) = 1; tc.rejects(x, char(name));
            end
        end

        function forbiddenNamesAreStillTruthLeaks(tc, sensor)
            for name = ["TargetTruth", "hidden_truth", "burial_depth_m", "label"]
                x = tc.valid(sensor); x.quality.(name) = 1;
                tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak', char(name));
            end
            x = tc.valid(sensor); x.quality.nested = struct('deep', struct('truth', 1)); tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
            x = tc.valid(sensor); x.quality.c = {struct('target_id', 3)}; tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
        end

        function nestedContainersAndObjectsAreRefused(tc, sensor)
            x = tc.valid(sensor); x.quality.nested = struct('a', 1); tc.rejects(x);
            x = tc.valid(sensor); x.quality.c = {1}; tc.rejects(x);
            x = tc.valid(sensor); x.quality.h = containers.Map(); tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
            x = tc.valid(sensor); x.quality.stats_available = {true}; tc.rejects(x);
            f = mgv2.sensors.contract().quality_fields.(char(sensor)).always(1);
            x = tc.valid(sensor); x.quality.(f) = struct('hidden', 1); tc.rejects(x, 'a listed field cannot carry a struct');
            x = tc.valid(sensor); x.quality.(f) = {0.5}; tc.rejects(x);
            x = tc.valid(sensor); x.quality.(f) = containers.Map(); tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
        end

        function qualityMustBeAScalarStruct(tc, sensor)
            s = tc.valid(sensor);
            x = s; x.quality = 1; tc.rejects(x);
            x = s; x.quality = [s.quality s.quality]; tc.rejects(x);
            x = s; x.quality = struct(); tc.rejects(x);
            x = s; x.quality = rmfield(s.quality, 'stats_available'); tc.rejects(x);
            x = s; x.quality.stats_available = 1; tc.rejects(x);
            x = s; x.quality.stats_available = [true true]; tc.rejects(x);
        end

        function everyRequiredFieldIsRequired(tc, sensor)
            s = tc.valid(sensor);
            for f = string(fieldnames(s.quality))'
                x = s; x.quality = rmfield(s.quality, f); tc.rejects(x, char(f));
            end
        end

        function cameraValuesAreChecked(tc)
            r = tc.valid("RGB_NADIR");
            for bad = {NaN, Inf, -0.1, 1.1, single(0.5), [0.5 0.5], "0.5", 0.5i}
                x = r; x.quality.object_pixel_fraction = bad{1}; tc.rejects(x);
                x = r; x.quality.saturated_fraction = bad{1}; tc.rejects(x);
            end
            x = r; x.quality.valid_pixel_fraction = r.quality.valid_pixel_fraction - 0.5; tc.rejects(x, 'must agree with the mask');
            for bad = {NaN, Inf, -1, 256, "1"}, x = r; x.quality.mean_dn = bad{1}; tc.rejects(x); end
            x = r; x.quality.stats_available = false; x.quality = rmfield(x.quality, ["saturated_fraction" "mean_dn"]); tc.rejects(x, 'a valid camera sample has stats');
            t = tc.valid("THERMAL_LWIR");
            x = t; x.quality.min_K = t.quality.max_K + 1; tc.rejects(x);
            x = t; x.quality.mean_K = NaN; tc.rejects(x);
            x = t; x.quality.min_K = -1; tc.rejects(x);
            x = t; x.quality.max_K = []; tc.rejects(x, 'empty only with no valid pixel');
        end

        function lidarValuesMustAgreeWithTheScan(tc)
            s = tc.valid("LIDAR_TERRAIN");
            for f = ["dropout_rays", "out_of_range_rays", "no_intersection_rays"]
                x = s; x.quality.(f) = s.quality.(f) + 1; tc.rejects(x, char(f));
                x = s; x.quality.(f) = uint32(s.quality.(f)); tc.rejects(x, char(f));
            end
            x = s; x.quality.valid_ray_fraction = 0; tc.rejects(x);
            x = s; x.quality.agl_from_returns_available = ~s.quality.agl_from_returns_available; tc.rejects(x);
            x = s; x.quality.agl_from_returns_available = 1; tc.rejects(x);
        end

        function navigationValuesAreChecked(tc)
            s = tc.valid("VIRTUAL_GNSS_INS");
            for bad = {NaN, Inf, -1, [1 2], "1", single(1)}
                x = s; x.quality.horizontal_sigma_m = bad{1}; tc.rejects(x);
                x = s; x.quality.vertical_sigma_m = bad{1}; tc.rejects(x);
            end
            x = s; x.quality.sigma_kind = "CALIBRATED"; tc.rejects(x, 'no calibrated claim');
            x = s; x.quality.sigma_kind = 'MODEL_ASSUMPTION'; tc.rejects(x, 'char is not the contract string');
            x = s; x.quality.stats_available = false; tc.rejects(x);
        end

        function dropoutAndNoPixelSamplesStayLegitimate(tc)
            L = tc.Drop.sys.Log; tc.assertGreaterThan(nnz(L.invalid_reason == "SENSOR_DROPOUT"), 0);
            tc.verifyTrue(all(ismember(["RGB_NADIR" "THERMAL_LWIR" "LIDAR_TERRAIN" "VIRTUAL_GNSS_INS"], L.sensor_id(L.invalid_reason == "SENSOR_DROPOUT"))));
            sc = mgv2.sensors.buildSensorScene(tc.W); cfg = mgv2.sensors.defaultSensorConfig(); up = testV2005Sensors.fixture([0 0 25], 0, 0, pi);      % inverted: only sky
            ms = struct('run_id', tc.Mc.run_id, 'scenario_id', tc.Mc.scenario_id, 'seed', tc.Mc.seed);
            r = mgv2.sensors.sampleCamera(sc, cfg.RGB_NADIR, ms, up, 1); t = mgv2.sensors.sampleCamera(sc, cfg.THERMAL_LWIR, ms, up, 1);
            tc.assertFalse(r.valid); tc.assertEqual(r.quality.valid_pixel_fraction, 0); tc.assertTrue(r.quality.stats_available);
            tc.verifyTrue(isnan(r.quality.mean_dn)); tc.verifyEmpty(t.quality.min_K);
            mgv2.sensors.validateSample(r); mgv2.sensors.validateSample(t);
            x = r; x.quality.mean_dn = 120; tc.rejects(x, 'no value can be claimed from no pixels');
            x = t; x.quality.mean_K = 300; tc.rejects(x, 'no value can be claimed from no pixels');
            x = r; x.quality.note = 1; tc.rejects(x, 'invalid samples get the same schema');
        end

        function serializedPublicSamplesKeepTheSameResult(tc, sensor)
            s = tc.valid(sensor); f = tempname + ".mat"; c = onCleanup(@() delete(f));
            save(f, 's'); L = load(f); tc.verifyEqual(L.s, s); mgv2.sensors.validateSample(L.s);
            x = s; x.quality.mine_location = 1; save(f, 'x'); L = load(f); tc.rejects(L.x);
            j = jsondecode(jsonencode(s.quality));
            tc.verifyFalse(isfield(j, 'mine_location'));
            x = s; x.quality = j; if sensor == "VIRTUAL_GNSS_INS", tc.rejects(x, 'JSON text does not silently stand in for the contract string'); end
        end

        function normalDetectorAndMapIngestion(tc)
            d = mgv2.detect.AnomalyDetector(tc.W, tc.Mc); m = mgv2.map.MissionMap(tc.W, tc.Mc); L = tc.Run.sys.Log; n = 0;
            for t = unique(L.tick_id)'
                for s = tc.Run.sys.samplesAt(t)
                    want = "INVALID_SAMPLE"; if s{1}.valid, want = "ACCEPTED"; end
                    tc.verifyEqual(d.ingest(s{1}), want); m.addSample(s{1}); n = n + 1;
                end
            end
            tc.verifyGreaterThan(n, 50); tc.verifyEqual(n, height(L));
            mgv2.sensors.assertPublic(m.snapshot(), "map");
        end

        function outputsAreDeterministic(tc)
            b = testV2005QualityContract.fly(tc.W, tc.Mc, mgv2.sensors.defaultSensorConfig(), 300);
            tc.verifyEqual(b.sys.Log.checksum, tc.Run.sys.Log.checksum);
            for id = ["RGB_NADIR" "THERMAL_LWIR" "LIDAR_TERRAIN" "VIRTUAL_GNSS_INS"]
                tc.verifyEqual(b.sys.latest(id).quality, tc.Run.sys.latest(id).quality);
            end
        end
    end
end
