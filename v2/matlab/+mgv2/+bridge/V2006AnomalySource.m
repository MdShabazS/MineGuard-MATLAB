classdef V2006AnomalySource < mgv2.ui.AnomalySource
    %V2006ANOMALYSOURCE Adapter from V2-006 public outputs to the V2-007 UI seam (UI Stage 3). SIMULATION ONLY.
    %   src = mgv2.bridge.V2006AnomalySource()                without a session: reports not connected, no events, no layers
    %   src = mgv2.bridge.V2006AnomalySource(RefreshTicks=20) ticks between rebuilds of the events and layers
    %   app = mgv2MissionControl('AnomalySource', src)        binds itself: events, layers and coverage work
    %   src.bindSession(app.Session)                          also gives access to the producer's sensor log for inspect
    %   ins = src.inspect("SUS-00012")                        verified evidence record for one event
    %
    %   Binding: MissionSession calls bindRun with its own public world and mission, once per engine, also after a
    %   reset or scenario change, and onPose with every executed pose. The detector and map are built there, never
    %   from a guessed copy. Every sample and pose arrives through the session, exactly once.
    %
    %   Evidence: inspect checks each record against the producer's SensorSystem.Log. The bindRun seam does not carry
    %   that log, so bindSession supplies it. Without it inspect raises mgv2:EvidenceLogUnavailable rather than report
    %   an unchecked record as verified.
    %
    %   Refresh: events and layers are rebuilt at most once per RefreshTicks while the clock runs, and on demand once
    %   it holds (session paused or ended, a repeated request at one tick, or a terminal pose). Between rebuilds, the
    %   last validated result is returned unchanged and sourceInfo reports its age. Ticks, never wall clock, decide
    %   when to rebuild, so runs are deterministic. events_as_of_tick changes whenever the output changes.
    %
    %   Boundaries: public samples only, no scenario truth, no mgv2.eval. This class holds no route for display;
    %   MapPanel owns the plan, UAV and flown route. The detector schema and thresholds are not changed here.
    %   Events are SUSPECTED with an uncalibrated score and uncertainty. Coverage is evidence acquisition only.

    properties (SetAccess = private)
        RefreshTicks
        Session = []          % optional mgv2.ui.MissionSession: source of the producer's sensor log
        Detector = []         % mgv2.detect.AnomalyDetector for the current run
        Map = []              % mgv2.map.MissionMap for the current run
        Stats                 % measured counters: see newStats
    end
    properties (Access = private)
        Dirty = false
        PoseTick = -1; RequestTick = -1; Terminal = false
        AsOfTick = -1; AsOfTime = NaN
        RawEvents = []; UiEvents = struct([]); Layers = struct([]); Rejected = strings(0, 1)
        LayerRevision = 0; CoverageKey = []; EventKey = []; CoverageRev = 0; EventRev = 0
        ValidatedEvents       % containers.Map: events already through validateEvent in this run
    end

    methods
        function obj = V2006AnomalySource(opts)
            arguments
                opts.RefreshTicks (1,1) double {mustBeInteger, mustBePositive} = 20
            end
            obj.RefreshTicks = opts.RefreshTicks; obj.Stats = obj.newStats();
        end

        function bindRun(obj, world, missionCfg)
            %BINDRUN Called by the session before the first pose and sample of each engine.
            obj.clearRun();
            obj.Detector = mgv2.detect.AnomalyDetector(world, missionCfg);
            obj.Map = mgv2.map.MissionMap(world, missionCfg);
            obj.ValidatedEvents = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Dirty = true; obj.Stats.binds = obj.Stats.binds + 1;
        end

        function bindSession(obj, ses)
            %BINDSESSION Optional: use this session's sensor log for inspect and its state for refresh. Allowed at any tick.
            arguments
                obj
                ses (1,1) mgv2.ui.MissionSession
            end
            if ~isempty(obj.Session), error('mgv2:BridgeAlreadyBound', 'This source is already bound to a session.'); end
            if ses.Source ~= obj, error('mgv2:BridgeWrongSession', 'The session was not created with this source.'); end
            obj.Session = ses;
        end

        function onPose(obj, p)
            if isempty(obj.Map), return; end
            obj.Map.addPose(p); obj.Stats.poses = obj.Stats.poses + 1; obj.Dirty = true;
            obj.PoseTick = double(p.tick_id); obj.Terminal = ismember(string(p.phase), ["COMPLETE","ABORTED","FAILED"]);
        end

        function onSample(obj, s)
            if isempty(obj.Detector)
                mgv2.sensors.validateSample(s);                       % a truth leak throws even with nothing bound
                obj.Stats.samples_unbound = obj.Stats.samples_unbound + 1;
                return
            end
            obj.process(s);
        end

        function ev = suspectedEvents(obj)
            obj.ensureFresh(true); ev = obj.UiEvents;
        end

        function L = mapLayers(obj)
            obj.ensureFresh(false); L = obj.Layers;
        end

        function i = sourceInfo(obj)
            if isempty(obj.Detector)
                i = struct('connected', false, 'detector_version', "", 'status_text', "DETECTOR BRIDGE NOT BOUND", 'detector_fingerprint', "", ...
                    'events_as_of_tick', -1, 'events_as_of_t_s', NaN, 'current_tick', -1, 'stale_ticks', NaN, 'rejected_events', 0);
                return
            end
            d = obj.Detector; tick = obj.clockTick(); stale = tick - obj.AsOfTick; if obj.AsOfTick < 0, stale = NaN; end
            txt = sprintf("V2-006 baseline %s | SUSPECTED only | uncalibrated | as of t=%.1f s", d.Config.detector_version, obj.AsOfTime);
            if ~isempty(obj.Rejected), txt = txt + sprintf(" | %d REJECTED", numel(obj.Rejected)); end
            i = struct('connected', true, 'detector_version', d.Config.detector_version, 'status_text', txt, 'detector_fingerprint', d.Fingerprint, ...
                'events_as_of_tick', obj.AsOfTick, 'events_as_of_t_s', obj.AsOfTime, 'current_tick', tick, 'stale_ticks', stale, 'rejected_events', numel(obj.Rejected));
        end

        function reset(obj)
            %RESET Clear run state. The session then calls bindRun for its new engine.
            obj.clearRun(); obj.Stats.resets = obj.Stats.resets + 1;
        end

        function ins = inspect(obj, eventId, opts)
            %INSPECT Verified evidence for one event, from its exact references. Nothing is ever substituted.
            arguments
                obj
                eventId (1,1) string
                opts.SensorLog = []
            end
            if isempty(obj.Detector), error('mgv2:BridgeNotBound', 'Bind the source before inspecting events.'); end
            obj.rebuild();
            E = obj.RawEvents; k = [];
            if ~isempty(E), k = find([E.event_id] == eventId); end
            if ~isscalar(k), error('mgv2:EventNotFound', 'Event %s is not in the current detector output.', eventId); end
            L = opts.SensorLog;
            if isempty(L)
                if isempty(obj.Session), error('mgv2:EvidenceLogUnavailable', 'Event %s cannot be verified: no producer sensor log is available.', eventId); end
                L = obj.Session.Sensors.Log;
            end
            ins = mgv2.bridge.checkEvidence(E(k), obj.Detector, L, obj.Detector.RunId);
        end

        function n = rejectedEventIds(obj)
            n = obj.Rejected;
        end
    end

    methods (Access = private)
        function clearRun(obj)
            obj.Detector = []; obj.Map = []; obj.Dirty = false; obj.PoseTick = -1; obj.RequestTick = -1; obj.Terminal = false;
            obj.AsOfTick = -1; obj.AsOfTime = NaN;
            obj.RawEvents = []; obj.UiEvents = struct([]); obj.Layers = struct([]); obj.Rejected = strings(0, 1);
            obj.CoverageKey = []; obj.EventKey = []; obj.ValidatedEvents = [];
        end

        function t = clockTick(obj)
            t = max([obj.Detector.CurrentTick, obj.PoseTick, 0]);     % poses and samples both change the output
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

        function ensureFresh(obj, isEventRequest)
            if isempty(obj.Detector), return; end
            obj.Stats.requests = obj.Stats.requests + 1;
            tick = obj.clockTick(); held = false;
            if isEventRequest, held = tick == obj.RequestTick; obj.RequestTick = tick; end   % asked twice at one tick: the clock holds
            if ~obj.Dirty, return; end
            ended = obj.Terminal || held || (~isempty(obj.Session) && obj.Session.state() ~= "ACTIVE");
            if obj.AsOfTick < 0 || tick - obj.AsOfTick >= obj.RefreshTicks || ended, obj.rebuild(); end
        end

        function rebuild(obj)
            if ~obj.Dirty, return; end
            t0 = tic; d = obj.Detector;
            E = d.events(); t1 = tic;
            [ev, rej] = mgv2.bridge.toUiEvents(E, d.RunId, d, obj.ValidatedEvents);
            ev = mgv2.ui.validateEvents(ev, d.RunId);
            if isempty(rej), obj.RawEvents = E; else, obj.RawEvents = E(~ismember([E.event_id], rej)); end
            ms2 = 1e3 * toc(t1); t2 = tic;
            S = obj.Map.snapshot();
            key = S.cell_state; if ~isequal(key, obj.CoverageKey), obj.CoverageKey = key; obj.LayerRevision = obj.LayerRevision + 1; obj.CoverageRev = obj.LayerRevision; end
            key = obj.eventKey(ev); if ~isequal(key, obj.EventKey), obj.EventKey = key; obj.LayerRevision = obj.LayerRevision + 1; obj.EventRev = obj.LayerRevision; end
            L = mgv2.bridge.toMapLayers(S, ev, obj.CoverageRev, obj.EventRev);
            L = mgv2.ui.validateMapLayers(L);
            ms3 = 1e3 * toc(t2);
            obj.UiEvents = ev; obj.Layers = L; obj.Rejected = rej;
            obj.AsOfTick = obj.clockTick(); obj.AsOfTime = obj.AsOfTick * d.Dt; obj.Dirty = false;
            st = obj.Stats; st.rebuilds = st.rebuilds + 1; n = st.rebuilds;
            st.rebuild_ms(n, 1) = 1e3 * toc(t0); st.rebuild_tick(n, 1) = obj.AsOfTick; st.rebuild_events(n, 1) = numel(ev);
            st.convert_ms(n, 1) = ms2; st.layers_ms(n, 1) = ms3; obj.Stats = st;
        end
    end

    methods (Static, Access = private)
        function s = newStats()
            e = zeros(0, 1);
            s = struct('samples', 0, 'samples_refused', 0, 'samples_unbound', 0, 'poses', 0, 'binds', 0, 'requests', 0, 'rebuilds', 0, 'resets', 0, ...
                'on_sample_total_ms', 0, 'on_sample_max_ms', 0, 'rebuild_ms', e, 'rebuild_tick', e, 'rebuild_events', e, 'convert_ms', e, 'layers_ms', e);
        end

        function k = eventKey(ev)
            if isempty(ev), k = zeros(0, 3); else, k = [[ev.x_est_m]' [ev.y_est_m]' [ev.model_score]']; end
        end
    end
end
