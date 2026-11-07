classdef PlaybackEngine < handle
    %PLAYBACKENGINE Replays the recorded poses of a verified run package on the same tick clock (V2-008). SIMULATION ONLY.
    %   eng = mgv2.replay.PlaybackEngine(pkg)        pkg from mgv2.run.verifyPackage
    %   Offers the members of mgv2.engine.MissionEngine that the session and dashboard use: start, pause, resume, abort,
    %   step, time, isTerminal, snapshot, subscribe, poseLog, and Config, Route, TickId, Phase, Paused, FaultCode,
    %   FaultMessage, PhaseLog. Nothing is simulated or re-seeded: step() emits the next recorded PoseSample exactly as
    %   recorded. The recorded end (COMPLETE, FAILED with its fault, or ABORTED) is restored after the last tick.
    %   ABORT during a replay stops the replay only; the recording is not changed.

    properties (SetAccess = private)
        Config; Route; Plan
        TickId = 0
        Phase = "CONFIGURED"
        FaultCode = ""
        FaultMessage = ""
        Paused = false
        PhaseLog
        LastTick          % final recorded tick
    end
    properties (Access = private)
        Poses             % recorded poseLog table, one row per tick (a trailing ABORTED duplicate removed)
        EndState          % manifest.end_state
        Subscribers = {}
    end

    methods
        function eng = PlaybackEngine(pkg)
            eng.Config = mgv2.mission.validateConfig(pkg.config.mission);
            eng.Plan = mgv2.mission.planSurvey(eng.Config); eng.Route = mgv2.mission.buildRoute(eng.Config, eng.Plan);
            P = pkg.poses; n = height(P);
            if n > 1 && P.tick_id(n) == P.tick_id(n - 1), P = P(1:n - 1, :); end   % abort() records the last tick again
            eng.Poses = P; eng.LastTick = P.tick_id(end); eng.EndState = pkg.manifest.end_state;
            eng.PhaseLog = table(0, 0, "CONFIGURED", 'VariableNames', {'tick_id','t_s','phase'});
        end

        function t = time(eng), t = eng.TickId * eng.Config.dt_s; end
        function start(eng)
            if eng.Phase == "CONFIGURED", eng.setPhase("PREFLIGHT"); end
        end
        function pause(eng), eng.Paused = true; end
        function resume(eng), eng.Paused = false; end
        function tf = isTerminal(eng), tf = ismember(eng.Phase, ["COMPLETE","ABORTED","FAILED"]); end

        function abort(eng, reason, code)
            if nargin < 2, reason = "operator abort of the replay"; end
            if nargin < 3, code = "ABORTED_BY_OPERATOR"; end
            if eng.isTerminal(), return; end
            eng.FaultCode = string(code); eng.FaultMessage = string(reason); eng.setPhase("ABORTED");
        end

        function subscribe(eng, fcn)
            arguments
                eng
                fcn (1,1) function_handle
            end
            eng.Subscribers{end+1} = fcn;
        end

        function advanced = step(eng)
            %STEP Emit the next recorded tick. False when paused, not started, terminal or at the end of the recording.
            advanced = false;
            if eng.Paused || eng.Phase == "CONFIGURED" || eng.isTerminal() || eng.TickId >= eng.LastTick, return; end
            eng.TickId = eng.TickId + 1; advanced = true;
            p = eng.Poses.phase(eng.TickId + 1);
            if p ~= eng.Phase, eng.setPhase(p); end
            if eng.TickId == eng.LastTick, eng.finish(); end
            s = eng.snapshot();
            for k = 1:numel(eng.Subscribers), eng.Subscribers{k}(s); end
            if eng.TickId == eng.LastTick && eng.EndState.phase == "ABORTED"   % abort came between ticks, after this pose
                eng.FaultCode = string(eng.EndState.fault_code); eng.FaultMessage = string(eng.EndState.fault_message); eng.setPhase("ABORTED");
            end
        end

        function s = snapshot(eng)
            %SNAPSHOT The recorded PoseSample of the current tick, in the MissionEngine format.
            P = eng.Poses; k = eng.TickId + 1;
            row = [P.tick_id(k), P.t_s(k), P.position_enu_m(k,:), P.velocity_enu_mps(k,:), P.acceleration_enu_mps2(k,:), ...
                P.orientation_quat(k,:), P.angular_velocity_body_rps(k,:), P.yaw_rad(k), P.heading_deg(k), P.pitch_up_rad(k), ...
                P.roll_right_down_rad(k), P.altitude_agl_m(k), P.terrain_height_m(k), P.commanded_position_enu_m(k,:), P.wind_enu_mps(k,:)];
            s = mgv2.engine.MissionEngine.rowToSample(row, eng.Config, eng.Phase, eng.FaultCode);
        end

        function T = poseLog(eng)
            T = eng.Poses(1:eng.TickId + 1, :);
        end
    end

    methods (Access = private)
        function setPhase(eng, p)
            eng.Phase = string(p); eng.PhaseLog(end+1, :) = {eng.TickId, eng.time(), eng.Phase};
        end
        function finish(eng)
            e = eng.EndState;
            if ismember(string(e.phase), ["COMPLETE","FAILED"])
                eng.FaultCode = string(e.fault_code); eng.FaultMessage = string(e.fault_message);
                if eng.Phase ~= string(e.phase), eng.setPhase(e.phase); end
            end
        end
    end
end
