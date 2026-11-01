classdef testV2005Sensors < matlab.unittest.TestCase
    %TESTV2005SENSORS V2-005 synchronised virtual sensors (V2-004 SC-01..17, SC-19, SC-23, SC-27..29). SIMULATED.
    %   From the repository root:  addpath('v2/matlab'); runtests('v2/matlab/tests/testV2005Sensors.m')
    %   Headless (no figures). One full mission with all four sensors runs in TestClassSetup.

    properties
        W; Sc; Cfg; Mc; Eng; Sys; T; Ms
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
            tc.W = mgv2.scene.buildWorld(); tc.Mc = mgv2.mission.defaultConfig(); tc.Cfg = mgv2.sensors.defaultSensorConfig();
            tc.Sc = mgv2.sensors.buildSensorScene(tc.W);
            tc.Ms = struct('run_id', tc.Mc.run_id, 'scenario_id', tc.Mc.scenario_id, 'seed', tc.Mc.seed);
            tc.Sys = mgv2.sensors.SensorSystem(tc.W, tc.Mc, KeepFrames=2000);
            tc.Eng = mgv2.engine.MissionEngine(tc.Mc, mgv2.scene.terrainProvider(tc.W));
            tc.Sys.attach(tc.Eng); tc.Eng.run(); tc.T = tc.Eng.poseLog();
        end
    end

    methods (Static)
        function p = pose(T, k)
            r = T(k, :);
            p = struct('pose_id', r.pose_id, 'tick_id', r.tick_id, 't_s', r.t_s, 'position_enu_m', r.position_enu_m, ...
                'velocity_enu_mps', r.velocity_enu_mps, 'orientation_quat', r.orientation_quat);
        end
        function p = fixture(xyz, yaw, pitch, roll, tick)
            if nargin < 5, tick = 0; end
            p = struct('pose_id', tick, 'tick_id', tick, 't_s', tick * 0.05, 'position_enu_m', xyz, 'velocity_enu_mps', [0 0 0], ...
                'orientation_quat', mgv2.frames.quatFromYawPitchRoll(yaw, pitch, roll));
        end
        function [sys, eng] = shortRun(w, mc, ticks, varargin)
            sys = mgv2.sensors.SensorSystem(w, mc, varargin{:});
            eng = mgv2.engine.MissionEngine(mc, mgv2.scene.terrainProvider(w)); sys.attach(eng); eng.run(ticks);
        end
        function f = flatWorld()
            f = mgv2.scene.buildWorld(mgv2.scene.defaultSceneConfig('relief_m', 0, 'slope', [0 0], 'n_rocks', 0, 'n_bushes', 0));
        end
    end

    methods (Test)
        function v01_envelopeSchema(tc)                                   % SC-01
            c = mgv2.sensors.contract(); S = tc.Sys.samplesAt(20);
            tc.verifyEqual(numel(S), 4);
            for k = 1:numel(S)
                s = S{k}; mgv2.sensors.validateSample(s);
                tc.verifyEqual(string(fieldnames(s))', [c.envelope, c.modality_fields.(char(s.sensor_id))]);
                tc.verifyEqual(s.schema_version, "mg-v2-sensors/1.0"); tc.verifyTrue(s.simulated);
                tc.verifyEqual(s.calibration_kind, "SYNTHETIC_ASSUMED");
                x = s; x.extra_field = 1; tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:InvalidSample');
                x = rmfield(s, 'tick_id'); tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:InvalidSample');
                x = s; x.schema_version = "mg-v2-sensors/0.9"; tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:InvalidSample');
                x = s; x.valid = ~x.valid; tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:InvalidSample');
            end
        end

        function v02_schedulerRates(tc)                                   % SC-02
            L = tc.Sys.Log; nT = tc.Eng.TickId;
            want = struct('RGB_NADIR', 4, 'THERMAL_LWIR', 4, 'LIDAR_TERRAIN', 10, 'VIRTUAL_GNSS_INS', 2);
            for id = string(fieldnames(want))'
                tk = double(L.tick_id(L.sensor_id == id)); N = want.(id);
                tc.verifyEqual(tc.Sys.Period.(id), N);
                tc.verifyEqual(tk', 0:N:nT, id + ": due exactly at multiples of N from tick 0, none missed or duplicated");
            end
            bad = tc.Cfg; bad.LIDAR_TERRAIN.rate_hz = 3;
            tc.verifyError(@() mgv2.sensors.SensorSystem(tc.W, tc.Mc, SensorConfig=bad), 'mgv2:InvalidSensorConfig');
        end

        function v03_poseTimestampInvariant(tc)                           % SC-03, EVAL-12
            L = tc.Sys.Log; T = tc.T;
            tc.verifyEqual(L.pose_id, L.tick_id);
            tc.verifyEqual(L.t_s, double(L.tick_id) * tc.Mc.dt_s, 'AbsTol', 1e-12);
            tc.verifyEqual(L.t_s, T.t_s(double(L.pose_id) + 1), 'AbsTol', 1e-12, 't_s equals the referenced PoseSample time');
            for id = tc.Sys.Order
                q = double(L.sample_seq(L.sensor_id == id)); tc.verifyEqual(q', 0:numel(q) - 1, id + ": sample_seq 0,1,2,... no gaps");
            end
            k20 = L(L.tick_id == 20, :);
            tc.verifyEqual(sort(k20.sensor_id)', sort(tc.Sys.Order), 'all four channels at tick 20');
            tc.verifyTrue(all(k20.pose_id == 20 & k20.t_s == 1.0));
            S = tc.Sys.samplesAt(20); p20 = testV2005Sensors.pose(T, 21);
            for k = 1:4
                s = S{k};
                if isfield(s, 'T_world_sensor')
                    tc.verifyEqual(s.T_world_sensor, mgv2.scene.sensorPose(p20, tc.Cfg.(char(s.sensor_id)).mount), 'AbsTol', 1e-12, ...
                        s.sensor_id + " computed from the tick-20 pose");
                end
            end
        end

        function v04_pauseFreezesEmission(tc)                             % SC-04
            [a, ea] = testV2005Sensors.shortRun(tc.W, tc.Mc, 0);
            ea.start(); for i = 1:100, ea.step(); end
            ea.pause(); n = height(a.Log);
            for i = 1:30, tc.verifyFalse(ea.step()); end
            tc.verifyEqual(height(a.Log), n, 'paused: no new sensor samples');
            ea.resume(); for i = 1:100, ea.step(); end
            [b, eb] = testV2005Sensors.shortRun(tc.W, tc.Mc, 0); eb.start(); for i = 1:200, eb.step(); end
            tc.verifyEqual(a.Log.checksum, b.Log.checksum, 'pause/resume yields the identical sample sequence');
            tc.verifyEqual(a.Log.tick_id, b.Log.tick_id);
        end

        function v05_independentRngStreams(tc)                            % SC-05, EVAL-11
            off = tc.Cfg; off.THERMAL_LWIR.enabled = false; off.LIDAR_TERRAIN.enabled = false;
            a = testV2005Sensors.shortRun(tc.W, tc.Mc, 120);
            b = testV2005Sensors.shortRun(tc.W, tc.Mc, 120, SensorConfig=off);
            tc.verifyFalse(any(b.Log.sensor_id == "THERMAL_LWIR"));
            for id = ["RGB_NADIR","VIRTUAL_GNSS_INS"]
                tc.verifyEqual(b.Log.checksum(b.Log.sensor_id == id), a.Log.checksum(a.Log.sensor_id == id), ...
                    id + " identical with thermal/LiDAR disabled");
            end
            p = testV2005Sensors.pose(tc.T, 701);   % order independence: a sample depends only on its own seq
            s1 = mgv2.sensors.sampleCamera(tc.Sc, tc.Cfg.RGB_NADIR, tc.Ms, p, 7);
            mgv2.sensors.sampleCamera(tc.Sc, tc.Cfg.THERMAL_LWIR, tc.Ms, p, 7);
            s2 = mgv2.sensors.sampleCamera(tc.Sc, tc.Cfg.RGB_NADIR, tc.Ms, p, 7);
            tc.verifyEqual(s1.image_rgb_uint8, s2.image_rgb_uint8);
        end

        function v06_cameraTransformsAndFootprint(tc)                     % SC-06 / SC-16 (sample level)
            p = testV2005Sensors.pose(tc.T, 801);
            for id = ["RGB_NADIR","THERMAL_LWIR"]
                c = tc.Cfg.(id); s = mgv2.sensors.sampleCamera(tc.Sc, c, tc.Ms, p, 1);
                tc.verifyEqual(s.T_world_sensor, mgv2.scene.sensorPose(p, c.mount), 'AbsTol', 1e-12);
                [C, ok] = mgv2.scene.cameraFootprint(tc.W, c.mount, s.T_world_sensor);
                tc.verifyTrue(ok);
                if id == "RGB_NADIR"
                    tc.verifyTrue(all(s.corner_valid)); tc.verifyEqual(s.corner_hits_enu_m, C, 'AbsTol', 1e-6, 'footprint corners = V2-003 geometry');
                end
                tc.verifyEqual(size(s.footprint_enu_m), [4 2]);
            end
        end

        function v07_rgbLandmarkGeometry(tc)                              % SC-07, G1
            L = tc.W.landmarks(1); Pl = [L.xy L.z];
            p = testV2005Sensors.fixture([Pl(1:2) + [2 -3], Pl(3) + 15], deg2rad(25), deg2rad(-6), deg2rad(4));
            c = tc.Cfg.RGB_NADIR; s = mgv2.sensors.sampleCamera(tc.Sc, c, tc.Ms, p, 3);
            uv = mgv2.scene.projectToImage(c.mount, s.T_world_sensor, Pl);
            I = double(reshape(s.image_rgb_uint8, [], 3)) / 255;
            m = vecnorm(I ./ max(sum(I, 2), eps) - L.color ./ sum(L.color), 2, 2) < 0.08 & sum(I, 2) > 0.3;
            [vv, uu] = ind2sub([c.mount.height_px c.mount.width_px], find(m));
            tc.verifyGreaterThan(nnz(m), 20, 'landmark visible in the RGB frame');
            cen = [mean(uu) mean(vv)];
            tc.verifyLessThan(norm(cen - uv), 1.5, 'landmark pixel centroid within 1.5 px of its projection');
            [O, D] = mgv2.scene.pixelRays(c.mount, s.T_world_sensor, cen); h = mgv2.sensors.castRays(tc.Sc, O, D, 200);
            tc.verifyLessThan(norm(h.P(1:2) - L.xy), 0.5, 'map ENU from the image within 0.5 m (SC-07)');
        end

        function v08_rgbValidityMask(tc)                                  % SC-08
            w = tc.W; p = testV2005Sensors.fixture([0 0 25], 0, deg2rad(-75), 0);   % pitched up: sky in view
            s = mgv2.sensors.sampleCamera(tc.Sc, tc.Cfg.RGB_NADIR, tc.Ms, p, 1);
            M = s.valid_pixel_mask; I = s.image_rgb_uint8;
            tc.verifyTrue(any(~M(:)) && any(M(:)), 'partly sky: both valid and invalid pixels');
            tc.verifyTrue(all(I(repmat(~M, 1, 1, 3)) == 0), 'no fabricated values in invalid pixels');
            up = testV2005Sensors.fixture([0 0 25], 0, 0, pi);                        % inverted: only sky
            s2 = mgv2.sensors.sampleCamera(tc.Sc, tc.Cfg.RGB_NADIR, tc.Ms, up, 2);
            tc.verifyFalse(s2.valid); tc.verifyEqual(s2.invalid_reason, "NO_INTERSECTION"); tc.verifyFalse(any(s2.valid_pixel_mask(:)));
            tc.verifyEqual(size(s2.footprint_enu_m), [0 2]); mgv2.sensors.validateSample(s2);
            tc.verifyNotEmpty(w);
        end

        function v09_thermalKelvinAndPaletteInvariance(tc)                % SC-09, EVAL-04
            s = tc.Sys.latest("THERMAL_LWIR"); K = s.temperature_K; M = s.valid_pixel_mask;
            tc.verifyTrue(all(isfinite(K(M)) & K(M) > 200 & K(M) < 400), 'plausible apparent K');
            tc.verifyTrue(all(isnan(K(~M))));
            h0 = mgv2.sensors.checksum(K); K0 = K;
            for pal = ["IRONBOW","WHITE_HOT","BLACK_HOT","TURBO"]
                [rgb, ~, lim] = mgv2.sensors.thermalPalette(K, pal);
                tc.verifyClass(rgb, 'uint8'); tc.verifyEqual(size(rgb), [size(K) 3]);
                tc.verifyEqual(mgv2.sensors.checksum(K), h0, pal + ": Kelvin raster unchanged"); tc.verifyEqual(K, K0);
                tc.verifyEqual(lim - 273.15, [min(K(M)) max(K(M))] - 273.15, 'AbsTol', 1e-12, 'Celsius legend = K - 273.15');
            end
            tc.verifyEqual(300 - 273.15, 26.85, 'AbsTol', 1e-12, 'fixture C3: 300 K = 26.85 C');
            tc.verifyEqual(s.temperature_kind, "APPARENT");
            tc.verifyFalse(any(contains(string(fieldnames(s)), "surface_temperature", 'IgnoreCase', true)), 'private surface T never public');
        end

        function v10_thermalEnvironmentResponse(tc)                       % SC-10, G2
            p = testV2005Sensors.pose(tc.T, 801); out = struct();
            for mode = ["DAY_CLEAR","OVERCAST","LOW_CONTRAST"]
                sc = mgv2.sensors.buildSensorScene(tc.W, mgv2.sensors.defaultEnvironment(mode));
                s = mgv2.sensors.sampleCamera(sc, tc.Cfg.THERMAL_LWIR, tc.Ms, p, 5); K = s.temperature_K(s.valid_pixel_mask);
                out.(mode) = [mean(K) std(K)];
            end
            tc.verifyGreaterThan(out.DAY_CLEAR(2), out.OVERCAST(2), 'less sun -> less spatial contrast');
            % declared model direction: clear-day solar loading gives more contrast than BOTH reduced-sun cases.
            % (Overcast vs grazing dawn sun is not ordered by the model: slope orientation dominates at 4 deg sun.)
            tc.verifyGreaterThan(out.DAY_CLEAR(2), out.LOW_CONTRAST(2));
            tc.log(matlab.unittest.Verbosity.Terse, sprintf('SC-10 mean/std K: DAY %.2f/%.3f OVERCAST %.2f/%.3f LOW_CONTRAST %.2f/%.3f', ...
                out.DAY_CLEAR, out.OVERCAST, out.LOW_CONTRAST));
            tc.verifyGreaterThan(out.DAY_CLEAR(1), out.LOW_CONTRAST(1), 'colder dawn ambient -> lower apparent K');
            % emissivity: painted landmark (eps 0.90) reads cooler than bare ground at the same substrate temperature
            L = tc.W.landmarks(1); q = testV2005Sensors.fixture([L.xy L.z + 12], 0, 0, 0);
            s = mgv2.sensors.sampleCamera(tc.Sc, tc.Cfg.THERMAL_LWIR, tc.Ms, q, 6);
            uv = round(mgv2.scene.projectToImage(tc.Cfg.THERMAL_LWIR.mount, s.T_world_sensor, [L.xy L.z]));
            ring = s.temperature_K(uv(2) + (-18:18), uv(1) + [-18 18]);   % outside the ~10 px landmark disc
            tc.verifyLessThan(s.temperature_K(uv(2), uv(1)), median(ring(:)) - 0.5, 'lower emissivity -> lower apparent temperature');
        end

        function v11_lowContrastNotForced(tc)                             % SC-11
            sc = mgv2.sensors.buildSensorScene(tc.W, mgv2.sensors.defaultEnvironment("LOW_CONTRAST"));
            s = mgv2.sensors.sampleCamera(sc, tc.Cfg.THERMAL_LWIR, tc.Ms, testV2005Sensors.pose(tc.T, 801), 1);
            K = s.temperature_K(s.valid_pixel_mask);
            tc.verifyLessThan(max(K) - min(K), 3.0, 'low-contrast scene: no forced bright hotspot');
            tc.verifyTrue(s.valid);
        end

        function v12_lidarFlatPlane(tc)                                   % SC-12, fixture C2
            flat = mgv2.sensors.buildSensorScene(testV2005Sensors.flatWorld()); c = tc.Cfg.LIDAR_TERRAIN;
            p = testV2005Sensors.fixture([10 20 5], deg2rad(30), 0, 0);
            s = mgv2.sensors.sampleLidar(flat, c, tc.Ms, p, 1);
            h = s.T_world_sensor(3,4);                                       % sensor height above the plane z = 0
            tc.verifyEqual(h, 5 + c.mount.translation_body_m(3), 'AbsTol', 1e-12);
            el = s.scan_elevation_deg(:); v = s.valid_ray_mask; expect = h ./ sind(el) + c.params.range_bias_m;
            tc.verifyLessThan(max(abs(s.ranges_m(v) - expect(v))), 5 * c.params.range_sigma_m, 'ranges = h/sin(el) + bias within 5 sigma');
            [~, i] = max(el .* v); tc.verifyEqual(s.ranges_m(i), h / sind(el(i)), 'AbsTol', 4 * c.params.range_sigma_m + c.params.range_bias_m);
            tc.verifyEqual(s.altitude_agl_m, h, 'AbsTol', 0.1); tc.verifyEqual(s.terrain_height_m, 0, 'AbsTol', 0.1);
        end

        function v13_lidarSlopedTerrain(tc)                               % SC-13, G3
            c = tc.Cfg.LIDAR_TERRAIN;
            p = testV2005Sensors.pose(tc.T, 801); s = mgv2.sensors.sampleLidar(tc.Sc, c, tc.Ms, p, 2);
            v = s.valid_ray_mask; P = s.points_enu_m(v, :);
            hit = mgv2.sensors.castRays(tc.Sc, repmat(s.T_world_sensor(1:3,4)', nnz(v), 1), s.ray_unit_vectors_sensor(v,:) * s.T_world_sensor(1:3,1:3)', 100);
            err = s.ranges_m(v) - hit.t;
            tc.verifyLessThan(max(abs(err - c.params.range_bias_m)), 5 * c.params.range_sigma_m, 'ranges match shared-mesh intersections');
            zg = mgv2.scene.heightAt(tc.W, P(:,1), P(:,2)); terr = hit.kind == 1;
            tc.verifyGreaterThan(min(P(terr,3) - zg(terr)), -5 * (c.params.range_sigma_m + c.params.range_bias_m), 'no point deeper than range noise');
            tc.verifyEqual(s.points_enu_m(v,:), s.points_sensor_m(v,:) * s.T_world_sensor(1:3,1:3)' + s.T_world_sensor(1:3,4)', 'AbsTol', 1e-9);
            tc.verifyTrue(all(isnan(s.ranges_m(~v))) && all(isnan(s.points_enu_m(~v,:)), 'all'));
        end

        function v14_lidarOutOfRangeAndSky(tc)                            % SC-14, fixture C4
            flat = mgv2.sensors.buildSensorScene(testV2005Sensors.flatWorld()); c = tc.Cfg.LIDAR_TERRAIN; c.valid_range_m = [0.3 4];
            s = mgv2.sensors.sampleLidar(flat, c, tc.Ms, testV2005Sensors.fixture([10 20 5], 0, 0, 0), 1);
            tc.verifyFalse(any(s.valid_ray_mask)); tc.verifyTrue(all(s.ray_invalid_code == 2)); tc.verifyTrue(all(isnan(s.ranges_m)));
            tc.verifyEqual(s.invalid_reason, "OUT_OF_RANGE", 'no 4 m clipped "hit"');
            c = tc.Cfg.LIDAR_TERRAIN; s = mgv2.sensors.sampleLidar(flat, c, tc.Ms, testV2005Sensors.fixture([10 20 5], 0, 0, pi), 2);
            tc.verifyTrue(all(s.ray_invalid_code == 3)); tc.verifyEqual(s.invalid_reason, "NO_INTERSECTION");
            on = mgv2.sensors.sampleLidar(tc.Sc, c, tc.Ms, testV2005Sensors.pose(tc.T, 1), 3);   % on the pad: blind zone
            tc.verifyFalse(on.valid); tc.verifyEqual(on.invalid_reason, "OUT_OF_RANGE");
        end

        function v15_virtualNavigation(tc)                                % SC-15
            L = tc.Sys.Log; c = tc.Cfg.VIRTUAL_GNSS_INS; e = zeros(0, 3); T = tc.T;
            for k = 1:20:numel(T.tick_id)
                if mod(T.tick_id(k), 2), continue; end
                s = mgv2.sensors.sampleNav(c, tc.Ms, testV2005Sensors.pose(T, k), double(T.tick_id(k)) / 2, tc.Mc.virtual_wgs84_origin);
                e(end+1, :) = s.reported_position_enu_m - T.position_enu_m(k, :); %#ok<AGROW>
                tc.verifyEqual(s.measurement_kind, "REPORTED_VIRTUAL"); tc.verifyEqual(s.fix_type, "VIRTUAL_3D");
            end
            tc.verifyGreaterThan(min(vecnorm(e, 2, 2)), 0, 'reported != reference pose');
            tc.verifyLessThan(max(abs(e), [], 'all'), 8, 'errors bounded by bias + drift + noise model');
            tc.verifyEqual(nnz(L.sensor_id == "VIRTUAL_GNSS_INS"), floor(tc.Eng.TickId / 2) + 1);
            if ~isempty(which('enu2lla'))
                s = mgv2.sensors.sampleNav(c, tc.Ms, testV2005Sensors.pose(T, 801), 400, [12.97 77.59 900]);
                ref = enu2lla(s.reported_position_enu_m, [12.97 77.59 900], 'ellipsoid');
                tc.verifyEqual([s.virtual_lat_deg s.virtual_lon_deg], ref(1:2), 'AbsTol', 1e-7, 'tangent-plane approx vs enu2lla');
            end
            d = c; d.dropout_model.intervals_s = [10 12];
            s = mgv2.sensors.sampleNav(d, tc.Ms, testV2005Sensors.pose(T, 221), 110, [0 0 0]);
            tc.verifyFalse(s.valid); tc.verifyEqual([s.invalid_reason s.fix_type], ["SENSOR_DROPOUT" "NO_FIX"]); tc.verifyTrue(all(isnan(s.reported_position_enu_m)));
        end

        function v16_truthFirewall(tc)                                    % SC-17, EVAL-02
            w = tc.W; w.TargetTruth = struct('x', 1);
            tc.verifyError(@() mgv2.sensors.SensorSystem(w, tc.Mc), 'mgv2:TruthLeak');
            w = tc.W; w.objects.burial_depth_m = zeros(height(w.objects), 1);
            tc.verifyError(@() mgv2.sensors.SensorSystem(w, tc.Mc), 'mgv2:TruthLeak');
            c = tc.Cfg; c.RGB_NADIR.params.target_count = 3;
            tc.verifyError(@() mgv2.sensors.SensorSystem(tc.W, tc.Mc, SensorConfig=c), 'mgv2:TruthLeak');
            c = tc.Cfg; c.TargetTruth = 1; tc.verifyError(@() mgv2.sensors.validateSensorConfig(c), 'mgv2:TruthLeak');
            s = tc.Sys.latest("RGB_NADIR"); x = s; x.quality.hidden_truth = 1;
            tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
            x = s; x.quality.inner = {struct('label', "mine")}; tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak');
            x = s; x.quality.h = containers.Map(); tc.verifyError(@() mgv2.sensors.validateSample(x), 'mgv2:TruthLeak', 'objects rejected');
            for id = tc.Sys.Order, mgv2.sensors.assertPublic(tc.Sys.latest(id)); end
        end

        function v17_dropoutNoStaleFrames(tc)                             % SC-19, EVAL-07, fixture C6
            c = tc.Cfg; c.THERMAL_LWIR.dropout_model.intervals_s = [0.5 1.5];
            a = testV2005Sensors.shortRun(tc.W, tc.Mc, 60, SensorConfig=c, KeepFrames=100);
            L = a.Log(a.Log.sensor_id == "THERMAL_LWIR", :);
            in = L.t_s >= 0.5 & L.t_s <= 1.5;
            tc.verifyTrue(all(~L.valid(in)) && all(L.invalid_reason(in) == "SENSOR_DROPOUT"));
            tc.verifyTrue(all(L.valid(~in)));
            tc.verifyEqual(numel(unique(L.t_s)), height(L), 'every sample has its own pose time (no reused timestamps)');
            S = a.samplesAt(20); s = S{cellfun(@(x) x.sensor_id == "THERMAL_LWIR", S)};
            tc.verifyTrue(all(isnan(s.temperature_K(:)))); tc.verifyFalse(any(s.valid_pixel_mask(:)));
            tc.verifyEqual(s.display_min_K, NaN);
            tc.verifyTrue(all(a.Log.valid(a.Log.sensor_id == "RGB_NADIR")), 'RGB unaffected by thermal dropout');
        end

        function v18_repeatability(tc)                                    % SC-23
            a = testV2005Sensors.shortRun(tc.W, tc.Mc, 80); b = testV2005Sensors.shortRun(tc.W, tc.Mc, 80);
            tc.verifyEqual(a.Log.checksum, b.Log.checksum, 'same source + seed + config -> identical observations');
            m2 = tc.Mc; m2.seed = tc.Mc.seed + 1; d = testV2005Sensors.shortRun(tc.W, m2, 80);
            for id = ["RGB_NADIR","THERMAL_LWIR","LIDAR_TERRAIN","VIRTUAL_GNSS_INS"]
                tc.verifyNotEqual(d.Log.checksum(d.Log.sensor_id == id & d.Log.tick_id == 40), a.Log.checksum(a.Log.sensor_id == id & a.Log.tick_id == 40), ...
                    id + ": a different seed changes the noise");
            end
        end

        function v19_fullMissionAllSensors(tc)                            % SC-27
            tc.verifyEqual(tc.Eng.Phase, "COMPLETE");
            L = tc.Sys.Log; nT = tc.Eng.TickId;
            for id = tc.Sys.Order, tc.verifyEqual(nnz(L.sensor_id == id), floor(nT / tc.Sys.Period.(id)) + 1, id + ": no dropped/invented samples"); end
            cam = L(ismember(L.sensor_id, ["RGB_NADIR","THERMAL_LWIR"]), :);
            tc.verifyTrue(all(cam.valid), 'all camera frames valid in the nominal mission');
            li = L(L.sensor_id == "LIDAR_TERRAIN", :);
            tc.verifyTrue(all(li.valid | li.invalid_reason == "OUT_OF_RANGE"), 'LiDAR invalid only in the blind zone on the pad');
            tc.verifyLessThanOrEqual(nnz(~li.valid), 4);
            r = L(L.sensor_id == "RGB_NADIR", :);
            tc.verifyGreaterThan(numel(unique(r.checksum)), 0.95 * height(r), 'RGB frames change as the UAV moves');
        end

        function v20_rasterEqualsRayCasting(tc)                           % geometry exactness of the fast path
            for k = [1 61 801 1601 2401 height(tc.T)]
                p = testV2005Sensors.pose(tc.T, k);
                for id = ["RGB_NADIR","THERMAL_LWIR"]
                    cam = tc.Cfg.(id).mount; Tws = mgv2.scene.sensorPose(p, cam);
                    [uu, vv] = meshgrid(1:cam.width_px, 1:cam.height_px); [O, D] = mgv2.scene.pixelRays(cam, Tws, [uu(:) vv(:)]);
                    hr = mgv2.sensors.rasterView(tc.Sc, cam, Tws, 200); hc = mgv2.sensors.castRays(tc.Sc, O, D, 200);
                    tc.verifyEqual(hr.kind, hc.kind, sprintf('tick %d %s: same surface kind for every pixel', k - 1, id));
                    b = isfinite(hr.t); tc.verifyEqual(hr.t(b), hc.t(b), 'AbsTol', 1e-6);
                end
            end
        end

        function v21_uavToolboxLidarCrossCheck(tc)                        % native vs base caster (same geometry)
            tc.assumeNotEmpty(which('uavLidarPointCloudGenerator'), 'UAV Toolbox not installed');
            flat = testV2005Sensors.flatWorld(); sc = mgv2.sensors.buildSensorScene(flat); c = tc.Cfg.LIDAR_TERRAIN;
            p = testV2005Sensors.fixture([10 20 12], 0, 0, 0);
            ours = mgv2.sensors.sampleLidar(sc, c, tc.Ms, p, 1); Tws = ours.T_world_sensor;
            scene = mgv2.scene.toUavScenario(flat, 10);
            [pn, qn] = mgv2.frames.poseEnuToNed(Tws(1:3,4)', mgv2.frames.rotmToQuat(Tws(1:3,1:3) * diag([1 -1 -1])));
            plat = uavPlatform("v5", scene, "ReferenceFrame", "NED", "InitialPosition", pn - [0 0 0.05], "InitialOrientation", qn);
            updateMesh(plat, "cuboid", {[0.01 0.01 0.01]}, [1 0 0], [0 0 0], [1 0 0 0]);
            lid = uavLidarPointCloudGenerator("UpdateRate", 10, "MaxRange", 100, "AzimuthResolution", 2, "ElevationResolution", 2, ...
                "AzimuthLimits", [-180 178], "ElevationLimits", [45 89], "HasNoise", false, "HasOrganizedOutput", false);
            sen = uavSensor("lidar", plat, lid, "MountingLocation", [0 0 0.05], "MountingAngles", [0 0 0]);
            setup(scene); updateSensors(scene); [~, ~, pc] = read(sen);
            N = reshape(pc.Location, [], 3); N = N(all(isfinite(N), 2), :); rn = vecnorm(N, 2, 2); eln = asind(N(:,3) ./ rn);
            h = Tws(3,4); tc.verifyLessThan(median(abs(rn - h ./ sind(eln))), 0.01, 'native ranges = h/sin(el) on the flat plane');
            v = ours.valid_ray_mask; el = ours.scan_elevation_deg(:);
            tc.verifyLessThan(median(abs(ours.ranges_m(v) - c.params.range_bias_m - h ./ sind(el(v)))), 0.02, 'base caster agrees with the same geometry');
            tc.verifyGreaterThan(mean(N(:,3) > 0), 0.99, 'native +elevation points DOWN in the FRD sensor frame (verified convention)');
        end

        function v22_baseMatlabOnly(tc)                                   % SC-28
            d = fullfile(fileparts(fileparts(mfilename('fullpath'))), '+mgv2', '+sensors'); f = dir(fullfile(d, '*.m'));
            [~, pl] = matlab.codetools.requiredFilesAndProducts(fullfile({f.folder}, {f.name}));
            tc.verifyEqual(string({pl.Name}), "MATLAB", 'sensor package needs base MATLAB only (Mac-safe)');
            tc.log(matlab.unittest.Verbosity.Terse, sprintf('SC-28 environment: MATLAB %s, %s', version, computer));
        end

        function v24_lidarRangeFromValidRange(tc)                         % review fix 1: one range source
            flat = mgv2.sensors.buildSensorScene(testV2005Sensors.flatWorld()); p = testV2005Sensors.fixture([10 20 5], 0, 0, 0);
            c0 = tc.Cfg.LIDAR_TERRAIN;
            tc.verifyEqual(c0.valid_range_m, [0.3 100], 'nominal effective range unchanged (V2-003 rig defaults)');
            tc.verifyFalse(any(isfield(c0.mount, {'max_range_m','min_range_m'})), 'mount carries geometry only');
            s0 = mgv2.sensors.sampleLidar(flat, c0, tc.Ms, p, 1);
            tc.verifyEqual([s0.min_range_m s0.max_range_m], [0.3 100], 'reported = applied');
            ok0 = s0.valid_ray_mask | s0.ray_invalid_code == 1;   % 1 = configured 1% per-ray SENSOR_DROPOUT
            tc.verifyTrue(all(ok0) && any(s0.ray_invalid_code == 0), 'nominal: every ray valid except random dropout');
            c = c0; c.valid_range_m = [0.3 6];                         % max range via valid_range_m
            s = mgv2.sensors.sampleLidar(flat, c, tc.Ms, p, 1); h = s.T_world_sensor(3,4); el = s.scan_elevation_deg(:);
            far = h ./ sind(el) > 6;
            tc.verifyTrue(all(s.ray_invalid_code(far) == 2) && all(s.valid_ray_mask(~far) | s.ray_invalid_code(~far) == 1), 'rays beyond 6 m OUT_OF_RANGE, the rest valid (or dropout)');
            tc.verifyEqual(s.max_range_m, 6); tc.verifyTrue(all(s.ranges_m(s.valid_ray_mask) < 6 + 5 * c.params.range_sigma_m + c.params.range_bias_m));
            c = c0; c.valid_range_m = [6 100];                         % min range (blind zone) via valid_range_m
            s = mgv2.sensors.sampleLidar(flat, c, tc.Ms, p, 1); near = h ./ sind(el) < 6;
            tc.verifyTrue(all(s.ray_invalid_code(near) == 2) && all(s.valid_ray_mask(~near) | s.ray_invalid_code(~near) == 1), 'rays closer than 6 m invalid (blind zone)');
            tc.verifyEqual(s.min_range_m, 6); tc.verifyTrue(all(isnan(s.ranges_m(near))));
            both = ~near & s.valid_ray_mask & s0.valid_ray_mask;
            tc.verifyEqual(s.ranges_m(both), s0.ranges_m(both), 'same seq: unaffected rays bit-identical (range limits do not touch RNG)');
            mgv2.sensors.validateSample(s);
        end

        function v25_rangeConfigRejected(tc)                              % review fix 1: no contradictory sources
            c = tc.Cfg; c.LIDAR_TERRAIN.mount.max_range_m = 4;
            tc.verifyError(@() mgv2.sensors.validateSensorConfig(c), 'mgv2:InvalidSensorConfig');
            bad = {[0 100], [5 5], [-1 10], [0.3 NaN], [0.3 Inf], 7};
            for i = 1:numel(bad)
                c = tc.Cfg; c.LIDAR_TERRAIN.valid_range_m = bad{i};
                tc.verifyError(@() mgv2.sensors.validateSensorConfig(c), 'mgv2:InvalidSensorConfig', sprintf('LiDAR range case %d', i));
            end
            c = tc.Cfg; c.THERMAL_LWIR.dropout_model.intervals_s = [12 10];
            tc.verifyError(@() mgv2.sensors.validateSensorConfig(c), 'mgv2:InvalidSensorConfig', 'reversed dropout interval');
            c = tc.Cfg; c.RGB_NADIR.params = 3; tc.verifyError(@() mgv2.sensors.validateSensorConfig(c), 'mgv2:InvalidSensorConfig');
            ok = tc.Cfg; ok.LIDAR_TERRAIN.valid_range_m = [1 50];
            a = mgv2.sensors.SensorSystem(tc.W, tc.Mc, SensorConfig=ok);
            tc.verifyEqual(a.Config.LIDAR_TERRAIN.valid_range_m, [1 50], 'documented override workflow still accepted');
        end

        function v26_parameterFingerprint(tc)                             % review fix 2
            c0 = tc.Cfg; ids = tc.Sys.Order; fp = @(c) arrayfun(@(id) c.(id).parameter_hash, ids);
            h0 = fp(c0);
            tc.verifyTrue(all(startsWith(h0, "fnv1a64:")) && numel(unique(h0)) == 4);
            tc.verifyEqual(fp(mgv2.sensors.defaultSensorConfig()), h0, 'identical configurations -> identical fingerprints');
            tc.verifyEqual(fp(mgv2.sensors.validateSensorConfig(c0)), h0, 're-validation is idempotent');
            c = c0; c.THERMAL_LWIR.dropout_model.intervals_s = [38 42]; v = mgv2.sensors.validateSensorConfig(c);
            tc.verifyNotEqual(v.THERMAL_LWIR.parameter_hash, c0.THERMAL_LWIR.parameter_hash, 'thermal dropout change -> thermal fingerprint changes');
            tc.verifyEqual(fp(v) == h0, ids ~= "THERMAL_LWIR", 'other channels unchanged');
            tc.verifyEqual(c.THERMAL_LWIR.parameter_hash, c0.THERMAL_LWIR.parameter_hash, 'precondition: user-edited struct still holds the stale hash');
            c = c0; c.LIDAR_TERRAIN.valid_range_m = [0.3 60]; v = mgv2.sensors.validateSensorConfig(c);
            tc.verifyEqual(fp(v) == h0, ids ~= "LIDAR_TERRAIN", 'LiDAR range change -> only the LiDAR fingerprint changes');
            c = c0; c.RGB_NADIR.params.read_noise_dn = 1.5 + 1e-12; v = mgv2.sensors.validateSensorConfig(c);
            tc.verifyNotEqual(v.RGB_NADIR.parameter_hash, h0(ids == "RGB_NADIR"), 'full precision: a 1e-12 change is detected');
            c = c0; c.VIRTUAL_GNSS_INS.parameter_hash = "forged"; v = mgv2.sensors.validateSensorConfig(c);
            tc.verifyEqual(v.VIRTUAL_GNSS_INS.parameter_hash, h0(ids == "VIRTUAL_GNSS_INS"), 'supplied hash replaced by the effective fingerprint');
            r = c0.RGB_NADIR; r2 = orderfields(r, flip(fieldnames(r)));
            tc.verifyEqual(mgv2.sensors.configFingerprint(r2), mgv2.sensors.configFingerprint(r), 'field order does not matter');
            c = c0; c.THERMAL_LWIR.dropout_model.intervals_s = [38 42];
            a = mgv2.sensors.SensorSystem(tc.W, tc.Mc, SensorConfig=c);
            tc.verifyEqual(a.Config.THERMAL_LWIR.parameter_hash, mgv2.sensors.configFingerprint(a.Config.THERMAL_LWIR), ...
                'accepted config hash matches its effective parameters');
            tc.verifyEqual(a.Config.THERMAL_LWIR.dropout_model.intervals_s, [38 42]);
        end

        function v27_fingerprintDoesNotTouchSamples(tc)                   % schemas + RNG preserved
            p = testV2005Sensors.pose(tc.T, 801); c = tc.Cfg; c2 = c; c2.THERMAL_LWIR.dropout_model.intervals_s = [500 501];
            c2 = mgv2.sensors.validateSensorConfig(c2);
            a = mgv2.sensors.sampleCamera(tc.Sc, c.THERMAL_LWIR, tc.Ms, p, 9); b = mgv2.sensors.sampleCamera(tc.Sc, c2.THERMAL_LWIR, tc.Ms, p, 9);
            tc.verifyEqual(a.temperature_K, b.temperature_K, 'a config-only change outside the sample time leaves the sample bit-identical');
            tc.verifyEqual(fieldnames(a), fieldnames(b)); mgv2.sensors.validateSample(b);
            k = mgv2.sensors.contract(); tc.verifyFalse(any(contains(k.envelope, "hash")), 'envelope schema unchanged (fingerprint stays in config)');
        end

        function v28_missionStillSynchronised(tc)                         % regression after both fixes
            tc.verifyEqual(tc.Sys.Config.LIDAR_TERRAIN.valid_range_m, [0.3 100]);
            L = tc.Sys.Log; nT = tc.Eng.TickId;
            for id = tc.Sys.Order
                k = L.sensor_id == id;
                tc.verifyEqual(double(L.tick_id(k))', 0:tc.Sys.Period.(id):nT, id + ": no missing/duplicated/invented samples");
            end
            tc.verifyEqual(numel(unique(L.frame_id)), height(L), 'unique frame ids');
            s = tc.Sys.latest("LIDAR_TERRAIN"); tc.verifyEqual([s.min_range_m s.max_range_m], [0.3 100]);
        end

        function v23_performanceLogged(tc)                                % SC-29
            L = tc.Sys.Log; msg = "";
            for id = tc.Sys.Order
                g = sort(L.gen_ms(L.sensor_id == id)); tc.verifyTrue(all(isfinite(g)));
                msg = msg + sprintf('%s n=%d median %.1f p95 %.1f max %.1f ms; ', id, numel(g), median(g), g(ceil(0.95 * numel(g))), g(end));
            end
            load = sum(arrayfun(@(id) tc.Cfg.(id).rate_hz * median(L.gen_ms(L.sensor_id == id)) / 1e3, tc.Sys.Order));
            tc.log(matlab.unittest.Verbosity.Terse, "SC-29 " + msg + sprintf('median sensor load %.2f s per simulated s', load));
            tc.verifyLessThan(median(L.gen_ms(L.sensor_id == "RGB_NADIR")), 1000, 'sanity bound only; 1x feasibility reported in evidence');
        end
    end
end
