classdef testV2006xDiagnostics < matlab.unittest.TestCase
    %TESTV2006XDIAGNOSTICS Experimental package only. Proves the research code stays separate from the frozen detector.
    methods (TestClassSetup)
        function paths(tc)
            r = fileparts(fileparts(mfilename('fullpath'))); tc.applyFixture(matlab.unittest.fixtures.PathFixture(r));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(r)), 'matlab')));
        end
    end
    methods (Test)
        function frozenFingerprintIsUnchanged(tc)
            tc.verifyEqual(mgv2.detect.defaultDetectorConfig().parameter_hash, "fnv1a64:d6d364f988f04bb4");
        end
        function frozenFormMatchesFrozenDetectorArea(tc)
            cfg = mgv2.detect.defaultDetectorConfig(); cfg.size.max_diameter_m = 20; cfg = mgv2.detect.validateDetectorConfig(cfg);
            w = mgv2.scene.buildWorld(); I = uint8(120 * ones(240, 320, 3)) + uint8(randi(RandStream('mrg32k3a', 'Seed', 1), [0 4], [240 320 3]));
            [U, V] = meshgrid(1:320, 1:240); d = hypot(U - 200, V - 120) <= 8; for c = 1:3, x = I(:,:,c); x(d) = 40; I(:,:,c) = x; end
            sys = mgv2.sensors.SensorSystem(w, mgv2.mission.defaultConfig()); e = mgv2.engine.MissionEngine(mgv2.mission.defaultConfig(), mgv2.scene.terrainProvider(w));
            sys.attach(e); e.start(); while e.TickId < 200, e.step(); end
            s = sys.latest("RGB_NADIR"); s.image_rgb_uint8 = I; s.valid_pixel_mask(:) = true; A = mgv2.detect.frameCandidates(s, w, cfg);
            B = mgv2x.detect.rgbResidualCandidates(double(I) / 255, true(240, 320), "FROZEN_FORM");
            tc.verifyEqual(max(B.area_px), max(A.area_px), 'the baseline form must reproduce the frozen measurement');
        end
        function variantsDoNotInventObjectsOnFlatNoise(tc)
            I = 120 / 255 * ones(240, 320, 3) + randi(RandStream('mrg32k3a', 'Seed', 3), [0 4], [240 320 3]) / 255;
            for v = ["FROZEN_FORM", "POLARITY_SPLIT", "CLIPPED"]
                tc.verifyEmpty(mgv2x.detect.rgbResidualCandidates(I, true(240, 320), v).u_px, char(v));
            end
        end
        function clippedRecoversDiscSizeOnOneFixture(tc)
            I = 120 / 255 * ones(240, 320, 3) + randi(RandStream('mrg32k3a', 'Seed', 1), [0 4], [240 320 3]) / 255;
            [U, V] = meshgrid(1:320, 1:240); d = hypot(U - 200, V - 120) <= 8; J = I; J(repmat(d, 1, 1, 3)) = 40 / 255;
            A = nnz(d); C = mgv2x.detect.rgbResidualCandidates(J, true(240, 320), "CLIPPED"); tc.verifyEqual(max(C.area_px), A, 'RelTol', 0.15);
        end
        function nothingInTheApplicationCallsTheCandidate(tc)
            r = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))); F = dir(fullfile(r, 'v2', 'matlab', '**', '*.m'));
            for f = reshape(F, 1, []), tc.verifyFalse(contains(fileread(fullfile(f.folder, f.name)), 'mgv2x'), f.name); end
        end
    end
end
