classdef testV2005NestedMetadataContract < matlab.unittest.TestCase
    %TESTV2005NESTEDMETADATACONTRACT Exact units and noise_parameters; no container in any other sample field. SIMULATED.
    %   Follow-up to issue #69. Headless. Injected values are disposable test inputs.

    properties (TestParameter)
        sensor = {"RGB_NADIR", "THERMAL_LWIR", "LIDAR_TERRAIN", "VIRTUAL_GNSS_INS"}
    end
    properties
        W; Mc; Sys; Eng
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
            tc.W = mgv2.scene.buildWorld(); tc.Mc = mgv2.mission.defaultConfig();
            tc.Sys = mgv2.sensors.SensorSystem(tc.W, tc.Mc, KeepFrames=2000);
            tc.Eng = mgv2.engine.MissionEngine(tc.Mc, mgv2.scene.terrainProvider(tc.W)); tc.Sys.attach(tc.Eng); tc.Eng.start();
            while tc.Eng.TickId < 200, tc.Eng.step(); end
        end
    end

    methods (Access = private)
        function s = sample(tc, id)
            s = tc.Sys.latest(id); tc.assertTrue(s.valid);
        end
        function rejects(tc, x, varargin)
            tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:InvalidSample', varargin{:});
        end
    end

    methods (Test)
        function producedSamplesStayValid(tc, sensor)
            for k = tc.Sys.samplesAt(0), mgv2.sensors.validateSample(k{1}); end
            s = tc.sample(sensor); mgv2.sensors.validateSample(s);
            tc.verifyEqual(s.units, mgv2.sensors.contract().units.(char(sensor)));
        end

        function unknownUnitsFieldIsRefused(tc, sensor)
            for name = ["mine_location", "note", "x"]
                x = tc.sample(sensor); x.units.(name) = "m"; tc.rejects(x, char(name));
            end
            x = tc.sample(sensor); x.units.hidden_truth = "m"; tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
        end

        function unitsMustBeTheContractText(tc, sensor)
            s = tc.sample(sensor); f = string(fieldnames(s.units))';
            for k = f
                x = s; x.units = rmfield(s.units, k); tc.rejects(x, char(k));
                x = s; x.units.(k) = "furlongs"; tc.rejects(x);
                x = s; x.units.(k) = char(s.units.(k)); tc.rejects(x);
                x = s; x.units.(k) = 1; tc.rejects(x);
                x = s; x.units.(k) = struct('a', 1); tc.rejects(x);
            end
            x = s; x.units = "m"; tc.rejects(x);
            x = s; x.units = [s.units s.units]; tc.rejects(x);
        end

        function noiseParametersAreExact(tc)
            s = tc.sample("RGB_NADIR");
            x = s; x.noise_parameters.mine_location = 1; tc.rejects(x);
            x = s; x.noise_parameters = rmfield(s.noise_parameters, 'shot_gain_dn'); tc.rejects(x);
            x = s; x.noise_parameters.target_id = 1; tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
            for bad = {NaN, Inf, -1, [1 2], "1", single(1), 1i, {1}, struct('a', 1)}
                x = s; x.noise_parameters.read_noise_dn = bad{1}; tc.rejects(x);
            end
            x = s; x.noise_parameters = 1; tc.rejects(x);
        end

        function noOtherFieldMayHoldAContainer(tc, sensor)
            s = tc.sample(sensor); nested = mgv2.sensors.contract().nested_fields;
            for f = setdiff(string(fieldnames(s))', nested)
                for bad = {struct('mine_location', 1), {1}, table(1), 'text', categorical("a"), datetime(2026, 1, 1), @sin, 1 + 2i}
                    x = s; x.(f) = bad{1};
                    tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:InvalidSample', char(f + " " + class(bad{1})));
                end
                x = s; x.(f) = containers.Map(); tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak', char(f));
            end
        end

        function issueFieldsAreRefusedByDetectorAndMap(tc)
            d = mgv2.detect.AnomalyDetector(tc.W, tc.Mc); m = mgv2.map.MissionMap(tc.W, tc.Mc); s = tc.sample("RGB_NADIR");
            a = s; a.units.mine_location = "m"; b = s; b.noise_parameters.mine_location = 1; c = s; c.distortion = struct('mine_location', 1);
            for x = {a, b, c}
                tc.verifyError(@() d.ingest(x{1}), 'mgv2:InvalidSample'); tc.verifyError(@() m.addSample(x{1}), 'mgv2:InvalidSample');
            end
        end

        function serializedSamplesKeepTheSameResult(tc, sensor)
            s = tc.sample(sensor); f = tempname + ".mat"; c = onCleanup(@() delete(f));
            save(f, 's'); L = load(f); mgv2.sensors.validateSample(L.s);
            x = s; x.units.mine_location = "m"; save(f, 'x'); L = load(f); tc.rejects(L.x);
        end
    end
end
