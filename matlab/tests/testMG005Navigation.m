classdef testMG005Navigation < matlab.unittest.TestCase
    %TESTMG005NAVIGATION MG-005 fixed grid navigation, virtual telemetry and UAV baseline.
    %   Covers: N-01 route legality, N-02 determinism, N-03 PoseSample contract, N-04 coverage,
    %   N-05 config validation, AT-10 exclusion conflict, C-05 navigation firewall (deferred
    %   from MG-004), C-10 ENU/NED basis, N-06 virtual geotag, N-07 uavScenario replay.
    %   Run from repo root: addpath('matlab'); runtests('matlab/tests/testMG005Navigation.m')
    %   SIMULATION ONLY. Kinematic baseline; no real flight or detection is claimed.

    methods (TestClassSetup)
        function addSourcePath(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Static)
        function c = fixture()
            c = struct('schema_version', "mg-contract/1.0", 'scenario_id', "S0-seed42", ...
                'seed', 42, 'x_min_m', 0, 'x_max_m', 20, 'y_min_m', 0, 'y_max_m', 20, ...
                'terrain_id', "flat-datum", 'grid_spacing_m', 2, 'dt_s', 0.1, ...
                'sampling_hz', 10, 'altitude_m', 2, 'speed_mps', 2, 'noise_seed', 7, ...
                'target_count', 1, 'clutter_count', 1, 'min_separation_m', 0.5, ...
                'soil_class', "synthetic_loam", 'model_version', "mg005-0.1");
        end
        function [nav, g, route, poses] = runPipeline(c)
            [g, ~] = mineguard.scenario.generateScenario(c);
            nav = mineguard.navigation.navigationConfigFromExperiment(c);
            route = mineguard.navigation.makeGridRoute(nav, g);
            poses = mineguard.navigation.simulatePose(nav, g, route);
        end
    end

    methods (Test)
        function n01_routeLegalAndSerpentine(tc)
            c = testMG005Navigation.fixture();
            [nav, g, route] = testMG005Navigation.runPipeline(c);
            b = g.bounds_enu_m;
            tc.verifySize(route, [100 3]);                      % 10 x 10 cells of 2 m
            tc.verifyTrue(all(route(:,1) > b(1) & route(:,1) < b(2) & route(:,2) > b(3) & route(:,2) < b(4)));
            tc.verifyTrue(all(route(:,3) == nav.altitude_m));
            tc.verifyEqual(route(1,1:2), [1 1]);                % first cell centre (SW)
            tc.verifyEqual(route(10,1:2), [19 1]);              % row 1 runs east
            tc.verifyEqual(route(11,1:2), [19 3]);              % row 2 starts east, runs west
            tc.verifyEqual(route(20,1:2), [1 3]);
            legs = sqrt(sum(diff(route(:,1:2)).^2, 2));
            tc.verifyLessThanOrEqual(max(legs), nav.grid_spacing_m + 1e-12);   % no jumps
            % Non-divisible field: pitch <= spacing and all cells inside.
            c.x_max_m = 7; c.y_max_m = 3;
            [~, g2, r2] = testMG005Navigation.runPipeline(c);
            tc.verifyEqual(size(r2,1), 4*2);
            tc.verifyTrue(all(r2(:,1) < g2.bounds_enu_m(2)));
        end

        function n02_deterministic(tc)
            c = testMG005Navigation.fixture();
            [g, ~] = mineguard.scenario.generateScenario(c);
            nav = mineguard.navigation.navigationConfigFromExperiment(c, ...
                'virtual_origin_lat_deg', 12.97, 'virtual_origin_lon_deg', 77.59, 'gps_sigma_m', 1.5);
            before = rng;
            r1 = mineguard.navigation.makeGridRoute(nav, g);  p1 = mineguard.navigation.simulatePose(nav, g, r1);
            r2 = mineguard.navigation.makeGridRoute(nav, g);  p2 = mineguard.navigation.simulatePose(nav, g, r2);
            tc.verifyEqual(r1, r2);
            tc.verifyTrue(isequaln(p1, p2));
            tc.verifyEqual(rng, before, 'global RNG modified');
        end

        function n03_poseSampleContract(tc)
            c = testMG005Navigation.fixture();
            [nav, g, route, p] = testMG005Navigation.runPipeline(c);
            tc.verifyEqual(string(p.Properties.VariableNames), ["pose_sample_id","t_s","x_east_m", ...
                "y_north_m","z_up_m","roll_rad","pitch_rad","yaw_rad","virtual_lat_deg", ...
                "virtual_lon_deg","gps_sigma_m","waypoint_id","mission_state"]);
            tc.verifyClass(p.pose_sample_id, 'string'); tc.verifyClass(p.waypoint_id, 'string');
            tc.verifyClass(p.mission_state, 'string');
            tc.verifyEqual(numel(unique(p.pose_sample_id)), height(p));
            tc.verifyTrue(all(diff(p.t_s) > 0), 't_s must strictly increase');
            tc.verifyEqual(p.t_s(1), 0);
            b = g.bounds_enu_m;
            tc.verifyTrue(all(p.x_east_m >= b(1) & p.x_east_m <= b(2) & p.y_north_m >= b(3) & p.y_north_m <= b(4)));
            tc.verifyEqual(p.mission_state(1), "INIT");
            tc.verifyEqual(p.mission_state(end), "COMPLETE");
            tc.verifyTrue(all(ismember(p.mission_state, ["INIT","SURVEY","COMPLETE","ABORTED"])));
            tc.verifyEqual([p.x_east_m(end) p.y_north_m(end) p.z_up_m(end)], route(end,:), 'AbsTol', 1e-9);
            % Constant speed: the step distance equals speed*dt, apart from the last step and corner samples.
            step = sqrt(diff(p.x_east_m).^2 + diff(p.y_north_m).^2);
            tc.verifyLessThanOrEqual(max(step), nav.speed_mps * nav.dt_s + 1e-9);
            pathLen = sum(sqrt(sum(diff(route).^2, 2)));
            tc.verifyEqual(p.t_s(end), pathLen / nav.speed_mps, 'AbsTol', 1e-9);
            tc.verifyTrue(all(isnan(p.virtual_lat_deg)) && all(isnan(p.gps_sigma_m)), 'no origin -> NaN geotags');
            tc.verifyTrue(all(p.yaw_rad >= -pi & p.yaw_rad <= pi));
            tc.verifyEqual(p.yaw_rad(2), 0, 'AbsTol', 1e-12);    % first row heads east
        end

        function n04_coverage(tc)
            c = testMG005Navigation.fixture();
            [nav, g, route, p] = testMG005Navigation.runPipeline(c);
            s = mineguard.navigation.computeCoverage(nav, g, p);
            tc.verifyEqual(s.coverage_fraction, 1);
            tc.verifyEqual(s.total_valid_cells, 100);
            tc.verifyTrue(s.completed);
            tc.verifyEqual(s.distance_m, sum(sqrt(sum(diff(route).^2, 2))), 'RelTol', 1e-9);
            tc.verifyEqual(s.mission_time_s, s.distance_m / nav.speed_mps, 'RelTol', 1e-9);
            % A truncated log reports partial coverage honestly.
            half = mineguard.navigation.computeCoverage(nav, g, p(1:floor(height(p)/2), :));
            tc.verifyLessThan(half.coverage_fraction, 1);
            tc.verifyGreaterThan(half.coverage_fraction, 0.3);
        end

        function n05_rejectsInvalidNavConfig(tc)
            c = testMG005Navigation.fixture();
            [nav, g] = testMG005Navigation.runPipeline(c);
            id = 'mineguard:InvalidNavigationConfig';
            mut = { @(n) setf(n,'grid_spacing_m',0), @(n) setf(n,'dt_s',-1), @(n) setf(n,'speed_mps',NaN), ...
                    @(n) setf(n,'altitude_m',-1), @(n) setf(n,'seed',1.5), @(n) rmfield(n,'dt_s'), ...
                    @(n) setf(n,'schema_version',"x"), @(n) setf(n,'virtual_origin_lat_deg',10), ...
                    @(n) setf(n,'gps_sigma_m',1) };
            for k = 1:numel(mut)
                tc.verifyError(@() mineguard.navigation.makeGridRoute(mut{k}(nav), g), id, sprintf('mutation %d', k));
            end
            tc.verifyError(@() mineguard.navigation.simulatePose(nav, g, [1 1]), 'mineguard:InvalidNavigationInput');
            tc.verifyError(@() mineguard.navigation.simulatePose(nav, g, [1 1 2; 50 1 2]), 'mineguard:InvalidNavigationInput');
            tc.verifyError(@() mineguard.navigation.simulatePose(nav, g, [1 1 2; 1 1 2]), 'mineguard:InvalidNavigationInput');
        end

        function at10_exclusionHandling(tc)
            c = testMG005Navigation.fixture();
            % Edge exclusion (west strip): cells are dropped, no leg crosses it.
            c.exclusion_polygons_enu_m = {[0 0; 4 0; 4 20; 0 20]};
            [nav, g, route, p] = testMG005Navigation.runPipeline(c);
            tc.verifyEqual(size(route,1), 80);
            tc.verifyFalse(any(inpolygon(p.x_east_m, p.y_north_m, [0 4 4 0], [0 0 20 20])), 'pose inside exclusion');
            s = mineguard.navigation.computeCoverage(nav, g, p);
            tc.verifyEqual(s.total_valid_cells, 80);
            tc.verifyEqual(s.coverage_fraction, 1);
            % Interior exclusion that a row must cross: rejected, never silently overflown.
            c.exclusion_polygons_enu_m = {[8 8; 12 8; 12 12; 8 12]};
            [g2, ~] = mineguard.scenario.generateScenario(c);
            tc.verifyError(@() mineguard.navigation.makeGridRoute(nav, g2), 'mineguard:RouteConflict');
        end

        function c05_navigationTruthFirewall(tc)
            % (1) Signatures take only (navConfig, geometry[, route]).
            tc.verifyEqual(nargin('mineguard.navigation.makeGridRoute'), 2);
            tc.verifyEqual(nargin('mineguard.navigation.simulatePose'), 3);
            % (2) Leaked truth in inputs is rejected.
            c = testMG005Navigation.fixture(); c.target_count = 5;
            [g, truth] = mineguard.scenario.generateScenario(c);
            nav = mineguard.navigation.navigationConfigFromExperiment(c);
            tc.verifyFalse(any(isfield(nav, {'target_count','clutter_count','soil_class','min_separation_m','label'})));
            bad = nav; bad.target_count = 5;
            tc.verifyError(@() mineguard.navigation.makeGridRoute(bad, g), 'mineguard:InvalidNavigationConfig');
            tc.verifyError(@() mineguard.navigation.makeGridRoute(c, g), 'mineguard:InvalidNavigationConfig');
            tc.verifyError(@() mineguard.navigation.makeGridRoute(nav, truth), 'mineguard:InvalidNavigationInput');
            g2 = g; g2.hidden_truth = truth;
            tc.verifyError(@() mineguard.navigation.makeGridRoute(nav, g2), 'mineguard:InvalidNavigationInput');
            % (3) Truth independence: different hidden truth, same geometry -> identical route and poses.
            c1 = c; c1.seed = 1;  c1.target_count = 5;
            c2 = c; c2.seed = 99; c2.target_count = 0; c2.clutter_count = 0;
            [ga, ta] = mineguard.scenario.generateScenario(c1);
            [gb, tb] = mineguard.scenario.generateScenario(c2);
            tc.verifyFalse(isequal(ta, tb));
            tc.verifyEqual(ga, gb);
            na = mineguard.navigation.navigationConfigFromExperiment(c1);
            nb = mineguard.navigation.navigationConfigFromExperiment(c2);
            ra = mineguard.navigation.makeGridRoute(na, ga); rb = mineguard.navigation.makeGridRoute(nb, gb);
            tc.verifyEqual(ra, rb);
            tc.verifyTrue(isequaln(mineguard.navigation.simulatePose(na, ga, ra), mineguard.navigation.simulatePose(nb, gb, rb)));
            % (4) Source scan: navigation code never references truth fields.
            files = dir(fullfile(fileparts(which('mineguard.navigation.makeGridRoute')), '**', '*.m'));
            tc.verifyGreaterThanOrEqual(numel(files), 8);
            for k = 1:numel(files)
                src = fileread(fullfile(files(k).folder, files(k).name));
                code = strjoin(regexprep(splitlines(string(src)), '%.*$', ''), newline);  % strip comments
                tc.verifyFalse(contains(code, ["hidden_truth","TargetTruth","burial_depth_m","material_type", ...
                    "target_count","clutter_count",".label","generateScenario"]), files(k).name);
            end
        end

        function c10_enuNedBasis(tc)
            tc.verifyEqual(mineguard.uav.enuToNed([1 0 0]), [0 1 0]);   % east  -> NED east (2nd)
            tc.verifyEqual(mineguard.uav.enuToNed([0 1 0]), [1 0 0]);   % north -> NED north (1st)
            tc.verifyEqual(mineguard.uav.enuToNed([0 0 1]), [0 0 -1]);  % up    -> NED down negative
            p = [3 -4 5; 0.5 2 0];
            tc.verifyEqual(mineguard.uav.enuToNed(mineguard.uav.enuToNed(p)), p);
        end

        function n06_virtualGeotag(tc)
            c = testMG005Navigation.fixture();
            [g, ~] = mineguard.scenario.generateScenario(c);
            nav = mineguard.navigation.navigationConfigFromExperiment(c, 'virtual_origin_lat_deg', 12.97, 'virtual_origin_lon_deg', 77.59);
            p = mineguard.navigation.simulatePose(nav, g, mineguard.navigation.makeGridRoute(nav, g));
            tc.verifyTrue(all(isfinite([p.virtual_lat_deg; p.virtual_lon_deg])));
            tc.verifyTrue(all(p.gps_sigma_m == 0));
            % 1 m north ~ 8.98e-6 deg; check projection back to metres.
            R = 6378137;
            tc.verifyEqual(deg2rad(p.virtual_lat_deg - 12.97) * R, p.y_north_m, 'AbsTol', 1e-6);
            tc.verifyEqual(deg2rad(p.virtual_lon_deg - 77.59) * R * cosd(12.97), p.x_east_m, 'AbsTol', 1e-6);
            nav.gps_sigma_m = 2;
            pn = mineguard.navigation.simulatePose(nav, g, mineguard.navigation.makeGridRoute(nav, g));
            err = deg2rad(pn.virtual_lat_deg - 12.97) * R - pn.y_north_m;
            tc.verifyGreaterThan(std(err), 1.5); tc.verifyLessThan(std(err), 2.5);   % ~N(0, 2 m)
        end

        function n07_uavScenarioReplay(tc)
            c = testMG005Navigation.fixture(); c.x_max_m = 6; c.y_max_m = 4;
            [~, ~, ~, p] = testMG005Navigation.runPipeline(c);
            [scene, logged] = mineguard.uav.replayInUavScenario(p);
            tc.verifyClass(scene, 'uavScenario');
            tc.verifyEqual(logged, [p.x_east_m p.y_north_m p.z_up_m], 'AbsTol', 1e-9);
            tc.verifyEqual(scene.CurrentTime, height(p) / scene.UpdateRate, 'RelTol', 1e-9);
        end
    end
end

function s = setf(s, f, v)
s.(f) = v;
end
