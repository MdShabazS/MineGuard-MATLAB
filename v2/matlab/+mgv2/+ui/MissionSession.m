classdef MissionSession < handle
    %MISSIONSESSION Non-visual owner of the V2-002 engine, V2-005 sensors and the anomaly source. SIMULATION ONLY.
    %   ses = mgv2.ui.MissionSession(SensorConfig=cfg, Environment=env, AnomalySource=src)
    %   ses.step()  advances exactly one engine tick; v = ses.view() returns plain public data for the panels.
    %   The authoritative clock and sensor state live here, never in a visual component. There is no timer.
    %   The session subscribes the source once per engine/sensor pair. V2-005 has no reset or unsubscribe,
    %   so reset() replaces both objects with the same seed and configuration.

    properties (SetAccess = private)
        World; MissionConfig; SensorConfig; Environment
        Engine; Sensors; Source
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
            ses.build();
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
            ses.Source.reset(); ses.build();
        end

        function s = state(ses)
            %STATE "READY" | "ACTIVE" | "PAUSED" | "ENDED", derived only from the engine.
            if ses.Engine.Phase == "CONFIGURED", s = "READY";
            elseif ses.Engine.isTerminal(), s = "ENDED";
            elseif ses.Engine.Paused, s = "PAUSED";
            else, s = "ACTIVE";
            end
        end

        function v = view(ses)
            %VIEW Plain-data picture of the current tick for the panels (the only thing they receive).
            eng = ses.Engine; sys = ses.Sensors; samples = struct();
            for id = sys.Order, samples.(char(id)) = sys.latest(id); end
            v = struct('pose', eng.snapshot(), 'samples', samples, 'period', sys.Period, 'state', ses.state(), ...
                'fault_message', eng.FaultMessage, 'mission', sys.Mission, ...
                'events', mgv2.ui.validateEvents(ses.Source.suspectedEvents()), ...
                'layers', mgv2.ui.validateMapLayers(ses.Source.mapLayers()), 'source', ses.Source.sourceInfo());
        end
    end

    methods (Access = private)
        function build(ses)
            ses.Sensors = mgv2.sensors.SensorSystem(ses.World, ses.MissionConfig, SensorConfig=ses.SensorConfig, Environment=ses.Environment);
            ses.Engine = mgv2.engine.MissionEngine(ses.MissionConfig, mgv2.scene.terrainProvider(ses.World));
            src = ses.Source;
            ses.Sensors.subscribe(@(s) src.onSample(s));
            ses.Sensors.attach(ses.Engine);
        end
    end
end
