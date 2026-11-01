classdef V2006AnomalySource < mgv2.ui.AnomalySource
    %V2006ANOMALYSOURCE Adapter from V2-006 public outputs to the V2-007 UI seam. SIMULATION ONLY.
    %   src = mgv2.bridge.V2006AnomalySource()               unbound: reports not connected, no events, no layers
    %   src = mgv2.bridge.V2006AnomalySource(RefreshTicks=20) ticks between rebuilds of the events and layers
    %   ses = mgv2.ui.MissionSession(AnomalySource=src); src.bindSession(ses)
    %   app = mgv2.ui.MissionControlApp(AnomalySource=src); src.bindSession(app.Session)
    %   ins = src.inspect("SUS-00012")                        verified evidence record for one event
    %
    %   Late binding: MissionSession creates its world, mission, engine and sensors after it receives this source,
    %   so the detector and map are built in bindSession from the session's own objects, never from a guessed copy.
    %   Tick-0 samples emitted before binding are held and replayed. Binding after tick 0 is refused, because earlier
    %   samples would be missing. Poses come from a subscription to the session's engine, re-attached after a reset.
    %
    %   Refresh: events and layers are rebuilt at most once per RefreshTicks while the session is ACTIVE, and on
    %   demand when it is paused or ended. Between rebuilds, the last validated result is returned unchanged.
    %   sourceInfo reports its age. Ticks, never wall clock, decide when to rebuild, so runs are deterministic.
    %
    %   Boundaries: public samples only, no scenario truth, no mgv2.eval. This class holds no route for display;
    %   MapPanel owns the plan, UAV and flown route. The detector schema and thresholds are not changed here.
    %   Events are SUSPECTED with an uncalibrated score and uncertainty. Coverage is evidence acquisition only.

    properties (SetAccess = private)
        RefreshTicks
        Session = []          % the bound mgv2.ui.MissionSession
        Detector = []         % mgv2.detect.AnomalyDetector for the current run
        Map = []              % mgv2.map.MissionMap for the current run
        Stats                 % measured counters: see newStats
    end
    properties (Access = private)
        Pending = {}          % samples received before binding
        PoseEngine = []       % engine currently followed for poses
        SubscribedEngines = {}
        Dirty = false
        AsOfTick = -1; AsOfTime = NaN
        RawEvents = []; UiEvents = struct([]); Layers = struct([]); Rejected = strings(0, 1)
        LayerRevision = 0; CoverageKey = []; EventKey = []; CoverageRev = 0; EventRev = 0
    end
    properties (Constant)
        MaxPending = 16
    end

    methods
        function obj = V2006AnomalySource(opts)
            arguments
                opts.RefreshTicks (1,1) double {mustBeInteger, mustBePositive} = 20
            end
            obj.RefreshTicks = opts.RefreshTicks; obj.Stats = obj.newStats();
        end

        function bindSession(obj, ses)
            %BINDSESSION Use the session's own public world and mission, and follow its engine.
            arguments
                obj
                ses (1,1) mgv2.ui.MissionSession
            end
            if ~isempty(obj.Session), error('mgv2:BridgeAlreadyBound', 'This source is already bound to a session.'); end
            if ses.Source ~= obj, error('mgv2:BridgeWrongSession', 'The session was not created with this source.'); end
            if ses.Engine.TickId ~= 0 || numel(obj.Pending) >= obj.MaxPending
                error('mgv2:BridgeLateBind', 'Bind before the first engine tick: earlier samples and poses would be missing.');
            end
            obj.Session = ses; obj.newRun();
            P = obj.Pending; obj.Pending = {};
            for k = 1:numel(P), obj.process(P{k}); end
        end

        function onSample(obj, s)
            if isempty(obj.Session)
                mgv2.sensors.validateSample(s);
                if numel(obj.Pending) < obj.MaxPending, obj.Pending{end+1} = s; else, obj.Stats.pending_overflow = obj.Stats.pending_overflow + 1; end
                return
            end
            if isempty(obj.PoseEngine), obj.followEngine(); end
            obj.process(s);
        end

        function ev = suspectedEvents(obj)
            obj.ensureFresh(); ev = obj.UiEvents;
        end

        function L = mapLayers(obj)
            obj.ensureFresh(); L = obj.Layers;
        end

        function i = sourceInfo(obj)
            if isempty(obj.Session)
                i = struct('connected', false, 'detector_version', "", 'status_text', "DETECTOR BRIDGE NOT BOUND", 'detector_fingerprint', "", ...
                    'events_as_of_tick', -1, 'events_as_of_t_s', NaN, 'current_tick', -1, 'stale_ticks', NaN, 'rejected_events', 0);
                return
            end
            d = obj.Detector; tick = max(d.CurrentTick, 0); stale = tick - obj.AsOfTick; if obj.AsOfTick < 0, stale = NaN; end
            txt = sprintf("V2-006 baseline %s | SUSPECTED only | uncalibrated | as of t=%.1f s", d.Config.detector_version, obj.AsOfTime);
            if ~isempty(obj.Rejected), txt = txt + sprintf(" | %d REJECTED", numel(obj.Rejected)); end
            i = struct('connected', true, 'detector_version', d.Config.detector_version, 'status_text', txt, 'detector_fingerprint', d.Fingerprint, ...
                'events_as_of_tick', obj.AsOfTick, 'events_as_of_t_s', obj.AsOfTime, 'current_tick', tick, 'stale_ticks', stale, 'rejected_events', numel(obj.Rejected));
        end

        function reset(obj)
            %RESET Clear run state. MissionSession then builds a new engine, followed on its first sample.
            obj.Pending = {};
            if ~isempty(obj.Session), obj.newRun(); end
            obj.Stats.resets = obj.Stats.resets + 1;
        end

        function ins = inspect(obj, eventId, opts)
            %INSPECT Verified evidence for one event, from its exact references. Nothing is ever substituted.
            arguments
                obj
                eventId (1,1) string
                opts.SensorLog = []
            end
            if isempty(obj.Session), error('mgv2:BridgeNotBound', 'Bind the source before inspecting events.'); end
            obj.rebuild();
            E = obj.RawEvents; k = [];
            if ~isempty(E), k = find([E.event_id] == eventId); end
            if ~isscalar(k), error('mgv2:EventNotFound', 'Event %s is not in the current detector output.', eventId); end
            L = opts.SensorLog; if isempty(L), L = obj.Session.Sensors.Log; end
            ins = mgv2.bridge.checkEvidence(E(k), obj.Detector, L, obj.Detector.RunId);
        end

        function n = rejectedEventIds(obj)
            n = obj.Rejected;
        end
    end

    methods (Access = private)
        function newRun(obj)
            ses = obj.Session;
            obj.Detector = mgv2.detect.AnomalyDetector(ses.World, ses.MissionConfig);
            obj.Map = mgv2.map.MissionMap(ses.World, ses.MissionConfig);
            obj.PoseEngine = []; obj.Dirty = true; obj.AsOfTick = -1; obj.AsOfTime = NaN;
            obj.RawEvents = []; obj.UiEvents = struct([]); obj.Layers = struct([]); obj.Rejected = strings(0, 1);
            obj.CoverageKey = []; obj.EventKey = [];
            if obj.Session.Engine.TickId == 0 && ~obj.isOldEngine(ses.Engine), obj.followEngine(); end
        end

        function tf = isOldEngine(obj, eng)
            tf = false;
            for k = 1:numel(obj.SubscribedEngines), tf = tf || obj.SubscribedEngines{k} == eng; end
        end

        function followEngine(obj)
            eng = obj.Session.Engine;
            if obj.isOldEngine(eng), return; end               % never a second subscription to one engine
            obj.PoseEngine = eng; obj.SubscribedEngines{end+1} = eng;
            obj.SubscribedEngines = obj.SubscribedEngines(max(1, end - 1):end);   % keep only the current and previous engine
            if eng.TickId == 0, obj.addPose(eng.snapshot()); end
            eng.subscribe(@(p) obj.onEnginePose(p, eng));
            obj.Stats.pose_subscriptions = obj.Stats.pose_subscriptions + 1;
        end

        function onEnginePose(obj, p, eng)
            if eng == obj.PoseEngine, obj.addPose(p); end
        end

        function addPose(obj, p)
            obj.Map.addPose(p); obj.Stats.poses = obj.Stats.poses + 1; obj.Dirty = true;
        end

        function process(obj, s)
            t0 = tic; outcome = obj.Detector.ingest(s);               % validates the sample; a truth leak throws here
            if outcome == "ACCEPTED" || outcome == "INVALID_SAMPLE"
                obj.Map.addSample(s); obj.Dirty = true;               % a stale or wrong-run sample never reaches the map
            else
                obj.Stats.samples_refused = obj.Stats.samples_refused + 1;
            end
            obj.Stats.samples = obj.Stats.samples + 1;
            ms = 1e3 * toc(t0); obj.Stats.on_sample_total_ms = obj.Stats.on_sample_total_ms + ms; obj.Stats.on_sample_max_ms = max(obj.Stats.on_sample_max_ms, ms);
        end

        function ensureFresh(obj)
            if isempty(obj.Session), return; end
            obj.Stats.requests = obj.Stats.requests + 1;
            if ~obj.Dirty, return; end
            tick = obj.Detector.CurrentTick;
            if obj.AsOfTick < 0 || tick - obj.AsOfTick >= obj.RefreshTicks || obj.Session.state() ~= "ACTIVE", obj.rebuild(); end
        end

        function rebuild(obj)
            if ~obj.Dirty, return; end
            t0 = tic; d = obj.Detector;
            E = d.events(); t1 = tic;
            [ev, rej] = mgv2.bridge.toUiEvents(E, d.RunId, d);
            ev = mgv2.ui.validateEvents(ev);
            if isempty(rej), obj.RawEvents = E; else, obj.RawEvents = E(~ismember([E.event_id], rej)); end
            ms2 = 1e3 * toc(t1); t2 = tic;
            S = obj.Map.snapshot();
            key = S.cell_state; if ~isequal(key, obj.CoverageKey), obj.CoverageKey = key; obj.LayerRevision = obj.LayerRevision + 1; obj.CoverageRev = obj.LayerRevision; end
            key = obj.eventKey(ev); if ~isequal(key, obj.EventKey), obj.EventKey = key; obj.LayerRevision = obj.LayerRevision + 1; obj.EventRev = obj.LayerRevision; end
            L = mgv2.bridge.toMapLayers(S, ev, obj.CoverageRev, obj.EventRev);
            L = mgv2.ui.validateMapLayers(L);
            ms3 = 1e3 * toc(t2);
            obj.UiEvents = ev; obj.Layers = L; obj.Rejected = rej;
            obj.AsOfTick = max(d.CurrentTick, 0); obj.AsOfTime = obj.AsOfTick * d.Dt; obj.Dirty = false;
            st = obj.Stats; st.rebuilds = st.rebuilds + 1; n = st.rebuilds;
            st.rebuild_ms(n, 1) = 1e3 * toc(t0); st.rebuild_tick(n, 1) = obj.AsOfTick; st.rebuild_events(n, 1) = numel(ev);
            st.convert_ms(n, 1) = ms2; st.layers_ms(n, 1) = ms3; obj.Stats = st;
        end
    end

    methods (Static, Access = private)
        function s = newStats()
            e = zeros(0, 1);
            s = struct('samples', 0, 'samples_refused', 0, 'poses', 0, 'pose_subscriptions', 0, 'requests', 0, 'rebuilds', 0, 'resets', 0, 'pending_overflow', 0, ...
                'on_sample_total_ms', 0, 'on_sample_max_ms', 0, 'rebuild_ms', e, 'rebuild_tick', e, 'rebuild_events', e, 'convert_ms', e, 'layers_ms', e);
        end

        function k = eventKey(ev)
            if isempty(ev), k = zeros(0, 3); else, k = [[ev.x_est_m]' [ev.y_est_m]' [ev.model_score]']; end
        end
    end
end
