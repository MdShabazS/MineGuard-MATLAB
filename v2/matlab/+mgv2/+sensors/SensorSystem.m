classdef SensorSystem < handle
    %SENSORSYSTEM Time-synchronised virtual RGB / thermal / LiDAR / GNSS-INS on the V2-002 clock. SIMULATED.
    %   sys = mgv2.sensors.SensorSystem(world, missionCfg)
    %   sys = mgv2.sensors.SensorSystem(world, missionCfg, SensorConfig=cfg, Environment=env, KeepFrames=8)
    %   sys = mgv2.sensors.SensorSystem(..., SurfaceFeatures=F)   PRIVATE flat surface features for the RGB/thermal
    %         forward models (V2-006 scenario hook; mgv2.sensors.validateSurfaceFeatures). Default none = V2-005.
    %   sys.attach(engine)      samples the engine's tick-0 pose (if not started) and subscribes to every
    %                           EXECUTED tick; a paused engine executes no tick, so no sample is emitted.
    %   S = sys.latest("RGB_NADIR");  L = sys.Log;  sys.samplesAt(tick)
    %
    %   Scheduling (V2-004 §2.1): channel due when mod(tick_id, N) == 0 with N = round(1/(dt*rate)),
    %   N >= 1 and |N*dt - 1/rate| <= 1e-9 s, else mgv2:InvalidSensorConfig. Nominal: RGB/thermal N=4,
    %   LiDAR N=10, navigation N=2 at dt = 0.05 s. Every sample copies pose_id/tick_id/t_s from the single
    %   immutable PoseSample of that tick; no sample is generated for a tick that did not execute.
    %   The sensor scene's radiometry is PRIVATE to this object; public samples pass validateSample
    %   (exact fields + truth-firewall scan) before they are stored or handed to subscribers.
    %   Wall-clock time is used ONLY to measure generation time (Log.gen_ms), never for timestamps.

    properties (SetAccess = private)
        Mission        % run_id, scenario_id, seed, dt_s, virtual origin
        Config         % validated SensorConfig per channel
        Period         % ticks between samples per channel
        Log            % table: one row per emitted sample (metadata, checksum, generation time)
        Seq            % next sample_seq per channel
        KeepFrames
    end
    properties (Access = private)
        Scene          % private: includes forward-model radiometry
        History        % containers.Map sensor_id -> cell of last KeepFrames samples
        Subs = {}
        LastTick = -1
    end
    properties (Constant)
        Order = ["VIRTUAL_GNSS_INS","LIDAR_TERRAIN","THERMAL_LWIR","RGB_NADIR"]
    end

    methods
        function sys = SensorSystem(world, missionCfg, opts)
            arguments
                world struct
                missionCfg struct
                opts.SensorConfig struct = mgv2.sensors.defaultSensorConfig()
                opts.Environment struct = mgv2.sensors.defaultEnvironment()
                opts.KeepFrames (1,1) double {mustBeInteger, mustBePositive} = 8
                opts.SurfaceFeatures = []
            end
            mgv2.sensors.assertPublic(rmfield(world, intersect(fieldnames(world), {'V','F','Z','vertex_rgb','material_weights','x','y'})), "world");
            mgv2.sensors.assertPublic(missionCfg, "missionConfig");
            sys.Config = mgv2.sensors.validateSensorConfig(opts.SensorConfig);
            sys.Mission = struct('run_id', string(missionCfg.run_id), 'scenario_id', string(missionCfg.scenario_id), ...
                'seed', missionCfg.seed, 'dt_s', missionCfg.dt_s, 'origin', missionCfg.virtual_wgs84_origin(:)');
            sys.Period = struct();
            for id = sys.Order
                N = round(1 / (missionCfg.dt_s * sys.Config.(id).rate_hz));
                if N < 1 || abs(N * missionCfg.dt_s - 1 / sys.Config.(id).rate_hz) > 1e-9
                    error('mgv2:InvalidSensorConfig', '%s rate %.6g Hz is incompatible with dt %.6g s (N must be an integer >= 1).', ...
                        id, sys.Config.(id).rate_hz, missionCfg.dt_s);
                end
                sys.Period.(id) = N; sys.Seq.(id) = 0;
            end
            sys.Scene = mgv2.sensors.buildSensorScene(world, opts.Environment, opts.SurfaceFeatures);
            sys.KeepFrames = opts.KeepFrames;
            sys.History = containers.Map(cellstr(sys.Order), repmat({{}}, 1, numel(sys.Order)));
            sys.Log = table('Size', [0 10], 'VariableTypes', ["string","uint64","uint64","uint64","double","logical","string","double","string","string"], ...
                'VariableNames', ["sensor_id","sample_seq","pose_id","tick_id","t_s","valid","invalid_reason","gen_ms","checksum","frame_id"]);
        end

        function attach(sys, engine)
            %ATTACH Sample the current (tick-0) pose if the engine has not run, then follow every executed tick.
            if engine.TickId == 0, sys.onPose(engine.snapshot()); end
            engine.subscribe(@(s) sys.onPose(s));
        end

        function subscribe(sys, fcn)
            %SUBSCRIBE fcn(sample) is called for every emitted public sample (e.g. a display).
            sys.Subs{end+1} = fcn;
        end

        function onPose(sys, pose)
            %ONPOSE Emit every channel due at this tick from this one immutable pose (fixed channel order).
            if pose.tick_id <= sys.LastTick
                error('mgv2:InvalidSample', 'Tick %d already sampled (ticks must strictly increase).', pose.tick_id);
            end
            sys.LastTick = pose.tick_id;
            for id = sys.Order
                c = sys.Config.(id);
                if ~c.enabled || mod(pose.tick_id, sys.Period.(id)) ~= 0, continue; end
                seq = sys.Seq.(id); t0 = tic;
                try
                    switch id
                        case {"RGB_NADIR","THERMAL_LWIR"}, s = mgv2.sensors.sampleCamera(sys.Scene, c, sys.Mission, pose, seq);
                        case "LIDAR_TERRAIN", s = mgv2.sensors.sampleLidar(sys.Scene, c, sys.Mission, pose, seq);
                        otherwise, s = mgv2.sensors.sampleNav(c, sys.Mission, pose, seq, sys.Mission.origin);
                    end
                catch err
                    if startsWith(err.identifier, 'mgv2:'), rethrow(err); end
                    s = sys.numericError(c, pose, seq);
                end
                ms = 1e3 * toc(t0);
                mgv2.sensors.validateSample(s);
                sys.Seq.(id) = seq + 1;
                h = [sys.History(char(id)), {s}]; sys.History(char(id)) = h(max(1, end - sys.KeepFrames + 1):end);
                sys.Log(end+1, :) = {id, s.sample_seq, s.pose_id, s.tick_id, s.t_s, s.valid, s.invalid_reason, ms, ...
                    mgv2.sensors.checksum(mgv2.sensors.SensorSystem.payload(s)), s.frame_id};
                for k = 1:numel(sys.Subs), sys.Subs{k}(s); end
            end
        end

        function s = latest(sys, id)
            h = sys.History(char(id)); if isempty(h), s = []; else, s = h{end}; end
        end

        function S = samplesAt(sys, tick)
            %SAMPLESAT Retained samples (any channel) whose tick_id equals tick.
            S = {};
            for id = sys.Order
                h = sys.History(char(id));
                for k = 1:numel(h), if h{k}.tick_id == tick, S{end+1} = h{k}; end, end %#ok<AGROW>
            end
        end
    end

    methods (Access = private)
        function s = numericError(sys, c, pose, seq)
            % a failed computation yields an explicit invalid sample of the correct schema, never a fake value
            bad = pose; bad.position_enu_m = [NaN NaN NaN];
            switch c.sensor_id
                case {"RGB_NADIR","THERMAL_LWIR"}, s = mgv2.sensors.sampleCamera(sys.Scene, c, sys.Mission, bad, seq);
                case "LIDAR_TERRAIN", s = mgv2.sensors.sampleLidar(sys.Scene, c, sys.Mission, bad, seq);
                otherwise, s = mgv2.sensors.sampleNav(c, sys.Mission, bad, seq, sys.Mission.origin);
            end
            s.invalid_reason = "NUMERIC_ERROR";
        end
    end

    methods (Static)
        function x = payload(s)
            switch s.sensor_id
                case "RGB_NADIR", x = s.image_rgb_uint8;
                case "THERMAL_LWIR", x = s.temperature_K;
                case "LIDAR_TERRAIN", x = s.ranges_m;
                otherwise, x = [s.reported_position_enu_m s.reported_velocity_enu_mps s.reported_orientation_quat];
            end
        end
    end
end
