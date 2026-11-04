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
    %   V2-008: every public sample of a live run is recorded in memory (mgv2.run.Recorder) and folder = ses.exportRun(root)
    %   writes a finished run as a checksummed package. ses.loadReplay(folder) verifies a package and switches to REPLAY:
    %   the recorded poses and samples play on the same clock through the same source, and nothing is simulated.
    %   ses.replayCheck() compares the replayed events with the recorded ones. configure() returns to a live run.
    %   V2.1 seam: SceneConfig=cfg builds the world from that V2 scene config (default: the V2 field, unchanged), and
    %   SurfaceFeatures=F is a PRIVATE forward-model input passed only to SensorSystem. F is never in a view, the
    %   evidence context, an export or any public property; an export records only its SHA-256 commitment.

    properties (Constant)
        % Thermal dropout: no valid temperature from t = 10 s to t = 40 s.
        % Invalid rays: RGB and LiDAR measure only to 16 m, so off-nadir pixels and rays at 15 m AGL fall out of range,
        %   and 20 % of LiDAR rays drop out. Mission fault: a timeout just above the planned minimum, so the run FAILS
        %   with TIMEOUT before it lands. All live scenarios place no synthetic target.
        Scenarios = ["As launched", "Low contrast", "Overcast", "Thermal dropout", "Invalid rays", "Mission fault (timeout)"]
    end
    properties (SetAccess = private)
        World; MissionConfig; SensorConfig; Environment
        Engine; Sensors; Source
        Scenario = "As launched"
        Mode = "LIVE"     % "LIVE" | "REPLAY"
        Recorder = []     % every sample of the live run; empty in a replay
        Package = []      % the verified package being replayed
        SceneConfig       % V2 scene config the world was built from (public)
    end
    properties (Access = private)
        Launch            % configurations the session was created with
        Overlay           % last validated source output: see clearOverlay
        Generation = 0    % engine/sensor pairs built so far: tells apart two runs with the same run id
        Building = false  % true only while the tick-0 samples are emitted
        BindError = ""    % why the source refused this run; the mission flies without it and the error stays displayed
        PrivateFeatures   % PRIVATE forward-model surface features (mgv2.sensors.validateSurfaceFeatures); empty in V2
    end

    methods
        function ses = MissionSession(opts)
            arguments
                opts.MissionConfig struct = mgv2.mission.defaultConfig()
                opts.SensorConfig struct = mgv2.sensors.defaultSensorConfig()
                opts.Environment struct = mgv2.sensors.defaultEnvironment()
                opts.AnomalySource (1,1) mgv2.ui.AnomalySource = mgv2.ui.NullAnomalySource()
                opts.SceneConfig struct = mgv2.scene.defaultSceneConfig()
                opts.SurfaceFeatures = []
            end
            ses.SceneConfig = opts.SceneConfig; ses.PrivateFeatures = mgv2.sensors.validateSurfaceFeatures(opts.SurfaceFeatures);
            ses.World = mgv2.scene.buildWorld(opts.SceneConfig); ses.MissionConfig = opts.MissionConfig;
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
        function abortOnFault(ses, message)
            %ABORTONFAULT A tick threw part-way, so its samples are incomplete: the run ends and cannot be resumed.
            ses.Engine.abort("software fault during a tick: " + string(message), "SOFTWARE_FAULT");
        end

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
                case "Invalid rays"
                    c.RGB_NADIR.valid_range_m(2) = 16; c.LIDAR_TERRAIN.valid_range_m(2) = 16;
                    c.LIDAR_TERRAIN.dropout_model.ray_probability = 0.2;
                case "Mission fault (timeout)", m.constraints.timeout_s = mgv2.ui.MissionSession.shortTimeout(m);
            end
            if scenario ~= "As launched" || seed ~= m.seed
                m.run_id = sprintf("V2RUN-UI-%s-%04d", upper(regexprep(scenario, '[^A-Za-z0-9]+', '_')), seed);
            end
            m.seed = seed; mgv2.mission.validateConfig(m);      % refused before anything changes
            was = {ses.Scenario, ses.MissionConfig, ses.SensorConfig, ses.Environment, ses.Mode, ses.Package};
            ses.Scenario = scenario; ses.MissionConfig = m; ses.SensorConfig = c; ses.Environment = e; ses.Mode = "LIVE"; ses.Package = [];
            try
                ses.reset();
            catch err
                [ses.Scenario, ses.MissionConfig, ses.SensorConfig, ses.Environment, ses.Mode, ses.Package] = was{:}; ses.reset();
                rethrow(err);
            end
        end

        function folder = exportRun(ses, root)
            %EXPORTRUN Write this finished live run as a package under root (mgv2.run.exportRun). Errors, never partial success.
            if ses.Mode ~= "LIVE", error('mgv2:ExportFailed', 'A replay is not exported again; its package already exists.'); end
            if ses.state() ~= "ENDED", error('mgv2:ExportFailed', 'Only a finished run can be exported.'); end
            folder = mgv2.run.exportRun(ses.packageInputs(), root);
        end

        function in = packageInputs(ses)
            %PACKAGEINPUTS Everything exportRun writes, read from this run only. Evidence is read through the same checks
            %   as the inspector; an event whose evidence cannot be read is exported with the reason.
            eng = ses.Engine; v = ses.view(); ev = v.events; evidence = cell(1, numel(ev));
            for k = 1:numel(ev)
                try
                    evidence{k} = struct('event_id', string(ev(k).event_id), 'inspection', ses.inspectCurrentRun(ev(k).event_id), 'error', "");
                catch err
                    evidence{k} = struct('event_id', string(ev(k).event_id), 'inspection', struct(), 'error', string(err.message));
                end
            end
            samples = struct();
            for id = mgv2.sensors.SensorSystem.Order, samples.(id) = ses.Recorder.samples(id); end
            in = struct('mission', ses.MissionConfig, 'sensors', ses.Sensors.Config, 'environment', ses.Environment, ...
                'scenario', ses.Scenario, 'generation', ses.Generation, ...
                'end_state', struct('state', ses.state(), 'phase', eng.Phase, 'fault_code', eng.FaultCode, 'fault_message', eng.FaultMessage, ...
                    'tick', double(eng.TickId), 't_s', eng.time()), ...
                'poses', eng.poseLog(), 'phases', eng.PhaseLog, 'sensor_log', ses.Sensors.Log, 'samples', samples, ...
                'events', ev, 'source', v.source, 'evidence', {evidence}, 'world_digest', mgv2.run.digest(ses.World), ...
                'provenance', mgv2.ui.MissionSession.provenance(), 'scene_config', ses.SceneConfig, ...
                'private_forward_model', ses.privateCommitment());
        end

        function loadReplay(ses, folder)
            %LOADREPLAY Verify a package and prepare its replay at tick 0. A refused package leaves the session unchanged.
            if ses.state() == "ACTIVE", error('mgv2:InvalidCommand', 'Pause or end the run before a replay.'); end
            pkg = mgv2.run.verifyPackage(folder);
            if mgv2.run.digest(ses.World) ~= string(pkg.manifest.world_digest)
                error('mgv2:PackageInvalid', 'The package was recorded in a different world (world_digest differs).');
            end
            c = pkg.config;
            if ~ismember(string(c.scenario), ses.Scenarios), error('mgv2:PackageInvalid', 'Unknown scenario "%s" in the package.', string(c.scenario)); end
            was = {ses.Scenario, ses.MissionConfig, ses.SensorConfig, ses.Environment, ses.Mode, ses.Package};
            ses.Scenario = string(c.scenario); ses.MissionConfig = c.mission; ses.SensorConfig = c.sensors; ses.Environment = c.environment;
            ses.Mode = "REPLAY"; ses.Package = pkg;
            try
                ses.reset();
            catch err
                [ses.Scenario, ses.MissionConfig, ses.SensorConfig, ses.Environment, ses.Mode, ses.Package] = was{:}; ses.reset();
                rethrow(err);
            end
        end

        function c = privateCommitment(ses)
            %PRIVATECOMMITMENT Public record that a private forward model was used: a SHA-256 commitment, never the features.
            n = numel(ses.PrivateFeatures);
            c = struct('used', n > 0, 'features_sha256', "");
            if n > 0, c.features_sha256 = mgv2.run.digest(ses.PrivateFeatures); end
        end

        function n = packageName(ses)
            %PACKAGENAME Name of the package being replayed, "" in a live run.
            n = ""; if ses.Mode == "REPLAY", n = string(ses.Package.manifest.package); end
        end

        function r = replayCheck(ses)
            %REPLAYCHECK After a replay has ended: do the events from the replayed samples equal the recorded events?
            r = struct('done', false, 'match', false, 'detail', "");
            if ses.Mode ~= "REPLAY", r.detail = "not a replay"; return; end
            if ses.state() ~= "ENDED", r.detail = "replay not finished"; return; end
            r.done = true; now = ses.view().events; was = ses.Package.event_list;
            r.match = isequaln(now, was);
            if r.match, r.detail = sprintf('%d replayed events equal the %d recorded events', numel(now), numel(was));
            else, r.detail = sprintf('replayed events (%d) differ from the recorded events (%d)', numel(now), numel(was));
            end
        end

        function ins = inspect(ses, eventId)
            %INSPECT Verified evidence of one public event from the source. It errors rather than substitute anything.
            ins = mgv2.ui.validateInspection(ses.Source.inspect(string(eventId)), eventId);
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

        function ins = inspectCurrentRun(ses, eventId)
            %INSPECTCURRENTRUN inspect, then refuse evidence that this run's sensor log does not hold, whatever the source says.
            ins = ses.inspect(eventId); L = ses.Sensors.Log;
            for it = reshape(ins.items, 1, [])
                k = find(L.frame_id == string(it.frame_id));
                if ~isscalar(k) || L.checksum(k) ~= string(it.sample_checksum) || L.tick_id(k) ~= it.tick_id ...
                        || L.sensor_id(k) ~= string(it.sensor_id) || L.pose_id(k) ~= it.pose_id || L.t_s(k) ~= it.t_s
                    error('mgv2:EvidenceMismatch', 'Evidence %s does not match the sensor log of the current run.', string(it.ref_id));
                end
            end
        end

        function v = view(ses, readSource)
            %VIEW Plain-data picture of the current tick for the panels (the only thing they receive).
            if nargin < 2 || readSource, ses.readOverlay(); end
            eng = ses.Engine; sys = ses.Sensors; samples = struct(); o = ses.Overlay;
            for id = sys.Order, samples.(char(id)) = sys.latest(id); end
            v = struct('pose', eng.snapshot(), 'samples', samples, 'period', sys.Period, 'state', ses.state(), ...
                'fault_message', eng.FaultMessage, 'mission', sys.Mission, 'scenario', ses.Scenario, 'events', o.events, 'layers', o.layers, ...
                'source', o.source, 'overlay_key', o.key, 'overlay_error', o.error, 'mode', ses.Mode, 'package', ses.packageName());
        end
    end

    methods (Access = private)
        function build(ses)
            if ses.Mode == "REPLAY"
                sys = mgv2.replay.PlaybackSensors(ses.Package); eng = mgv2.replay.PlaybackEngine(ses.Package); rec = [];
            else
                sys = mgv2.sensors.SensorSystem(ses.World, ses.MissionConfig, SensorConfig=ses.SensorConfig, Environment=ses.Environment, ...
                    SurfaceFeatures=ses.PrivateFeatures);
                eng = mgv2.engine.MissionEngine(ses.MissionConfig, mgv2.scene.terrainProvider(ses.World));
                rec = mgv2.run.Recorder(); sys.subscribe(@(s) rec.add(s));      % first subscriber: every sample, tick 0 included
            end
            ses.Sensors = sys; ses.Engine = eng; ses.Recorder = rec; ses.Generation = ses.Generation + 1;   % built, then swapped together
            src = ses.Source;
            ses.BindError = "";
            try
                src.bindRun(ses.World, ses.MissionConfig);
                src.onPose(ses.Engine.snapshot());
                ses.Engine.subscribe(@(p) src.onPose(p));   % before the sensors: a sample's pose is always known first
                ses.Sensors.subscribe(@(s) ses.forwardSample(s));
            catch err
                ses.BindError = string(err.message);
            end
            ses.Building = true; ses.Sensors.attach(ses.Engine); ses.Building = false;   % the sensors never depend on the source
        end

        function forwardSample(ses, s)
            %FORWARDSAMPLE A failure on the tick-0 sample refuses the run like a failed bind. Later it faults the tick.
            if strlength(ses.BindError) > 0, return; end
            try
                ses.Source.onSample(s);
            catch err
                if ~ses.Building, rethrow(err); end
                ses.BindError = string(err.message);
            end
        end

        function clearOverlay(ses)
            %CLEAROVERLAY key: events_as_of_tick of the validated output, NaN when the source reports no freshness.
            ses.Overlay = struct('events', struct([]), 'layers', struct([]), 'source', ses.Source.sourceInfo(), 'key', NaN, 'error', "");
        end

        function readOverlay(ses)
            %READOVERLAY Ask the source. Validation and panel redraws are skipped while its freshness tick is unchanged.
            %   Any failure in reading or validating shows no overlays and displays the error; the run itself continues.
            src = ses.Source; o = ses.Overlay;
            if strlength(ses.BindError) > 0
                o.key = NaN; o.events = struct([]); o.layers = struct([]); o.error = "source refused this run: " + ses.BindError;
                ses.Overlay = o; return;
            end
            try
                ev = src.suspectedEvents(); L = src.mapLayers(); o.source = src.sourceInfo();
                key = NaN; if isfield(o.source, 'events_as_of_tick'), key = double(o.source.events_as_of_tick); end
                if ~isequal(key, o.key) || isnan(key) || strlength(o.error) > 0
                    o.key = key; o.error = "";
                    o.events = mgv2.ui.validateEvents(ev, ses.MissionConfig.run_id); o.layers = mgv2.ui.validateMapLayers(L);
                end
            catch err
                o.key = NaN; o.events = struct([]); o.layers = struct([]); o.error = string(err.message);
            end
            ses.Overlay = o;
        end
    end

    methods (Static)
        function t = shortTimeout(m)
            %SHORTTIMEOUT A timeout 2 s above the engine's preflight lower bound: preflight accepts it, the flight overruns it.
            c = mgv2.mission.validateConfig(m); k = c.constraints; route = mgv2.mission.buildRoute(c, mgv2.mission.planSurvey(c));
            t = ceil(route.length_m / c.speed_mps + c.alt_agl_setpoint_m / k.max_climb_mps + c.alt_agl_setpoint_m / k.max_descent_mps + c.preflight_s) + 2;
        end

        function p = provenance()
            %PROVENANCE Software that produced a package: MATLAB release, platform and, when available, the git commit.
            here = string(fileparts(mfilename('fullpath')));
            [st, sha] = system(sprintf('git -C "%s" rev-parse HEAD', here));
            if st ~= 0, sha = "unknown"; end
            [st2, dirty] = system(sprintf('git -C "%s" status --porcelain', here));
            p = struct('matlab', string(version), 'platform', string(computer), 'git_commit', strtrim(string(sha)), ...
                'git_tree_clean', st == 0 && st2 == 0 && strlength(strtrim(string(dirty))) == 0, 'producer', "mgv2.ui.MissionSession");
        end
    end
end
