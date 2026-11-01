classdef MissionEngine < handle
    %MISSIONENGINE Deterministic fixed-step live UAV mission engine (V2-002). SIMULATION ONLY.
    %   eng = mgv2.engine.MissionEngine(cfg)            flat terrain at z = 0
    %   eng = mgv2.engine.MissionEngine(cfg, terrain)   terrain provider (see mgv2.engine.flatTerrain)
    %   eng.start(); while eng.step(), end              or  eng.run()
    %   s = eng.snapshot();  T = eng.poseLog();
    %
    %   Clock: one authoritative SimulationClock, t_s = tick_id * dt_s (ADR-03). Nothing here reads the
    %   wall clock; the caller decides how fast to call step(). pause() freezes time (step returns false
    %   and nothing is logged); resume() continues the same sequence; reset() returns to CONFIGURED
    %   with the original seed.
    %
    %   Phases: CONFIGURED -> PREFLIGHT -> TAKEOFF -> CLIMB -> TRANSIT -> SURVEY -> RETURN_HOME ->
    %           LANDING -> COMPLETE, plus the terminal faults ABORTED and FAILED (fault_code says why).
    %   COMPLETE is entered only on touchdown at home (AGL <= landing tolerance, low sink rate).
    %
    %   Vehicle model (documented approximation, NOT a certified flight controller):
    %   - translational point mass; commanded acceleration a_cmd from a cascaded position/velocity
    %     controller, bounded by the horizontal-acceleration, tilt and vertical-acceleration limits;
    %   - achieved acceleration follows a_cmd through a first-order lag (tau_a = 0.15 s), standing in
    %     for attitude and thrust response;
    %   - linear aerodynamic drag on airspeed, a_drag = -k_d (v - w), with optional wind w (seeded
    %     mean + first-order Gauss-Markov gust), so commanded and actual paths differ under wind;
    %   - attitude from differential flatness: body z axis along (a_thrust + g e_up), yaw rate-limited
    %     toward the path direction (Mellinger & Kumar 2011; Mahony, Kumar & Corke 2012);
    %   - horizontal guidance: L1-style carrot on one continuous path (Park, Deyst & How 2004) with a
    %     corner and braking speed profile, and terrain-following height at the AGL setpoint.

    properties (Constant)
        G = 9.80665          % m/s^2
        TauA = 0.15          % s, achieved-acceleration lag (attitude/thrust response)
        KDrag = 0.25         % 1/s, linear drag coefficient on airspeed (small multirotor, assumed)
        KpPos = 0.9          % 1/s, position -> velocity gain
        KvVel = 2.2          % 1/s, velocity -> acceleration gain
        KpZ = 1.0            % 1/s, height -> vertical speed gain
        Phases = ["CONFIGURED","PREFLIGHT","TAKEOFF","CLIMB","TRANSIT","SURVEY","RETURN_HOME","LANDING","COMPLETE","ABORTED","FAILED"]
    end

    properties (SetAccess = private)
        Config            % validated MissionConfig
        Terrain           % terrain provider struct (id, heightAt)
        Plan              % survey plan (planSurvey)
        Route             % horizontal path (buildRoute)
        TickId = 0        % integer tick index
        Phase = "CONFIGURED"
        FaultCode = ""    % "" | PREFLIGHT_* | CLEARANCE | TERRAIN_COLLISION | GEOFENCE | TIMEOUT | ABORTED_BY_OPERATOR
        FaultMessage = ""
        Paused = false
        HomeZ             % terrain height at home
        PhaseLog          % table: tick_id, t_s, phase
    end
    properties (Access = private)
        P; V; A; Q; Acc; Omega; Yaw; Rprev
        Wind; GustState; Rng
        PathS = 0          % progress along the route (m), monotone
        PreflightTicks
        Log; NLog = 0
        Subscribers = {}
        Cmd = struct('p', [NaN NaN NaN], 'v', [NaN NaN NaN])
    end

    methods
        function eng = MissionEngine(cfg, terrain)
            if nargin < 2, terrain = mgv2.engine.flatTerrain(); end
            eng.Config = mgv2.mission.validateConfig(cfg);
            eng.Terrain = mgv2.engine.MissionEngine.checkTerrain(terrain);
            eng.Plan = mgv2.mission.planSurvey(eng.Config);
            eng.Route = mgv2.mission.buildRoute(eng.Config, eng.Plan);
            eng.reset();
        end

        function t = time(eng)
            %TIME Simulation time in seconds (tick_id * dt_s).
            t = eng.TickId * eng.Config.dt_s;
        end

        function start(eng)
            %START Leave CONFIGURED and begin PREFLIGHT. No-op in any other phase.
            if eng.Phase ~= "CONFIGURED", return; end
            eng.setPhase("PREFLIGHT");
        end

        function pause(eng), eng.Paused = true; end
        function resume(eng), eng.Paused = false; end

        function abort(eng, reason)
            %ABORT Operator abort: terminal ABORTED state; the simulated vehicle state is frozen.
            if nargin < 2, reason = "operator abort"; end
            if ismember(eng.Phase, ["COMPLETE","ABORTED","FAILED"]), return; end
            eng.FaultCode = "ABORTED_BY_OPERATOR"; eng.FaultMessage = string(reason);
            eng.setPhase("ABORTED"); eng.record();
        end

        function reset(eng)
            %RESET Back to CONFIGURED at tick 0 with the original seed; the log is cleared.
            c = eng.Config;
            eng.HomeZ = eng.Terrain.heightAt(c.home_enu_m(1), c.home_enu_m(2));
            eng.P = [c.home_enu_m eng.HomeZ]; eng.V = [0 0 0]; eng.A = [0 0 0]; eng.Acc = [0 0 0]; eng.Omega = [0 0 0];
            d0 = eng.Route.xy(2,:) - eng.Route.xy(1,:);
            eng.Yaw = atan2(d0(2), d0(1));
            R0 = mgv2.frames.quatToRotm(mgv2.frames.quatFromYawPitchRoll(eng.Yaw, 0, 0));
            eng.Q = mgv2.frames.rotmToQuat(R0); eng.Rprev = R0;
            eng.Rng = RandStream('mt19937ar', 'Seed', c.seed);
            eng.GustState = [0 0 0];
            if c.wind.enabled, eng.Wind = c.wind.mean_enu_mps; else, eng.Wind = [0 0 0]; end
            eng.PathS = 0; eng.TickId = 0; eng.Paused = false;
            eng.FaultCode = ""; eng.FaultMessage = "";
            eng.PreflightTicks = round(c.preflight_s / c.dt_s);
            eng.Phase = "CONFIGURED";
            eng.PhaseLog = table(0, 0, "CONFIGURED", 'VariableNames', {'tick_id','t_s','phase'});
            cap = ceil(c.constraints.timeout_s / c.dt_s) + 2;
            eng.Log = nan(cap, 31); eng.NLog = 0; eng.Cmd = struct('p', [NaN NaN NaN], 'v', [NaN NaN NaN]);
            eng.record();
        end

        function subscribe(eng, fcn)
            %SUBSCRIBE Register fcn(snapshot) to be called after every executed tick (read-only use).
            arguments
                eng
                fcn (1,1) function_handle
            end
            eng.Subscribers{end+1} = fcn;
        end

        function tf = isTerminal(eng)
            tf = ismember(eng.Phase, ["COMPLETE","ABORTED","FAILED"]);
        end

        function advanced = step(eng)
            %STEP Advance exactly one tick. Returns false (and changes nothing) when paused, not
            %   started, or terminal.
            advanced = false;
            if eng.Paused || eng.Phase == "CONFIGURED" || eng.isTerminal(), return; end
            c = eng.Config; dt = c.dt_s;
            eng.TickId = eng.TickId + 1; advanced = true;
            switch eng.Phase
                case "PREFLIGHT"
                    if eng.TickId == 1, eng.preflightChecks(); end
                    if ~eng.isTerminal() && eng.TickId >= eng.PreflightTicks, eng.setPhase("TAKEOFF"); end
                    eng.groundHold();
                case {"TAKEOFF","CLIMB","LANDING"}
                    eng.verticalStep(dt);
                otherwise   % TRANSIT, SURVEY, RETURN_HOME
                    eng.horizontalStep(dt);
            end
            if ~eng.isTerminal() && eng.time() > c.constraints.timeout_s
                eng.fail("TIMEOUT", sprintf('Mission not complete after %.1f s.', c.constraints.timeout_s));
            end
            eng.record();
            if ~isempty(eng.Subscribers)
                s = eng.snapshot();
                for k = 1:numel(eng.Subscribers), eng.Subscribers{k}(s); end
            end
        end

        function n = run(eng, maxTicks)
            %RUN Start if needed and step until terminal (or maxTicks). Returns ticks executed.
            if nargin < 2, maxTicks = inf; end
            eng.start(); n = 0;
            while n < maxTicks && eng.step(), n = n + 1; end
        end

        function s = snapshot(eng)
            %SNAPSHOT Current PoseSample (mg-v2-contract/1.0 subset), an immutable value struct.
            s = mgv2.engine.MissionEngine.rowToSample(eng.Log(eng.NLog, :), eng.Config, eng.Phase, eng.FaultCode);
        end

        function T = poseLog(eng)
            %POSELOG All recorded PoseSamples as a table (one row per executed tick plus tick 0).
            L = eng.Log(1:eng.NLog, :);
            ph = mgv2.engine.MissionEngine.Phases(L(:,31))';
            T = table(L(:,1), L(:,2), L(:,3:5), L(:,6:8), L(:,9:11), L(:,12:15), L(:,16:18), L(:,19), ...
                L(:,20), L(:,21), L(:,22), L(:,23), L(:,24), L(:,25:27), L(:,28:30), ph, ...
                'VariableNames', {'tick_id','t_s','position_enu_m','velocity_enu_mps','acceleration_enu_mps2', ...
                'orientation_quat','angular_velocity_body_rps','yaw_rad','heading_deg','pitch_up_rad','roll_right_down_rad', ...
                'altitude_agl_m','terrain_height_m','commanded_position_enu_m','wind_enu_mps','phase'});
            T.pose_id = T.tick_id;
            T.validity = true(height(T), 1);
        end
    end

    methods (Access = private)
        function setPhase(eng, p)
            eng.Phase = p;
            eng.PhaseLog(end+1, :) = {eng.TickId, eng.time(), p};
        end

        function fail(eng, code, msg)
            eng.FaultCode = string(code); eng.FaultMessage = string(msg);
            eng.setPhase("FAILED");
        end

        function preflightChecks(eng)
            c = eng.Config; k = c.constraints; xy = eng.Route.xy;
            hz = eng.Terrain.heightAt(c.home_enu_m(1), c.home_enu_m(2));
            if ~isfinite(hz), eng.fail("PREFLIGHT_TERRAIN", "Terrain height at home is not finite."); return; end
            % sample the planned path densely: terrain finite, required height inside the geofence
            sq = linspace(0, eng.Route.length_m, max(2, ceil(eng.Route.length_m / 1)))';
            pq = [interp1(eng.Route.s, xy(:,1), sq), interp1(eng.Route.s, xy(:,2), sq)];
            th = eng.Terrain.heightAt(pq(:,1), pq(:,2));
            if any(~isfinite(th)), eng.fail("PREFLIGHT_TERRAIN", "Terrain undefined along the planned path."); return; end
            if any(th + c.alt_agl_setpoint_m > c.bounds_enu_m(3,2))
                eng.fail("PREFLIGHT_UNREACHABLE", "Required survey height exceeds the geofence ceiling."); return;
            end
            % lower bound on mission time (no acceleration, wind or turns): only a provably impossible
            % mission is refused here; an actual overrun is caught at run time as TIMEOUT
            lb = eng.Route.length_m / c.speed_mps + c.alt_agl_setpoint_m / k.max_climb_mps ...
                + c.alt_agl_setpoint_m / k.max_descent_mps + c.preflight_s;
            if lb > k.timeout_s
                eng.fail("PREFLIGHT_UNREACHABLE", sprintf('Minimum mission time %.0f s exceeds the %.0f s timeout.', lb, k.timeout_s));
            end
        end

        function groundHold(eng)
            eng.V = [0 0 0]; eng.A = [0 0 0]; eng.Acc = [0 0 0];
            eng.P(3) = eng.Terrain.heightAt(eng.P(1), eng.P(2));
            eng.Cmd = struct('p', eng.P, 'v', [0 0 0]);
            eng.attitude(eng.Config.dt_s);
        end

        function verticalStep(eng, dt)
            c = eng.Config; k = c.constraints;
            hxy = c.home_enu_m; hz = eng.Terrain.heightAt(eng.P(1), eng.P(2));
            agl = eng.P(3) - hz;
            switch eng.Phase
                case "TAKEOFF", goalAgl = c.takeoff_agl_m;
                case "CLIMB",   goalAgl = c.alt_agl_setpoint_m;
                otherwise,      goalAgl = 0;
            end
            if eng.Phase == "LANDING"
                vz = -max(k.touchdown_speed_mps * 0.7, min(k.max_descent_mps, 0.5 * agl));   % slow near ground
            else
                vz = max(-k.max_descent_mps, min(k.max_climb_mps, eng.KpZ * (goalAgl - agl) + 0.4));
                if eng.Phase == "TAKEOFF", vz = min(vz, 1.0); end                             % gentle lift-off
            end
            vref = [eng.KpPos * (hxy - eng.P(1:2)), vz];
            eng.Cmd = struct('p', [hxy hz + goalAgl], 'v', vref);
            eng.integrate(dt, vref, [0 0 0]);
            agl = eng.P(3) - eng.Terrain.heightAt(eng.P(1), eng.P(2));
            switch eng.Phase
                case "TAKEOFF"
                    if agl >= c.takeoff_agl_m, eng.setPhase("CLIMB"); end
                case "CLIMB"
                    if agl >= c.alt_agl_setpoint_m - 0.25, eng.setPhase("TRANSIT"); end
                case "LANDING"
                    if agl <= k.landing_tolerance_m && abs(eng.V(3)) <= k.touchdown_speed_mps ...
                            && norm(eng.P(1:2) - hxy) <= k.arrive_tolerance_m
                        eng.P(3) = eng.Terrain.heightAt(eng.P(1), eng.P(2)); eng.V = [0 0 0]; eng.A = [0 0 0]; eng.Acc = [0 0 0]; eng.Omega = [0 0 0];
                        eng.setPhase("COMPLETE");
                    end
            end
            eng.safetyChecks();
        end

        function horizontalStep(eng, dt)
            c = eng.Config; k = c.constraints; r = eng.Route;
            L = max(3, 1.0 * c.speed_mps);                       % carrot look-ahead distance (m)
            % monotone progress: project onto the path within a forward window
            sp = eng.projectProgress(eng.P(1:2), eng.PathS, 3 * L);
            eng.PathS = max(eng.PathS, sp);
            sC = min(r.length_m, eng.PathS + L);
            carrot = eng.pointAt(sC); ref = eng.pointAt(eng.PathS);
            % speed profile: cruise, slowed for the next corner and for the final arrival
            vmax = c.speed_mps; aB = 0.6 * k.max_accel_mps2;
            [dV, vC] = eng.nextCorner(eng.PathS, L);
            vmax = min(vmax, sqrt(vC^2 + 2 * aB * dV));
            dEnd = r.length_m - eng.PathS;
            vmax = min(vmax, sqrt(2 * aB * max(dEnd - 0.2, 0)));
            dirv = carrot - eng.P(1:2); nd = norm(dirv);
            if nd > 1e-6, vh = vmax * dirv / nd; else, vh = [0 0]; end
            % terrain-following height: highest ground near the current point, carrot and 2 s ahead
            ahead = eng.P(1:2) + 2 * eng.V(1:2);
            gq = [eng.P(1:2); carrot; ahead; (eng.P(1:2) + carrot) / 2];
            zt = max(eng.Terrain.heightAt(gq(:,1), gq(:,2))) + c.alt_agl_setpoint_m;
            vz = max(-k.max_descent_mps, min(k.max_climb_mps, eng.KpZ * (zt - eng.P(3))));
            vref = [vh, vz];
            eng.Cmd = struct('p', [ref zt], 'v', vref);
            eng.integrate(dt, vref, [0 0 0]);
            % phase from the segment being flown; arrival at home -> LANDING
            seg = find(r.s <= eng.PathS, 1, 'last'); seg = min(max(seg, 1), numel(r.seg_phase));
            ph = r.seg_phase(seg);
            if ph ~= eng.Phase, eng.setPhase(ph); end
            if dEnd < 0.5 && norm(eng.P(1:2) - c.home_enu_m) <= k.arrive_tolerance_m && norm(eng.V(1:2)) < 0.5
                eng.setPhase("LANDING");
            end
            eng.safetyChecks();
        end

        function integrate(eng, dt, vref, aff)
            c = eng.Config; k = c.constraints;
            aCmd = eng.KvVel * (vref - eng.V) + aff + eng.KDrag * vref;     % drag feed-forward (still air)
            % bound: vertical accel, then horizontal by accel limit and achievable tilt
            aCmd(3) = max(-k.max_vert_accel_mps2, min(k.max_vert_accel_mps2, aCmd(3)));
            ah = aCmd(1:2); amax = min(k.max_accel_mps2, (eng.G + aCmd(3)) * tand(k.max_tilt_deg));
            if norm(ah) > amax, ah = ah * amax / norm(ah); end
            aCmd(1:2) = ah;
            eng.A = eng.A + (aCmd - eng.A) * min(1, dt / eng.TauA);         % achieved thrust acceleration
            eng.Wind = eng.windAt();
            aTot = eng.A - eng.KDrag * (eng.V - eng.Wind);
            eng.V = eng.V + aTot * dt;                                       % semi-implicit Euler
            eng.P = eng.P + eng.V * dt;
            eng.Acc = aTot;                                                  % logged total acceleration
            % yaw toward the horizontal velocity reference, rate-limited
            if norm(vref(1:2)) > 0.5
                yc = atan2(vref(2), vref(1)); dy = atan2(sin(yc - eng.Yaw), cos(yc - eng.Yaw));
                lim = deg2rad(k.max_yaw_rate_dps) * dt;
                eng.Yaw = eng.Yaw + max(-lim, min(lim, dy));
            end
            eng.attitude(dt);
        end

        function attitude(eng, dt)
            % Differential flatness: body z along specific thrust (achieved accel + gravity), heading = Yaw.
            zb = eng.A + [0 0 eng.G]; zb = zb / norm(zb);
            yc = [-sin(eng.Yaw) cos(eng.Yaw) 0];             % Mellinger & Kumar: x_b = y_c x z_b keeps ZYX yaw == Yaw
            xb = cross(yc, zb); xb = xb / norm(xb); yb = cross(zb, xb);
            R = [xb' yb' zb'];
            dR = eng.Rprev' * R; ang = acos(max(-1, min(1, (trace(dR) - 1) / 2)));
            if ang < 1e-9, om = [0 0 0];
            else, om = ang / (2 * sin(ang)) * [dR(3,2)-dR(2,3), dR(1,3)-dR(3,1), dR(2,1)-dR(1,2)] / dt;
            end
            eng.Rprev = R; eng.Q = mgv2.frames.rotmToQuat(R); eng.Omega = om;
        end

        function w = windAt(eng)
            c = eng.Config.wind;
            if ~c.enabled, w = [0 0 0]; return; end
            dt = eng.Config.dt_s; phi = exp(-dt / c.gust_tau_s);
            eng.GustState(1:3) = phi * eng.GustState(1:3) + c.gust_sigma_mps * sqrt(1 - phi^2) * randn(eng.Rng, 1, 3) .* [1 1 0.3];
            w = c.mean_enu_mps + eng.GustState(1:3);
        end

        function safetyChecks(eng)
            if eng.isTerminal(), return; end
            c = eng.Config; k = c.constraints; b = c.bounds_enu_m;
            hz = eng.Terrain.heightAt(eng.P(1), eng.P(2)); agl = eng.P(3) - hz;
            if agl < -0.02
                eng.P(3) = hz; eng.V = [0 0 0];
                eng.fail("TERRAIN_COLLISION", sprintf('Ground contact at (%.1f, %.1f) during %s.', eng.P(1), eng.P(2), eng.Phase)); return;
            end
            if ismember(eng.Phase, ["TRANSIT","SURVEY","RETURN_HOME"]) && agl < k.min_clearance_m
                eng.fail("CLEARANCE", sprintf('AGL %.2f m below the %.2f m minimum during %s.', agl, k.min_clearance_m, eng.Phase)); return;
            end
            if any(eng.P(1:2) < b(1:2,1)' | eng.P(1:2) > b(1:2,2)') || eng.P(3) > b(3,2) || eng.P(3) < b(3,1)
                eng.fail("GEOFENCE", sprintf('Position (%.1f, %.1f, %.1f) outside the geofence.', eng.P)); return;
            end
            if ismember(eng.Phase, ["TRANSIT","SURVEY","RETURN_HOME"]) && ~eng.inOperationalArea(eng.P(1:2))
                eng.fail("GEOFENCE", sprintf('Position (%.1f, %.1f) outside the survey area and home corridors.', eng.P(1:2)));
            end
        end

        function tf = inOperationalArea(eng, xy)
            c = eng.Config; hw = c.constraints.corridor_halfwidth_m;
            if mgv2.engine.MissionEngine.distToPolygon(c.survey_polygon_enu_m, xy) <= hw, tf = true; return; end
            cs = eng.Route.corridor_segments;
            for i = 1:size(cs, 1)
                if mgv2.engine.MissionEngine.distToSegment(xy, cs(i,1:2), cs(i,3:4)) <= hw, tf = true; return; end
            end
            d = norm(xy - c.home_enu_m); tf = d <= hw;
        end

        function sp = projectProgress(eng, xy, s0, win)
            r = eng.Route; best = inf; sp = s0;
            i0 = find(r.s <= s0, 1, 'last'); i1 = find(r.s >= s0 + win, 1, 'first');
            if isempty(i1), i1 = numel(r.s); end
            for i = i0:min(i1, numel(r.s) - 1)
                a = r.xy(i,:); b = r.xy(i+1,:); ab = b - a; L2 = ab * ab';
                t = max(0, min(1, ((xy - a) * ab') / L2));
                sCand = r.s(i) + t * sqrt(L2);
                if sCand < s0 || sCand > s0 + win, continue; end
                d = norm(a + t * ab - xy);
                if d < best, best = d; sp = sCand; end
            end
        end

        function p = pointAt(eng, s)
            r = eng.Route; s = max(0, min(r.length_m, s));
            p = [interp1(r.s, r.xy(:,1), s), interp1(r.s, r.xy(:,2), s)];
        end

        function [dist, vC] = nextCorner(eng, s, L)
            % distance to the next vertex with a significant turn, and the allowed speed through it
            r = eng.Route; c = eng.Config; dist = inf; vC = c.speed_mps;
            idx = find(r.s > s + 1e-9);
            for i = idx'
                if i >= numel(r.s), break; end
                u = r.xy(i,:) - r.xy(i-1,:); w = r.xy(i+1,:) - r.xy(i,:);
                th = acos(max(-1, min(1, (u * w') / (norm(u) * norm(w)))));
                if th > deg2rad(20)
                    dist = r.s(i) - s;
                    vC = min(c.speed_mps, sqrt(0.6 * c.constraints.max_accel_mps2 * L));   % lateral accel on a ~L radius
                    return;
                end
            end
        end

        function record(eng)
            [yaw, pitch, roll] = mgv2.frames.yawPitchRollFromQuat(eng.Q);
            hz = eng.Terrain.heightAt(eng.P(1), eng.P(2));
            row = [eng.TickId, eng.time(), eng.P, eng.V, eng.Acc, eng.Q, eng.Omega, yaw, ...
                mgv2.frames.headingDegFromYaw(yaw), -pitch, roll, eng.P(3) - hz, hz, eng.Cmd.p, eng.Wind, ...
                find(eng.Phases == eng.Phase)];
            eng.NLog = eng.NLog + 1;
            if eng.NLog > size(eng.Log, 1), eng.Log(end + 1000, :) = NaN; end
            eng.Log(eng.NLog, :) = row;
        end
    end

    methods (Static)
        function terrain = checkTerrain(terrain)
            id = 'mgv2:InvalidTerrain';
            if ~isstruct(terrain) || ~all(isfield(terrain, {'id','heightAt'})) || ~isa(terrain.heightAt, 'function_handle')
                error(id, 'Terrain provider must be a struct with fields id and heightAt (function handle).');
            end
            z = terrain.heightAt([0 1; 2 3], [0 0; 1 1]);
            if ~isequal(size(z), [2 2]) || ~isnumeric(z)
                error(id, 'terrain.heightAt must be vectorised and return the input size.');
            end
            terrain.id = string(terrain.id);
        end

        function s = rowToSample(row, cfg, phase, fault)
            s = struct('schema_version', "mg-v2-contract/1.0", 'record_type', "PoseSample", ...
                'run_id', cfg.run_id, 'scenario_id', cfg.scenario_id, 'seed', cfg.seed, ...
                'pose_id', row(1), 'tick_id', row(1), 't_s', row(2), ...
                'position_enu_m', row(3:5), 'velocity_enu_mps', row(6:8), 'acceleration_enu_mps2', row(9:11), ...
                'orientation_quat', row(12:15), 'quat_convention', "wxyz, body FLU -> world ENU", ...
                'angular_velocity_body_rps', row(16:18), 'yaw_rad', row(19), 'heading_deg', row(20), ...
                'pitch_up_rad', row(21), 'roll_right_down_rad', row(22), ...
                'altitude_agl_m', row(23), 'terrain_height_m', row(24), ...
                'commanded_position_enu_m', row(25:27), 'wind_enu_mps', row(28:30), ...
                'phase', string(phase), 'validity', true, 'fault_code', string(fault), 'simulated', true);
        end

        function d = distToSegment(p, a, b)
            ab = b - a; L2 = ab * ab';
            if L2 == 0, d = norm(p - a); return; end
            t = max(0, min(1, ((p - a) * ab') / L2)); d = norm(a + t * ab - p);
        end

        function d = distToPolygon(P, p)
            % 0 inside the convex CCW polygon, otherwise distance to the boundary
            n = size(P, 1); inside = true; d = inf;
            for i = 1:n
                a = P(i,:); b = P(mod(i, n)+1, :);
                if (b(1)-a(1))*(p(2)-a(2)) - (b(2)-a(2))*(p(1)-a(1)) < 0, inside = false; end
                d = min(d, mgv2.engine.MissionEngine.distToSegment(p, a, b));
            end
            if inside, d = 0; end
        end
    end
end
