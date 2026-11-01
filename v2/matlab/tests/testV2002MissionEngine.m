classdef testV2002MissionEngine < matlab.unittest.TestCase
    %TESTV2002MISSIONENGINE V2-002 live mission engine tests. Headless (no figure needed). SIMULATION ONLY.
    %   From the repository root:  addpath('v2/matlab'); runtests('v2/matlab/tests/testV2002MissionEngine.m')

    properties
        Cfg; Wavy; Nom; NomT; WavyEng; WavyT
    end

    methods (TestClassSetup)
        function setup(tc)
            here = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(here));
            tc.Cfg = mgv2.mission.defaultConfig();
            tc.Wavy = struct('id', "wavy-slope", 'heightAt', @(x, y) 0.04 * x + 2 * sin(x / 15) .* cos(y / 20));
            tc.Nom = mgv2.engine.MissionEngine(tc.Cfg); tc.Nom.run(); tc.NomT = tc.Nom.poseLog();
            tc.WavyEng = mgv2.engine.MissionEngine(tc.Cfg, tc.Wavy); tc.WavyEng.run(); tc.WavyT = tc.WavyEng.poseLog();
        end
    end

    methods (Static)
        function e = runCfg(cfg, terrain)
            if nargin < 2, e = mgv2.engine.MissionEngine(cfg); else, e = mgv2.engine.MissionEngine(cfg, terrain); end
            e.run();
        end
    end

    methods (Test)
        function t01_phaseSequence(tc)
            want = ["CONFIGURED","PREFLIGHT","TAKEOFF","CLIMB","TRANSIT","SURVEY","RETURN_HOME","LANDING","COMPLETE"];
            for e = {tc.Nom, tc.WavyEng}
                tc.verifyEqual(e{1}.PhaseLog.phase', want);
                tc.verifyEqual(e{1}.FaultCode, "");
            end
            tc.verifyTrue(issorted(tc.Nom.PhaseLog.tick_id));
        end

        function t02_takeoff(tc)
            for Tc = {tc.NomT, tc.WavyT}
                T = Tc{1}; k = T.phase == "TAKEOFF"; c = tc.Cfg;
                tc.verifyLessThan(max(vecnorm(T.position_enu_m(k,1:2) - c.home_enu_m, 2, 2)), 0.1, 'vertical lift-off over home');
                tc.verifyGreaterThanOrEqual(T.altitude_agl_m(find(k, 1, 'last') + 1), c.takeoff_agl_m);
                tc.verifyTrue(all(diff(T.altitude_agl_m(k)) >= -1e-9), 'AGL never decreases during TAKEOFF');
                tc.verifyEqual(T.altitude_agl_m(T.phase == "PREFLIGHT"), zeros(nnz(T.phase == "PREFLIGHT"), 1), 'AbsTol', 1e-12);
            end
        end

        function t03_altitudeSetpointTracking(tc)
            c = tc.Cfg;
            tc.verifyLessThan(max(abs(tc.NomT.altitude_agl_m(tc.NomT.phase == "SURVEY") - c.alt_agl_setpoint_m)), 0.5, 'flat terrain');
            w = tc.WavyT.altitude_agl_m(tc.WavyT.phase == "SURVEY");
            tc.verifyLessThan(max(abs(w - c.alt_agl_setpoint_m)), 3.0, 'terrain following (look-ahead holds above the highest nearby ground)');
            tc.verifyGreaterThan(min(w), c.constraints.min_clearance_m);
            tc.verifyLessThan(abs(median(w) - c.alt_agl_setpoint_m), 1.0);
        end

        function t04_gridCoverage(tc)
            plan = tc.Nom.Plan; T = tc.NomT; xy = T.position_enu_m(:, 1:2);
            tc.verifyEqual(plan.n_lines, 6);
            for L = 1:plan.n_lines
                ab = plan.waypoints_xy(plan.line_id == L, :);
                q = ab(1,:) + linspace(0.1, 0.9, 41)' .* (ab(2,:) - ab(1,:));   % inner 80% of each line
                d = min(sqrt((q(:,1) - xy(:,1)').^2 + (q(:,2) - xy(:,2)').^2), [], 2);
                tc.verifyLessThan(max(d), 0.75, sprintf('survey line %d flown within 0.75 m', L));
            end
            sv = T.phase == "SURVEY"; P = tc.Cfg.survey_polygon_enu_m; hw = tc.Cfg.constraints.corridor_halfwidth_m;
            tc.verifyTrue(all(xy(sv,1) >= min(P(:,1)) - hw & xy(sv,1) <= max(P(:,1)) + hw & xy(sv,2) >= min(P(:,2)) - hw & xy(sv,2) <= max(P(:,2)) + hw));
        end

        function t05_continuityNoTeleport(tc)
            c = tc.Cfg; T = tc.NomT;
            tc.verifyEqual(diff(T.tick_id), ones(height(T) - 1, 1));
            step = vecnorm(diff(T.position_enu_m), 2, 2);
            tc.verifyLessThanOrEqual(max(step), hypot(c.constraints.max_speed_mps, c.constraints.max_climb_mps) * c.dt_s + 1e-9);
            dv = vecnorm(diff(T.velocity_enu_mps), 2, 2);
            tc.verifyLessThan(max(dv), 10 * c.dt_s, 'velocity continuous (< 10 m/s^2 equivalent jump)');
        end

        function t06_velocityAccelerationTiltBounds(tc)
            k = tc.Cfg.constraints; d = mgv2.engine.MissionEngine.KDrag;
            for Tc = {tc.NomT, tc.WavyT}
                T = Tc{1};
                tc.verifyLessThanOrEqual(max(vecnorm(T.velocity_enu_mps(:,1:2), 2, 2)), k.max_speed_mps + 1e-6);
                tc.verifyLessThanOrEqual(max(T.velocity_enu_mps(:,3)), k.max_climb_mps + 0.05);
                tc.verifyGreaterThanOrEqual(min(T.velocity_enu_mps(:,3)), -k.max_descent_mps - 0.05);
                % total = thrust acceleration (bounded) + drag on airspeed (no wind here)
                tc.verifyLessThanOrEqual(max(vecnorm(T.acceleration_enu_mps2(:,1:2), 2, 2)), k.max_accel_mps2 + d * k.max_speed_mps + 1e-6);
                tc.verifyLessThanOrEqual(rad2deg(max(hypot(T.pitch_up_rad, T.roll_right_down_rad))), k.max_tilt_deg + 0.5);
                tc.verifyTrue(all(abs(vecnorm(T.orientation_quat, 2, 2) - 1) < 1e-9), 'unit quaternions');
            end
        end

        function t07_headingAndAttitudeInTurns(tc)
            T = tc.NomT; sv = find(T.phase == "SURVEY"); k = tc.Cfg.constraints;
            yaw = unwrap(T.yaw_rad);
            tc.verifyLessThanOrEqual(max(abs(diff(yaw))) / tc.Cfg.dt_s, deg2rad(k.max_yaw_rate_dps) + 1e-9, 'heading rate limited');
            hd = T.heading_deg(sv);
            tc.verifyGreaterThan(nnz(abs(hd - 90) < 10), 100, 'flies eastbound lines (heading 90)');
            tc.verifyGreaterThan(nnz(abs(hd - 270) < 10), 100, 'flies westbound lines (heading 270)');
            tc.verifyGreaterThan(rad2deg(max(abs(T.roll_right_down_rad(sv)))), 5, 'banks in turns');
            % steady cruise: thrust must balance drag k_d*v -> nose-down pitch atan(k_d*v/g) (~8.7 deg at 6 m/s)
            v = vecnorm(T.velocity_enu_mps(:,1:2), 2, 2); a = vecnorm(T.acceleration_enu_mps2(:,1:2), 2, 2);
            cr = T.phase == "SURVEY" & abs(v - tc.Cfg.speed_mps) < 0.05 & a < 0.05;
            expect = -atan(mgv2.engine.MissionEngine.KDrag * tc.Cfg.speed_mps / mgv2.engine.MissionEngine.G);
            tc.verifyGreaterThan(nnz(cr), 200);
            tc.verifyLessThan(rad2deg(abs(median(T.pitch_up_rad(cr)) - expect)), 0.5, 'cruise pitch balances modelled drag');
            tc.verifyGreaterThan(rad2deg(max(T.pitch_up_rad(sv)) - min(T.pitch_up_rad(sv))), 5, 'pitch changes when braking/accelerating at line ends');
        end

        function t08_returnHomeAndLanding(tc)
            c = tc.Cfg; k = c.constraints;
            for e = {tc.Nom, tc.WavyEng}
                T = e{1}.poseLog();
                tc.verifyEqual(e{1}.Phase, "COMPLETE");
                tc.verifyLessThanOrEqual(norm(T.position_enu_m(end,1:2) - c.home_enu_m), k.arrive_tolerance_m);
                tc.verifyEqual(T.altitude_agl_m(end), 0, 'AbsTol', 1e-9);
                tc.verifyEqual(T.velocity_enu_mps(end,:), [0 0 0]);
                i = find(T.phase == "LANDING", 1);
                tc.verifyNotEmpty(i); tc.verifyEqual(find(T.phase == "COMPLETE", 1), find(T.phase == "LANDING", 1, 'last') + 1);
            end
            e = mgv2.engine.MissionEngine(c); e.run(2000);
            tc.verifyNotEqual(e.Phase, "COMPLETE", 'elapsed time alone never completes a mission');
        end

        function t09_determinism(tc)
            c = tc.Cfg; c.wind = struct('enabled', true, 'mean_enu_mps', [2 1 0], 'gust_sigma_mps', 0.8, 'gust_tau_s', 3);
            a = testV2002MissionEngine.runCfg(c, tc.Wavy); b = testV2002MissionEngine.runCfg(c, tc.Wavy);
            tc.verifyTrue(isequaln(a.poseLog(), b.poseLog()), 'same seed/config -> bit-identical pose log');
            c2 = c; c2.seed = c.seed + 1; d = testV2002MissionEngine.runCfg(c2, tc.Wavy);
            tc.verifyFalse(isequaln(a.poseLog().wind_enu_mps, d.poseLog().wind_enu_mps), 'different seed -> different gusts');
        end

        function t10_pauseResume(tc)
            e = mgv2.engine.MissionEngine(tc.Cfg); e.start();
            for i = 1:400, e.step(); end
            e.pause(); t = e.time(); n = height(e.poseLog());
            for i = 1:50, tc.verifyFalse(e.step()); end
            tc.verifyEqual(e.time(), t); tc.verifyEqual(height(e.poseLog()), n, 'paused: no ticks, no samples');
            e.resume(); while e.step(), end
            tc.verifyTrue(isequaln(e.poseLog(), tc.NomT), 'pause/resume continues the identical sequence');
        end

        function t11_reset(tc)
            e = mgv2.engine.MissionEngine(tc.Cfg); e.start(); for i = 1:700, e.step(); end
            e.reset();
            tc.verifyEqual(e.Phase, "CONFIGURED"); tc.verifyEqual(e.TickId, 0); tc.verifyEqual(height(e.poseLog()), 1);
            tc.verifyFalse(e.step(), 'not started after reset');
            e.run();
            tc.verifyTrue(isequaln(e.poseLog(), tc.NomT), 'reset restores the original seed and state');
        end

        function t12_invalidInputs(tc)
            id = 'mgv2:InvalidMissionConfig'; c = tc.Cfg;
            bad = {@(c) setf(c, 'dt_s', 0), @(c) setf(c, 'dt_s', 0.5), @(c) setf(c, 'seed', -1), ...
                @(c) setf(c, 'survey_polygon_enu_m', flipud(c.survey_polygon_enu_m)), ...                % clockwise
                @(c) setf(c, 'survey_polygon_enu_m', [0 0; 20 0; 5 5; 20 20; 0 20]), ...                % non-convex
                @(c) setf(c, 'targets', [1 2]), @(c) setf(c, 'truth', struct()), ...                     % truth firewall
                @(c) setf(c, 'speed_mps', 20), @(c) setf(c, 'home_enu_m', [500 0]), ...
                @(c) setf(c, 'alt_agl_setpoint_m', 3), @(c) setf(c, 'schema_version', "mg-contract/1.0"), ...
                @(c) setf(c, 'wind', struct('enabled', true, 'mean_enu_mps', [9 0 0], 'gust_sigma_mps', 0, 'gust_tau_s', 3)), ...
                @(c) rmfield(c, 'run_id')};
            for i = 1:numel(bad)
                tc.verifyError(@() mgv2.engine.MissionEngine(bad{i}(c)), id, sprintf('bad config %d', i));
            end
            tc.verifyError(@() mgv2.engine.MissionEngine(c, struct('id', "x")), 'mgv2:InvalidTerrain');
            tc.verifyError(@() mgv2.engine.MissionEngine(c, struct('id', "x", 'heightAt', @(x, y) 0)), 'mgv2:InvalidTerrain');
            function c = setf(c, f, v), c.(f) = v; end
        end

        function t13_terrainFaults(tc)
            c = tc.Cfg;
            e = testV2002MissionEngine.runCfg(c, struct('id', "ridge", 'heightAt', @(x, y) 25 * (x > 10)));
            tc.verifyEqual([e.Phase e.FaultCode], ["FAILED" "TERRAIN_COLLISION"]);
            e = testV2002MissionEngine.runCfg(c, struct('id', "slope", 'heightAt', @(x, y) max(0, 1.2 * x)));
            tc.verifyEqual([e.Phase e.FaultCode], ["FAILED" "CLEARANCE"]);
            c2 = c; c2.bounds_enu_m(3,2) = 12; e = testV2002MissionEngine.runCfg(c2);
            tc.verifyEqual([e.Phase e.FaultCode], ["FAILED" "PREFLIGHT_UNREACHABLE"]);
            T = e.poseLog(); tc.verifyFalse(any(T.phase == "TAKEOFF"), 'refused before take-off');
        end

        function t14_enuNedRoundTrip(tc)
            tc.verifyEqual(mgv2.frames.enuToNed([1 2 3]), [2 1 -3]);
            s = RandStream('mt19937ar', 'Seed', 14); P = 1e3 * (rand(s, 500, 3) - 0.5) .* [1 3 7];
            tc.verifyLessThanOrEqual(max(abs(mgv2.frames.nedToEnu(mgv2.frames.enuToNed(P)) - P), [], 'all'), 1e-12);
            for i = 1:200
                q = mgv2.frames.quatFromYawPitchRoll(2*pi*rand(s) - pi, pi*(rand(s) - 0.5) * 0.9, 2*pi*rand(s) - pi);
                [pn, qn] = mgv2.frames.poseEnuToNed(P(i,:), q); [pe, qe] = mgv2.frames.poseNedToEnu(pn, qn);
                tc.verifyLessThanOrEqual(norm(pe - P(i,:)), 1e-8);
                tc.verifyLessThanOrEqual(norm(mgv2.frames.quatToRotm(qe) - mgv2.frames.quatToRotm(q)), 1e-12);
            end
            % facing East in ENU (yaw 0) == heading 90 deg in NED/FRD; body forward maps to world East
            [~, qn] = mgv2.frames.poseEnuToNed([0 0 0], [1 0 0 0]);
            tc.verifyEqual(mgv2.frames.quatToRotm(qn) * [1 0 0]', [0 1 0]', 'AbsTol', 1e-12);
            tc.verifyEqual(mgv2.frames.headingDegFromYaw(0), 90); tc.verifyEqual(mgv2.frames.headingDegFromYaw(pi/2), 0);
            if ~isempty(which('eul2quat'))   % independent cross-check with the shared MathWorks rotation library
                [~, qn] = mgv2.frames.poseEnuToNed([0 0 0], mgv2.frames.quatFromYawPitchRoll(deg2rad(30), 0, 0));
                qr = eul2quat([deg2rad(60) 0 0], 'ZYX');   % ENU yaw 30 deg == NED yaw 60 deg
                tc.verifyLessThan(min(norm(qn - qr), norm(qn + qr)), 1e-12);
            end
        end

        function t15_windDisturbanceAndRecovery(tc)
            c = tc.Cfg; c.wind = struct('enabled', true, 'mean_enu_mps', [2.5 1 0], 'gust_sigma_mps', 0.8, 'gust_tau_s', 3);
            e = testV2002MissionEngine.runCfg(c); T = e.poseLog(); sv = T.phase == "SURVEY";
            tc.verifyEqual(e.Phase, "COMPLETE", 'completes under the configured wind');
            err = vecnorm(T.position_enu_m(sv,1:2) - T.commanded_position_enu_m(sv,1:2), 2, 2);
            nerr = vecnorm(tc.NomT.position_enu_m(tc.NomT.phase == "SURVEY",1:2) - tc.NomT.commanded_position_enu_m(tc.NomT.phase == "SURVEY",1:2), 2, 2);
            tc.verifyGreaterThan(max(err), max(nerr) + 0.5, 'wind visibly increases commanded-vs-actual error');
            tc.verifyLessThan(max(err), 6, 'tracking error stays bounded (recovers, no divergence)');
            tc.verifyGreaterThan(std(T.wind_enu_mps(:,1)), 0.2, 'gusts are present');
            tc.verifyLessThanOrEqual(norm(T.position_enu_m(end,1:2) - c.home_enu_m), c.constraints.arrive_tolerance_m);
        end

        function t16_clockConsistency(tc)
            T = tc.NomT; dt = tc.Cfg.dt_s;
            tc.verifyEqual(T.t_s, T.tick_id * dt, 'AbsTol', 0, 't_s is exactly tick_id * dt');
            tc.verifyEqual(T.pose_id, T.tick_id);
            src = [fileread(which('mgv2.engine.MissionEngine')), fileread(which('mgv2.mission.planSurvey')), fileread(which('mgv2.mission.buildRoute'))];
            code = regexprep(src, '%[^\n]*', '');
            tc.verifyEmpty(regexp(code, '\<(tic|toc|clock|now|datetime|cputime|posixtime|timer)\>', 'once'), 'engine never reads the wall clock');
        end

        function t17_geofence(tc)
            c = tc.Cfg; c.bounds_enu_m(1,2) = 41;     % turns overshoot the polygon edge by ~2 m
            e = testV2002MissionEngine.runCfg(c);
            tc.verifyEqual([e.Phase e.FaultCode], ["FAILED" "GEOFENCE"]);
        end

        function t18_timeoutAndAbort(tc)
            c = tc.Cfg; c.constraints.timeout_s = 125; e = testV2002MissionEngine.runCfg(c);
            tc.verifyEqual([e.Phase e.FaultCode], ["FAILED" "TIMEOUT"]); tc.verifyLessThanOrEqual(e.time(), 125 + c.dt_s + 1e-9);
            c.constraints.timeout_s = 90; e = testV2002MissionEngine.runCfg(c);
            tc.verifyEqual([e.Phase e.FaultCode], ["FAILED" "PREFLIGHT_UNREACHABLE"]);
            e = mgv2.engine.MissionEngine(tc.Cfg); e.start(); for i = 1:900, e.step(); end
            p = e.snapshot().position_enu_m; e.abort("test");
            tc.verifyEqual([e.Phase e.FaultCode], ["ABORTED" "ABORTED_BY_OPERATOR"]);
            tc.verifyFalse(e.step()); tc.verifyEqual(e.snapshot().position_enu_m, p);
        end

        function t19_subscribersSeeEveryTick(tc)
            e = mgv2.engine.MissionEngine(tc.Cfg); got = zeros(0, 2);
            e.subscribe(@(s) numel(s));   % a second, read-only subscriber
            e.subscribe(@record); e.run();
            T = e.poseLog();
            tc.verifyEqual(got(:,1), T.tick_id(2:end)); tc.verifyEqual(got(:,2), T.t_s(2:end));
            function record(s), got(end+1, :) = [s.tick_id s.t_s]; end
        end

        function t20_fieldSizesAndWaypointCounts(tc)
            c0 = tc.Cfg;
            cases = {struct('poly', [-10 -10; 10 -10; 10 10; -10 10], 'sp', 5, 'hd', 90, 'n', 4), ...
                struct('poly', [-60 -60; 60 -60; 60 60; -60 60], 'sp', 15, 'hd', 0, 'n', 8), ...
                struct('poly', [-30 -20; 30 -20; 30 20; -30 20], 'sp', 8, 'hd', 30, 'n', NaN), ...
                struct('poly', [0 -30; 30 -10; 20 25; -20 25; -30 -10], 'sp', 10, 'hd', 120, 'n', NaN)};
            for i = 1:numel(cases)
                k = cases{i}; c = c0; c.survey_polygon_enu_m = k.poly; c.line_spacing_m = k.sp; c.survey_heading_deg = k.hd;
                c.bounds_enu_m = [-80 80; -80 80; -10 120]; c.home_enu_m = [-70 -70]; c.constraints.timeout_s = 2000;
                e = testV2002MissionEngine.runCfg(c);
                tc.verifyEqual(e.Phase, "COMPLETE", sprintf('case %d', i));
                if ~isnan(k.n), tc.verifyEqual(e.Plan.n_lines, k.n, sprintf('case %d line count', i)); end
                tc.verifyEqual(size(e.Plan.waypoints_xy, 1), 2 * e.Plan.n_lines);
            end
        end

        function t21_poseSampleContract(tc)
            s = tc.Nom.snapshot();
            need = ["schema_version","run_id","scenario_id","seed","pose_id","tick_id","t_s","position_enu_m","velocity_enu_mps", ...
                "acceleration_enu_mps2","orientation_quat","angular_velocity_body_rps","yaw_rad","heading_deg","altitude_agl_m", ...
                "terrain_height_m","phase","validity","fault_code","simulated"];
            tc.verifyEmpty(setdiff(need, string(fieldnames(s))'));
            tc.verifyEqual(s.schema_version, "mg-v2-contract/1.0"); tc.verifyTrue(s.simulated);
            tc.verifyEqual(size(s.position_enu_m), [1 3]); tc.verifyEqual(size(s.orientation_quat), [1 4]);
            tc.verifyEqual(s.altitude_agl_m, s.position_enu_m(3) - s.terrain_height_m, 'AbsTol', 1e-12);
        end

        function t22_truthFirewall(tc)
            src = "";
            for f = ["mgv2.engine.MissionEngine","mgv2.mission.planSurvey","mgv2.mission.buildRoute"]   % validateConfig names them only to reject them
                src = src + string(fileread(which(f)));
            end
            body = regexprep(src, '%[^\n]*', '');   % code only, comments excluded
            tc.verifyEmpty(regexp(body, '\<(target|truth|label|landmine|mine_)\w*', 'once'), 'no truth/target identifiers in engine code');
        end
    end
end
