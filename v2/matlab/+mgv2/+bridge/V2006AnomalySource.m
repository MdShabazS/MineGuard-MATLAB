classdef V2006AnomalySource < mgv2.ui.AnomalySource
    %V2006ANOMALYSOURCE Adapter from V2-006 public outputs to the V2-007 UI seam (UI Stage 3). SIMULATION ONLY.
    %   src = mgv2.bridge.V2006AnomalySource()                without a session: reports not connected, no events, no layers
    %   src = mgv2.bridge.V2006AnomalySource(RefreshTicks=20) ticks between rebuilds of the events and layers
    %   app = mgv2MissionControl('AnomalySource', src)        binds itself: events, layers, coverage and evidence work
    %   ins = src.inspect("SUS-00012")                        verified evidence record for one listed event
    %
    %   Binding: MissionSession calls bindEvidence once, then bindRun with its own public world and mission, once per
    %   engine, also after a reset or scenario change, and onPose with every executed pose. The detector and map are
    %   built there, never from a guessed copy. Every sample and pose arrives through the session, exactly once.
    %   One source serves one live session: a second session raises mgv2:BridgeAlreadyBound while the first one exists.
    %   If the session refuses a run at binding, the source keeps no detector or map for it.
    %
    %   Evidence: inspect checks each record against the session's current SensorSystem.Log, read through the provider.
    %   A reset or other run raises mgv2:BridgeRunMismatch. No provider raises mgv2:EvidenceLogUnavailable. inspect
    %   reads the listed result and never advances the refresh schedule, so a click cannot change a run. If the detector
    %   has since replaced a listed event's retained records, inspect reads that same event id from the current detector
    %   output, with all checks, and costs one detector read. The record states record_basis, its run and its age.
    %
    %   Refresh: events and layers are rebuilt at most once per RefreshTicks while the clock runs, and on demand once
    %   it holds (session paused or ended, or a terminal pose; without a session, a repeated request at one tick).
    %   RefreshTicks=20 is one simulated second, a provisional default. Between rebuilds, the last validated result is
    %   returned unchanged and sourceInfo reports its age. Ticks, never wall clock, decide when to rebuild, so runs are
    %   deterministic. events_as_of_tick changes whenever the output changes.
    %
    %   Boundaries: public samples only, no scenario truth, no mgv2.eval. This class holds no route for display;
    %   MapPanel owns the plan, UAV and flown route. The detector schema and thresholds are not changed here.
    %   Events are SUSPECTED with an uncalibrated score and uncertainty. Coverage is evidence acquisition only.

    properties (SetAccess = private)
        RefreshTicks
        Detector = []       % mgv2.detect.AnomalyDetector for the current run
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
        EvidenceFcn = []      % provider from the session: see mgv2.ui.MissionSession.evidenceContext
        BoundGeneration = NaN % session generation this detector was built for
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
            if ~isempty(obj.EvidenceFcn)
                try
                    c = obj.evidenceContext(); obj.BoundGeneration = c.generation;
                    if c.run_id ~= obj.Detector.RunId, error('mgv2:BridgeRunMismatch', 'Bound to run %s, but the session shows %s.', obj.Detector.RunId, c.run_id); end
                catch err
                    obj.clearRun(); rethrow(err);                     % a refused run leaves nothing that could be shown
                end
            end
        end

        function bindEvidence(obj, provider)
            %BINDEVIDENCE Called once by the session that owns this source, before its first bindRun.
            arguments
                obj
                provider (1,1) function_handle
            end
            if obj.providerIsLive(), error('mgv2:BridgeAlreadyBound', 'This source is already bound to a session.'); end
            obj.EvidenceFcn = provider;
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

        function ins = inspect(obj, eventId)
            %INSPECT Verified evidence for one listed event, from its exact references. Nothing is ever substituted.
            arguments
                obj
                eventId (1,1) string
            end
            if isempty(obj.Detector), error('mgv2:BridgeNotBound', 'Bind the source before inspecting events.'); end
            if isempty(obj.EvidenceFcn), error('mgv2:EvidenceLogUnavailable', 'Event %s cannot be verified: no producer sensor log is available.', eventId); end
            c = obj.evidenceContext();
            if c.generation ~= obj.BoundGeneration || c.run_id ~= obj.Detector.RunId
                error('mgv2:BridgeRunMismatch', 'Event %s belongs to an earlier run than the one the session shows.', eventId);
            end
            if obj.AsOfTick < 0, obj.rebuild(); end
            E = obj.RawEvents; k = [];
            if ~isempty(E), k = find([E.event_id] == eventId); end
            if ~isscalar(k), error('mgv2:EventNotFound', 'Event %s is not in the current detector output.', eventId); end
            asOf = obj.AsOfTick; basis = "LISTED";
            try
                ins = mgv2.bridge.checkEvidence(E(k), obj.Detector, c.sensor_log, c.run_id);
            catch err
                if err.identifier ~= "mgv2:EvidenceMissing", rethrow(err); end
                % The detector replaced this event's retained records after it was listed. Read the same event id from
                % the current detector output, without touching the refresh schedule. All checks apply again.
                obj.Stats.inspect_current_reads = obj.Stats.inspect_current_reads + 1;
                E = obj.Detector.events(); k = [];
                if ~isempty(E), k = find([E.event_id] == eventId); end
                if ~isscalar(k), error('mgv2:EventNotFound', 'Event %s is no longer in the current detector output.', eventId); end
                ins = mgv2.bridge.checkEvidence(E(k), obj.Detector, c.sensor_log, c.run_id);
                asOf = obj.clockTick(); basis = "CURRENT";
            end
            ins.run_id = c.run_id; ins.record_basis = basis; ins.events_as_of_tick = asOf; ins.events_as_of_t_s = asOf * obj.Detector.Dt;
            ins.current_tick = c.tick; ins.stale_ticks = c.tick - asOf;
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
            obj.CoverageKey = []; obj.EventKey = []; obj.ValidatedEvents = []; obj.BoundGeneration = NaN;
            obj.LayerRevision = 0; obj.CoverageRev = 0; obj.EventRev = 0;     % a same-seed run gives identical layers
        end

        function c = evidenceContext(obj)
            try
                c = obj.EvidenceFcn();
            catch err
                error('mgv2:EvidenceLogUnavailable', 'The session gave no sensor log: %s', err.message);
            end
            need = ["run_id","generation","state","tick","sensor_log"];
            if ~isstruct(c) || ~isscalar(c) || ~all(isfield(c, need)) || ~istable(c.sensor_log)
                error('mgv2:EvidenceLogUnavailable', 'The session gave no usable sensor log.');
            end
        end

        function tf = providerIsLive(obj)
            tf = false; if isempty(obj.EvidenceFcn), return; end
            try
                obj.EvidenceFcn(); tf = true;
            catch
            end
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
            if isempty(obj.EvidenceFcn), ended = obj.Terminal || held;
            else, ended = obj.Terminal || obj.evidenceContext().state ~= "ACTIVE";
            end
            if obj.AsOfTick < 0 || tick - obj.AsOfTick >= obj.RefreshTicks || ended, obj.rebuild(); end
        end

        function rebuild(obj)
            if ~obj.Dirty, return; end
            t0 = tic; d = obj.Detector;
            E = d.events(); t1 = tic;
            [ev, rej] = mgv2.bridge.toUiEvents(E, d.RunId, d, obj.ValidatedEvents);
            ev = mgv2.ui.validateEvents(ev, d.RunId);
            if isempty(rej), raw = E; else, raw = E(~ismember([E.event_id], rej)); end
            ms2 = 1e3 * toc(t1); t2 = tic;
            S = obj.Map.snapshot();
            key = S.cell_state; if ~isequal(key, obj.CoverageKey), obj.CoverageKey = key; obj.LayerRevision = obj.LayerRevision + 1; obj.CoverageRev = obj.LayerRevision; end
            key = obj.eventKey(ev); if ~isequal(key, obj.EventKey), obj.EventKey = key; obj.LayerRevision = obj.LayerRevision + 1; obj.EventRev = obj.LayerRevision; end
            L = mgv2.bridge.toMapLayers(S, ev, obj.CoverageRev, obj.EventRev);
            L = mgv2.ui.validateMapLayers(L);
            ms3 = 1e3 * toc(t2);
            obj.RawEvents = raw; obj.UiEvents = ev; obj.Layers = L; obj.Rejected = rej;   % all or nothing, so inspect matches the list
            obj.AsOfTick = obj.clockTick(); obj.AsOfTime = obj.AsOfTick * d.Dt; obj.Dirty = false;
            st = obj.Stats; st.rebuilds = st.rebuilds + 1; n = st.rebuilds;
            st.rebuild_ms(n, 1) = 1e3 * toc(t0); st.rebuild_tick(n, 1) = obj.AsOfTick; st.rebuild_events(n, 1) = numel(ev);
            st.convert_ms(n, 1) = ms2; st.layers_ms(n, 1) = ms3; obj.Stats = st;
        end
    end

    methods (Static, Access = private)
        function s = newStats()
            e = zeros(0, 1);
            s = struct('inspect_current_reads', 0, 'samples', 0, 'samples_refused', 0, 'samples_unbound', 0, 'poses', 0, 'binds', 0, 'requests', 0, 'rebuilds', 0, 'resets', 0, ...
                'on_sample_total_ms', 0, 'on_sample_max_ms', 0, 'rebuild_ms', e, 'rebuild_tick', e, 'rebuild_events', e, 'convert_ms', e, 'layers_ms', e);
        end

        function k = eventKey(ev)
            if isempty(ev), k = zeros(0, 3); else, k = [[ev.x_est_m]' [ev.y_est_m]' [ev.model_score]']; end
        end
    end
end
