classdef PlaybackSensors < handle
    %PLAYBACKSENSORS Emits the recorded samples of a verified run package at their own ticks (V2-008). SIMULATION ONLY.
    %   sys = mgv2.replay.PlaybackSensors(pkg)       pkg from mgv2.run.verifyPackage
    %   Offers the members of mgv2.sensors.SensorSystem that the session, dashboard and anomaly source use: attach,
    %   subscribe, latest, samplesAt, Log, Mission, Config, Period, Seq, KeepFrames and Order. Samples are the recorded
    %   ones, in the recorded order; no forward model runs and no random number is drawn. Log rows take time, ids and
    %   validity from the samples themselves and the checksum and generation time from the package index.

    properties (Constant)
        Order = mgv2.sensors.SensorSystem.Order
    end
    properties (SetAccess = private)
        Mission; Config; Period; Log; Seq
        KeepFrames = 8
    end
    properties (Access = private)
        ByTick            % cell: ByTick{tick+1} = {samples of that tick, in emission order}
        Meta              % struct per sample in ByTick order: checksum, gen_ms
        History; Subs = {}; LastTick = -1
    end

    methods
        function sys = PlaybackSensors(pkg)
            m = pkg.config.mission;
            sys.Config = mgv2.sensors.validateSensorConfig(pkg.config.sensors);
            sys.Mission = struct('run_id', string(m.run_id), 'scenario_id', string(m.scenario_id), 'seed', m.seed, ...
                'dt_s', m.dt_s, 'origin', m.virtual_wgs84_origin(:)');
            sys.Period = struct(); sys.Seq = struct();
            for id = sys.Order, sys.Period.(id) = round(1 / (m.dt_s * sys.Config.(id).rate_hz)); sys.Seq.(id) = 0; end
            idx = pkg.index; nT = height(pkg.poses);
            sys.ByTick = cell(1, nT); sys.Meta = cell(1, nT); pos = struct();
            for id = sys.Order, pos.(id) = 0; end
            for r = 1:height(idx)                          % index rows are in emission order
                id = char(idx.sensor_id(r)); pos.(id) = pos.(id) + 1; s = pkg.samples.(id){pos.(id)};
                t = double(s.tick_id) + 1;
                sys.ByTick{t}{end+1} = s; sys.Meta{t}{end+1} = struct('checksum', idx.checksum(r), 'gen_ms', idx.gen_ms(r));
            end
            sys.History = containers.Map(cellstr(sys.Order), repmat({{}}, 1, numel(sys.Order)));
            sys.Log = table('Size', [0 10], 'VariableTypes', ["string","uint64","uint64","uint64","double","logical","string","double","string","string"], ...
                'VariableNames', ["sensor_id","sample_seq","pose_id","tick_id","t_s","valid","invalid_reason","gen_ms","checksum","frame_id"]);
        end

        function attach(sys, engine)
            if engine.TickId == 0, sys.onPose(engine.snapshot()); end
            engine.subscribe(@(p) sys.onPose(p));
        end

        function subscribe(sys, fcn), sys.Subs{end+1} = fcn; end

        function onPose(sys, pose)
            t = double(pose.tick_id);
            if t <= sys.LastTick, error('mgv2:InvalidSample', 'Tick %d already replayed.', t); end
            sys.LastTick = t;
            if t + 1 > numel(sys.ByTick), return; end
            S = sys.ByTick{t + 1}; M = sys.Meta{t + 1};
            for k = 1:numel(S)
                s = S{k}; id = char(s.sensor_id);
                sys.Seq.(id) = double(s.sample_seq) + 1;
                h = [sys.History(id), {s}]; sys.History(id) = h(max(1, end - sys.KeepFrames + 1):end);
                sys.Log(end+1, :) = {string(id), s.sample_seq, s.pose_id, s.tick_id, s.t_s, s.valid, s.invalid_reason, M{k}.gen_ms, M{k}.checksum, s.frame_id};
                for j = 1:numel(sys.Subs), sys.Subs{j}(s); end
            end
        end

        function s = latest(sys, id)
            h = sys.History(char(id)); if isempty(h), s = []; else, s = h{end}; end
        end

        function S = samplesAt(sys, tick)
            S = {};
            for id = sys.Order
                h = sys.History(char(id));
                for k = 1:numel(h), if h{k}.tick_id == tick, S{end+1} = h{k}; end, end %#ok<AGROW>
            end
        end
    end
end
