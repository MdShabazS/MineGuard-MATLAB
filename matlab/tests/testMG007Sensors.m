classdef testMG007Sensors < matlab.unittest.TestCase
    %TESTMG007SENSORS MG-006 acceptance tests S-01..S-14 for the MG-007 synthetic sensor proxies.
    %   Run from repo root: addpath('matlab'); runtests('matlab/tests/testMG007Sensors.m')
    %   SIMULATION ONLY. These tests check model properties under ASSUMED parameters. They
    %   are not a measure of mine-detection performance.

    methods (TestClassSetup)
        function addPaths(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'experiments')));
        end
    end

    methods (Static)
        function c = config()
            c = struct('schema_version', "mg-contract/1.0", 'scenario_id', "S0-mg007", ...
                'seed', 42, 'x_min_m', 0, 'x_max_m', 20, 'y_min_m', 0, 'y_max_m', 20, ...
                'terrain_id', "flat-datum", 'grid_spacing_m', 1, 'dt_s', 0.1, 'sampling_hz', 10, ...
                'altitude_m', 1, 'speed_mps', 1, 'noise_seed', 7, 'target_count', 0, 'clutter_count', 0, ...
                'min_separation_m', 0.5, 'soil_class', "synthetic_loam", 'model_version', "mg007-0.1");
            c.sensor_settings = mg007FixtureSettings();
        end
        function s = scenario(c, objects)
            % objects: Nx4 cell rows {x, y, depth, material} placed as hidden truth (forward-model input only).
            [g, t, e] = mineguard.scenario.generateScenario(c);
            if nargin > 1 && ~isempty(objects)
                n = size(objects, 1);
                t = table(compose("OBJ-%04d", (1:n)'), cell2mat(objects(:,1)), cell2mat(objects(:,2)), ...
                    cell2mat(objects(:,3)), string(objects(:,4)), categorical(repmat("target", n, 1), ["target" "clutter"]), ...
                    repmat("synthetic_loam", n, 1), cell2mat(objects(:,3)) == 0, 'VariableNames', t.Properties.VariableNames);
            end
            s = struct('config', c, 'geometry', g, 'hidden_truth', t, 'environment', e);
        end
        function p = poses(xyz)
            n = size(xyz, 1);
            p = table(compose("P-%06d", (1:n)'), (0:n-1)' * 0.1, xyz(:,1), xyz(:,2), xyz(:,3), ...
                zeros(n,1), zeros(n,1), zeros(n,1), NaN(n,1), NaN(n,1), NaN(n,1), repmat("WP-0001", n, 1), ...
                repmat("SURVEY", n, 1), 'VariableNames', {'pose_sample_id','t_s','x_east_m','y_north_m', ...
                'z_up_m','roll_rad','pitch_rad','yaw_rad','virtual_lat_deg','virtual_lon_deg','gps_sigma_m', ...
                'waypoint_id','mission_state'});
        end
        function c = noiseless(c)
            c.sensor_settings.thermal.thermal_noise_sigma_K = 0;
            c.sensor_settings.em.em_noise_sigma_norm = 0;
        end
    end

    methods (Test)
        function s01_flatBaselineUnits(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            c.sensor_settings.thermal.contrast_amplitude_K = 0;
            s = testMG007Sensors.scenario(c);
            p = testMG007Sensors.poses([10 10 1]);
            th = mineguard.sensors.simulateThermal(c, s, p);
            em = mineguard.sensors.simulateEM(c, s, p);
            tc.verifyTrue(th.valid);
            tc.verifyEqual(th.temperature_K, 293.15, 'AbsTol', 1e-12);
            tc.verifyTrue(isnan(th.response_norm));
            tc.verifyEqual(th.sensor_kind, "thermal");
            tc.verifyTrue(isnan(em.temperature_K));
            tc.verifyEqual(em.response_norm, 0.05, 'AbsTol', 1e-12);   % background only
            tc.verifyEqual(em.sensor_kind, "em");
            tc.verifyEqual(th.standoff_m, 1); tc.verifyEqual(th.footprint_radius_m, tan(0.35), 'AbsTol', 1e-12);
        end

        function s02_zeroContrastNoGuaranteedHotspot(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            c.sensor_settings.thermal.contrast_amplitude_K = 0;
            p = testMG007Sensors.poses([10 10 0.5; 10.1 10 0.5]);
            withT = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c, {10, 10, 0, "synthetic_cased_surrogate"}), p);
            empty = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c), p);
            tc.verifyEqual(withT.temperature_K, empty.temperature_K);
        end

        function s03_footprintDilutionNeverAmplifies(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            s = testMG007Sensors.scenario(c, {10, 10, 0, "synthetic_cased_surrogate"});
            h = [0.2 0.5 1 2 5]';
            th = mineguard.sensors.simulateThermal(c, s, testMG007Sensors.poses([repmat([10 10], 5, 1) h]));
            dT = th.temperature_K - 293.15;
            tc.verifyTrue(all(diff(dT) <= 1e-12), 'contrast must not grow with footprint');
            tc.verifyTrue(all(diff(th.footprint_radius_m) > 0));
            tc.verifyLessThanOrEqual(max(dT), 2.0 + 1e-12);           % bounded by A*g*1
            R = 5 * tan(0.35);                                          % analytic dilution a^2/R^2
            tc.verifyEqual(dT(end), 2.0 * (0.15 / R)^2, 'RelTol', 1e-9);
            % Lateral offset beyond footprint + object radius: no contribution.
            far = mineguard.sensors.simulateThermal(c, s, testMG007Sensors.poses([12 10 0.5]));
            tc.verifyEqual(far.temperature_K, 293.15, 'AbsTol', 1e-12);
        end

        function s04_signedAndTimeDependentContrast(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            p = testMG007Sensors.poses([10 10 0.3]);
            obj = {10, 10, 0.02, "synthetic_cased_surrogate"};
            vals = zeros(1, 3); amps = [2 0 -2];
            for k = 1:3
                c.sensor_settings.thermal.contrast_amplitude_K = amps(k);
                vals(k) = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c, obj), p).temperature_K;
            end
            tc.verifyGreaterThan(vals(1), 293.15); tc.verifyEqual(vals(2), 293.15, 'AbsTol', 1e-12);
            tc.verifyLessThan(vals(3), 293.15);
            % Diurnal cosine forcing: contrast peaks at 14:00 and inverts 12 h later (02:00).
            c.sensor_settings.thermal.contrast_amplitude_K = 2;
            c.sensor_settings.thermal.diurnal_mode = "cosine";
            c.sensor_settings.thermal.contrast_peak_time_s = 14 * 3600;
            c.sensor_settings.thermal.time_of_day_s = 14 * 3600;
            noon = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c, obj), p).temperature_K;
            c.sensor_settings.thermal.time_of_day_s = 2 * 3600;
            night = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c, obj), p).temperature_K;
            c.sensor_settings.thermal.time_of_day_s = 8 * 3600;      % quarter period: contrast vanishes
            dawn = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c, obj), p).temperature_K;
            tc.verifyGreaterThan(noon, 293.15); tc.verifyLessThan(night, 293.15);
            tc.verifyEqual(noon - 293.15, 293.15 - night, 'RelTol', 1e-9);
            tc.verifyEqual(dawn, 293.15, 'AbsTol', 1e-9);
            % Clutter can exceed the target: no hard-coded target > clutter rule.
            c.sensor_settings.thermal.diurnal_mode = "static";
            rock = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c, {10, 10, 0.02, "synthetic_rock"}), p).temperature_K;
            tgt  = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c, obj), p).temperature_K;
            tc.verifyGreaterThan(rock, tgt);
        end

        function s05_hotRockWithoutTarget(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            p = testMG007Sensors.poses([10 10 0.5]);
            s = testMG007Sensors.scenario(c, {10, 10, 0, "synthetic_rock"});
            s.hidden_truth.label(:) = "clutter";
            th = mineguard.sensors.simulateThermal(c, s, p);
            empty = mineguard.sensors.simulateThermal(c, testMG007Sensors.scenario(c), p);
            tc.verifyGreaterThan(th.temperature_K, empty.temperature_K, 'positive anomaly with no target');
            tc.verifyFalse(any(ismember(th.Properties.VariableNames, {'label','target_id','material_type','x_east_m','y_north_m','burial_depth_m'})));
        end

        function s06_emStandoffStressAndDomain(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            s = testMG007Sensors.scenario(c, {10, 10, 0.1, "synthetic_metal_cased_surrogate"});
            h = [0.05 0.2 0.5 1 2 5]';
            em = mineguard.sensors.simulateEM(c, s, testMG007Sensors.poses([repmat([10 10], 6, 1) h]));
            v = em.valid;
            tc.verifyEqual(v', [true true true true true false]);       % 5 m beyond 2 m modelling cutoff
            tc.verifyTrue(all(diff(em.response_norm(v)) <= 0), 'signal must not strengthen with separation');
            tc.verifyTrue(isnan(em.response_norm(6)));
            tc.verifyEqual(em.invalid_reason(6), "MODEL_OUT_OF_DOMAIN");
            tc.verifyEqual(em.standoff_m(6), 5);
            % Analytic check at 0.2 m standoff: f(d) = 1/(1+(d/0.3)^3), d = 0.3.
            tc.verifyEqual(em.response_norm(2), 0.05 + 1.0 / (1 + 1), 'AbsTol', 1e-12);
        end

        function s07_nonmetallicNoMetalContribution(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            s = testMG007Sensors.scenario(c, {10, 10, 0.05, "synthetic_plastic_surrogate"});
            em = mineguard.sensors.simulateEM(c, s, testMG007Sensors.poses([10 10 0.05; 10 10 0.2; 10 10 1]));
            tc.verifyEqual(em.response_norm, repmat(0.05, 3, 1), 'AbsTol', 1e-12);   % background only
            tc.verifyTrue(all(em.valid));
        end

        function s08_conductiveClutterAndTargetNoLabels(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            p = testMG007Sensors.poses([10 10 0.2]);
            sc = testMG007Sensors.scenario(c, {10, 10, 0.05, "synthetic_metal_debris"}); sc.hidden_truth.label(:) = "clutter";
            st = testMG007Sensors.scenario(c, {10, 10, 0.05, "synthetic_metal_cased_surrogate"});
            ec = mineguard.sensors.simulateEM(c, sc, p); et = mineguard.sensors.simulateEM(c, st, p);
            tc.verifyGreaterThan(ec.response_norm, 0.05); tc.verifyGreaterThan(et.response_norm, 0.05);
            tc.verifyEqual(string(ec.Properties.VariableNames), string(et.Properties.VariableNames));
            for T = {ec, et, mineguard.sensors.simulateThermal(c, st, p)}
                txt = strjoin(string(table2cell(T{1})), " ");
                tc.verifyFalse(contains(txt, ["OBJ-","target","clutter","synthetic_"]), 'sample text leaks truth');
            end
        end

        function s09_dropoutAndInvalidRowsKept(tc)
            c = testMG007Sensors.noiseless(testMG007Sensors.config());
            c.sensor_settings.thermal.dropout_pose_sample_ids = "P-000002";
            c.sensor_settings.em.dropout_pose_sample_ids = "P-000003";
            s = testMG007Sensors.scenario(c, {10, 10, 0.05, "synthetic_metal_cased_surrogate"});
            p = testMG007Sensors.poses([10 10 0.5; 10 10 0.5; 10 10 0.5; 25 10 0.5; 10 10 -0.1; 10 10 3]);
            th = mineguard.sensors.simulateThermal(c, s, p); em = mineguard.sensors.simulateEM(c, s, p);
            tc.verifyEqual(height(th), 6); tc.verifyEqual(height(em), 6);
            tc.verifyEqual(th.pose_sample_id, p.pose_sample_id); tc.verifyEqual(em.t_s, p.t_s);
            tc.verifyEqual(th.invalid_reason', ["" "DROPPED_SAMPLE" "" "POSE_INVALID" "POSE_INVALID" ""]);
            tc.verifyEqual(em.invalid_reason', ["" "" "DROPPED_SAMPLE" "POSE_INVALID" "POSE_INVALID" "MODEL_OUT_OF_DOMAIN"]);
            tc.verifyEqual(th.valid, th.invalid_reason == ""); tc.verifyEqual(em.valid, em.invalid_reason == "");
            tc.verifyTrue(all(isnan(th.temperature_K(~th.valid)))); tc.verifyTrue(all(isnan(em.response_norm(~em.valid))));
            tc.verifyTrue(all(isnan(th.response_norm))); tc.verifyTrue(all(isnan(em.temperature_K)));
            tc.verifyTrue(th.valid(3) && em.valid(2), 'opposite modality must not inherit a dropout');
            tc.verifyTrue(all(isnan(th.standoff_m(4:5))));
        end

        function s10_deterministicAndIndependentSeeds(tc)
            c = testMG007Sensors.config();
            c.sensor_settings.thermal.dropout_probability = 0.2;
            c.sensor_settings.em.dropout_probability = 0.2;
            s = testMG007Sensors.scenario(c, {10, 10, 0.05, "synthetic_metal_cased_surrogate"});
            p = testMG007Sensors.poses([linspace(5, 15, 500)' repmat(10, 500, 1) repmat(0.5, 500, 1)]);
            s0 = s; p0 = p; before = rng;
            th1 = mineguard.sensors.simulateThermal(c, s, p); th2 = mineguard.sensors.simulateThermal(c, s, p);
            em1 = mineguard.sensors.simulateEM(c, s, p);      em2 = mineguard.sensors.simulateEM(c, s, p);
            tc.verifyTrue(isequaln(th1, th2)); tc.verifyTrue(isequaln(em1, em2));
            tc.verifyEqual(rng, before, 'global RNG modified');
            tc.verifyTrue(isequaln(s, s0) && isequaln(p, p0), 'inputs modified');
            tc.verifyNotEqual(s.environment.rng.thermal_seed, s.environment.rng.em_seed);
            tc.verifyFalse(isequal(th1.valid, em1.valid), 'dropout masks must not be coupled');
            % Noise innovations: compare noiseless runs against noisy runs.
            cn = testMG007Sensors.noiseless(c);
            cn.sensor_settings.thermal = rmfield(cn.sensor_settings.thermal, 'dropout_probability');
            cn.sensor_settings.em = rmfield(cn.sensor_settings.em, 'dropout_probability');
            c2 = c; c2.sensor_settings.thermal = rmfield(c.sensor_settings.thermal, 'dropout_probability');
            c2.sensor_settings.em = rmfield(c.sensor_settings.em, 'dropout_probability');
            eT = (mineguard.sensors.simulateThermal(c2, s, p).temperature_K - mineguard.sensors.simulateThermal(cn, s, p).temperature_K) / 0.1;
            eE = (mineguard.sensors.simulateEM(c2, s, p).response_norm - mineguard.sensors.simulateEM(cn, s, p).response_norm) / 0.02;
            r = corrcoef(eT, eE);
            tc.verifyLessThan(abs(r(1,2)), 0.2, 'thermal and EM noise must be independent');
        end

        function s11_schemaAndInputValidation(tc)
            c = testMG007Sensors.config();
            s = testMG007Sensors.scenario(c, {10, 10, 0.05, "synthetic_cased_surrogate"});
            p = testMG007Sensors.poses([5 5 1; 6 5 1; 7 5 1]);
            cols = ["sample_id","pose_sample_id","t_s","sensor_kind","temperature_K","response_norm", ...
                "noise_sigma","standoff_m","footprint_radius_m","valid","invalid_reason"];
            for T = {mineguard.sensors.simulateThermal(c, s, p), mineguard.sensors.simulateEM(c, s, p)}
                x = T{1};
                tc.verifyEqual(string(x.Properties.VariableNames), cols);
                tc.verifyClass(x.sample_id, 'string'); tc.verifyClass(x.pose_sample_id, 'string');
                tc.verifyClass(x.sensor_kind, 'string'); tc.verifyClass(x.valid, 'logical');
                tc.verifyClass(x.invalid_reason, 'string'); tc.verifyClass(x.temperature_K, 'double');
                tc.verifyEqual(numel(unique(x.sample_id)), height(x));
                tc.verifyTrue(all(ismember(x.pose_sample_id, p.pose_sample_id)));
                tc.verifyTrue(all(diff(x.t_s) >= 0));
                tc.verifyTrue(all(x.noise_sigma >= 0));
            end
            id = 'mineguard:InvalidSensorInput';
            bad = p; bad.pose_sample_id(2) = bad.pose_sample_id(1);
            tc.verifyError(@() mineguard.sensors.simulateThermal(c, s, bad), id);
            bad = p; bad.t_s(3) = 0;
            tc.verifyError(@() mineguard.sensors.simulateEM(c, s, bad), id);
            bad = p; bad.t_s(2) = NaN;
            tc.verifyError(@() mineguard.sensors.simulateEM(c, s, bad), id);
            s2 = s; s2.geometry.terrain_model.type = "dem";
            tc.verifyError(@() mineguard.sensors.simulateThermal(c, s2, p), id);
            s3 = rmfield(s, 'hidden_truth');
            tc.verifyError(@() mineguard.sensors.simulateEM(c, s3, p), id);
            tc.verifyError(@() mineguard.sensors.simulateEM(c, s, table2array(p(:,2:5))), id);
            % Empty pose table: typed zero-row output.
            e0 = mineguard.sensors.simulateThermal(c, s, p([], :));
            tc.verifyEqual(height(e0), 0); tc.verifyEqual(string(e0.Properties.VariableNames), cols);
        end

        function s12_invalidSensorConfig(tc)
            c = testMG007Sensors.config();
            s = testMG007Sensors.scenario(c, {10, 10, 0.05, "synthetic_cased_surrogate"});
            p = testMG007Sensors.poses([10 10 1]);
            id = 'mineguard:InvalidSensorConfig';
            th = { {'background_temperature_K', NaN}, {'background_temperature_K', 0}, {'contrast_amplitude_K', Inf}, ...
                   {'camera_half_fov_rad', 0}, {'camera_half_fov_rad', pi/2}, {'thermal_noise_sigma_K', -1}, ...
                   {'thermal_depth_scale_m', 0}, {'diurnal_mode', "hourly"} };
            for k = 1:numel(th)
                b = c; b.sensor_settings.thermal.(th{k}{1}) = th{k}{2};
                tc.verifyError(@() mineguard.sensors.simulateThermal(b, s, p), id, th{k}{1});
            end
            b = c; b.sensor_settings.thermal = rmfield(b.sensor_settings.thermal, 'thermal_object_radius_m');
            tc.verifyError(@() mineguard.sensors.simulateThermal(b, s, p), id);
            em = { {'em_model_kind', "dipole"}, {'em_distance_scale_m', -1}, {'em_falloff_exponent', 0}, ...
                   {'em_noise_sigma_norm', NaN}, {'em_model_max_standoff_m', 0}, {'em_footprint_radius_m', -0.1}, ...
                   {'em_background_norm', Inf} };
            for k = 1:numel(em)
                b = c; b.sensor_settings.em.(em{k}{1}) = em{k}{2};
                tc.verifyError(@() mineguard.sensors.simulateEM(b, s, p), id, em{k}{1});
            end
            % Unknown material: rejected, never assumed metallic.
            su = testMG007Sensors.scenario(c, {10, 10, 0.05, "mystery_alloy"});
            tc.verifyError(@() mineguard.sensors.simulateEM(c, su, p), id);
            tc.verifyError(@() mineguard.sensors.simulateThermal(c, su, p), id);
            % Unconfigured channel: typed rows marked UNCONFIGURED_SENSOR (no invented parameters).
            b = c; b.sensor_settings = rmfield(b.sensor_settings, 'em');
            u = mineguard.sensors.simulateEM(b, s, p);
            tc.verifyFalse(u.valid); tc.verifyEqual(u.invalid_reason, "UNCONFIGURED_SENSOR"); tc.verifyTrue(isnan(u.response_norm));
            b = rmfield(c, 'sensor_settings');
            u = mineguard.sensors.simulateThermal(b, s, p);
            tc.verifyEqual(u.invalid_reason, "UNCONFIGURED_SENSOR");
        end

        function s13_emptyFieldBackgroundOnly(tc)
            c = testMG007Sensors.config();     % noise on
            s = testMG007Sensors.scenario(c);
            n = 4000;
            p = testMG007Sensors.poses([linspace(1, 19, n)' repmat(10, n, 1) repmat(0.5, n, 1)]);
            th = mineguard.sensors.simulateThermal(c, s, p); em = mineguard.sensors.simulateEM(c, s, p);
            tc.verifyTrue(all(th.valid) && all(em.valid));
            % 99.9 % normal CI on the mean (z = 3.29).
            tc.verifyLessThan(abs(mean(th.temperature_K) - 293.15), 3.29 * 0.1 / sqrt(n));
            tc.verifyLessThan(abs(mean(em.response_norm) - 0.05), 3.29 * 0.02 / sqrt(n));
            tc.verifyEqual(std(th.temperature_K), 0.1, 'RelTol', 0.06);
            tc.verifyEqual(std(em.response_norm), 0.02, 'RelTol', 0.06);
        end

        function s14_sensitivitySweeps(tc)
            out = runMG007Sensitivity();
            d = out.depth;
            tc.verifyTrue(all(diff(d.thermal_contrast_K_at_0p5m) < 0), 'thermal contrast decreases with depth');
            tc.verifyTrue(all(diff(d.em_signal_norm_at_0p5m) < 0), 'EM signal decreases with depth');
            k = out.clearance;
            tc.verifyTrue(all(diff(k.thermal_contrast_K) <= 1e-12));
            tc.verifyTrue(all(diff(k.em_signal_norm(k.em_valid)) < 0));
            tc.verifyEqual(k.em_invalid_reason(~k.em_valid), "MODEL_OUT_OF_DOMAIN");
            f = out.footprint;
            tc.verifyTrue(all(diff(f.thermal_contrast_K) <= 1e-12), 'wider footprint dilutes');
            nz = out.noise;
            tc.verifyEqual([nz.thermal_empirical_std_K(1) nz.em_empirical_std_norm(1)], [0 0], 'AbsTol', 1e-9);   % sigma 0: constant (rounding only)
            tc.verifyEqual(nz.thermal_empirical_std_K(2:end), nz.configured_sigma(2:end), 'RelTol', 0.08);
            tc.verifyEqual(nz.em_empirical_std_norm(2:end), nz.configured_sigma(2:end), 'RelTol', 0.08);
            dr = out.dropout;
            tc.verifyEqual(dr.thermal_invalid_fraction, dr.dropout_probability, 'AbsTol', 0.04);
        end
    end
end
