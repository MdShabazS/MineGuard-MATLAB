classdef MissionSession < handle
    %MISSIONSESSION Non-visual owner of the V2-002 engine, V2-005 sensors and the anomaly source. SIMULATION ONLY.
    %   ses = mgv2.ui.MissionSession(SensorConfig=cfg, Environment=env, AnomalySource=src)
    %   ses.step()  advances exactly one engine tick; v = ses.view() returns plain public data for the panels.
    %   v = ses.view(false) reuses the last validated events and layers without asking the source.
    %   ses.configure(scenario, seed)  before a start: rerun the same world under a listed scenario and mission seed.
    %   The authoritative clock and sensor state live here, never in a visual component. There is no timer.
    %   The session binds and subscribes the source once per engine/sensor pair. V2-005 has no reset or unsubscribe,
    %   so reset() replaces both objects with the same seed and configuration.
    %   A source output that fails validation is not shown: the events and layers are empty and the error is displayed.

    properties (Constant)
        % Thermal dropout: no valid temperature from t = 10 s to t = 40 s
        Scenarios = ["As launched", "Low contrast", "Overcast", "Thermal dropout"]
    end
    properties (SetAccess = private)
        World; MissionConfig; SensorConfig; Environment
        Engine; Sensors; Source
        Scenario = "As launched"
    end
    properties (Access = private)
        Launch            % configurations the session was created with
        Overlay           % last validated source output: see clearOverlay
        Generation = 0    % engine/sensor pairs built so far: tells apart two runs with the same run id
    end

    methods
        function ses = MissionSession(opts)
            arguments
                opts.MissionConfig struct = mgv2.mission.defaultConfig()
                opts.SensorConfig struct = mgv2.sensors.defaultSensorConfig()
                opts.Environment struct = mgv2.sensors.defaultEnvironment()
                opts.AnomalySource (1,1) mgv2.ui.AnomalySource = mgv2.ui.NullAnomalySource()
            end
            ses.World = mgv2.scene.buildWorld(); ses.MissionConfig = opts.MissionConfig;
            ses.SensorConfig = opts.SensorConfig; ses.Environment = opts.Environment; ses.Source = opts.AnomalySource;
            ses.Launch = struct('mission', opts.MissionConfig, 'sensors', opts.SensorConfig, 'environment', opts.Environment);
            ses.Source.bindEvidence(@() ses.evidenceContext());
            ses.clearOverlay(); ses.build();
        end

        function start(ses), ses.Engine.start(); end
        function pauseRun(ses), ses.Engine.pause(); end
        function resumeRun(ses), ses.Engine.resume(); end
        function abortRun(ses), ses.Engine.abort("operator abort from mission control"); end
        function advanced = step(ses), advanced = ses.Engine.step(); end

        function p = pose(ses)
            %POSE Current PoseSample alone, for a scene-only refresh.
            p = ses.Engine.snapshot();
        end

        function reset(ses)
            %RESET Back to tick 0 with the original seed: new engine and sensors, same configuration.
            ses.Source.reset(); ses.clearOverlay(); ses.build();
        end

        function configure(ses, scenario, seed)
            %CONFIGURE Choose a listed scenario and mission seed before a start. The world and the plan stay the same.
            scenario = string(scenario);
            if ses.state() ~= "READY", error('mgv2:InvalidCommand', 'The scenario can change only before a start.'); end
            if ~ismember(scenario, ses.Scenarios), error('mgv2:InvalidCommand', 'Unknown scenario "%s".', scenario); end
            m = ses.Launch.mission; c = ses.Launch.sensors; e = ses.Launch.environment;
            switch scenario
                case "Low contrast", e = mgv2.sensors.defaultEnvironment("LOW_CONTRAST");
                case "Overcast", e = mgv2.sensors.defaultEnvironment("OVERCAST");
                case "Thermal dropout", c.THERMAL_LWIR.dropout_model.intervals_s = [10 40];
            end
            if scenario ~= "As launched" || seed ~= m.seed
                m.run_id = sprintf("V2RUN-UI-%s-%04d", upper(regexprep(scenario, '[^A-Za-z0-9]+', '_')), seed);
            end
            m.seed = seed;
            ses.Scenario = scenario; ses.MissionConfig = m; ses.SensorConfig = c; ses.Environment = e;
            ses.reset();
        end

        function ins = inspect(ses, eventId)
            %INSPECT Verified evidence of one public event from the source. It errors rather than substitute anything.
            ins = mgv2.ui.validateInspection(ses.Source.inspect(string(eventId)), eventId);
            L = ses.Sensors.Log;
            for it = reshape(ins.items, 1, [])
                k = find(L.frame_id == string(it.frame_id));
                if ~isscalar(k) || L.checksum(k) ~= string(it.sample_checksum) || L.tick_id(k) ~= it.tick_id
                    error('mgv2:EvidenceMismatch', 'Evidence %s does not match the sensor log of the current run.', string(it.ref_id));
                end
            end
        end

        function c = evidenceContext(ses)
            %EVIDENCECONTEXT Read-only copy of the current run for evidence checks. Public producer log only, no frames.
            %   Fields: run_id, generation (changes on every reset), state, tick, sensor_log (SensorSystem.Log).
            c = struct('run_id', string(ses.MissionConfig.run_id), 'generation', ses.Generation, 'state', ses.state(), ...
                'tick', double(ses.Engine.TickId), 'sensor_log', ses.Sensors.Log);
        end

        function s = state(ses)
            %STATE "READY" | "ACTIVE" | "PAUSED" | "ENDED", derived only from the engine.
            if ses.Engine.Phase == "CONFIGURED", s = "READY";
            elseif ses.Engine.isTerminal(), s = "ENDED";
            elseif ses.Engine.Paused, s = "PAUSED";
            else, s = "ACTIVE";
            end
        end

        function v = view(ses, readSource)
            %VIEW Plain-data picture of the current tick for the panels (the only thing they receive).
            if nargin < 2 || readSource, ses.readOverlay(); end
            eng = ses.Engine; sys = ses.Sensors; samples = struct(); o = ses.Overlay;
            for id = sys.Order, samples.(char(id)) = sys.latest(id); end
            v = struct('pose', eng.snapshot(), 'samples', samples, 'period', sys.Period, 'state', ses.state(), ...
                'fault_message', eng.FaultMessage, 'mission', sys.Mission, 'scenario', ses.Scenario, 'events', o.events, 'layers', o.layers, ...
                'source', o.source, 'overlay_key', o.key, 'overlay_error', o.error);
        end
    end

    methods (Access = private)
        function build(ses)
            ses.Generation = ses.Generation + 1;
            ses.Sensors = mgv2.sensors.SensorSystem(ses.World, ses.MissionConfig, SensorConfig=ses.SensorConfig, Environment=ses.Environment);
            ses.Engine = mgv2.engine.MissionEngine(ses.MissionConfig, mgv2.scene.terrainProvider(ses.World));
            src = ses.Source;
            src.bindRun(ses.World, ses.MissionConfig);
            src.onPose(ses.Engine.snapshot());
            ses.Engine.subscribe(@(p) src.onPose(p));       % before the sensors: a sample's pose is always known first
            ses.Sensors.subscribe(@(s) src.onSample(s));
            ses.Sensors.attach(ses.Engine);
        end

        function clearOverlay(ses)
            %CLEAROVERLAY key: events_as_of_tick of the validated output, NaN when the source reports no freshness.
            ses.Overlay = struct('events', struct([]), 'layers', struct([]), 'source', ses.Source.sourceInfo(), 'key', NaN, 'error', "");
        end

        function readOverlay(ses)
            %READOVERLAY Ask the source. Validation and panel redraws are skipped while its freshness tick is unchanged.
            src = ses.Source; o = ses.Overlay; ev = src.suspectedEvents(); L = src.mapLayers(); o.source = src.sourceInfo();
            key = NaN; if isfield(o.source, 'events_as_of_tick'), key = double(o.source.events_as_of_tick); end
            if ~isequal(key, o.key) || isnan(key)
                o.key = key; o.error = "";
                try
                    o.events = mgv2.ui.validateEvents(ev, ses.MissionConfig.run_id); o.layers = mgv2.ui.validateMapLayers(L);
                catch err
                    if ~ismember(string(err.identifier), ["mgv2:InvalidEvent", "mgv2:InvalidMapLayer", "mgv2:TruthLeak"]), rethrow(err); end
                    o.events = struct([]); o.layers = struct([]); o.error = string(err.message);
                end
            end
            ses.Overlay = o;
        end
    end
end
