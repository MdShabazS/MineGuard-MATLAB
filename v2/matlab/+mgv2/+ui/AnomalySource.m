classdef (Abstract) AnomalySource < handle
    %ANOMALYSOURCE The only seam between the mission-control UI and V2-006 output. SIMULATION ONLY.
    %   A V2-006 adapter subclasses this; the UI never calls detector or map code directly.
    %   onSample(obj, sample)  called once for every emitted public V2-005 sample, in engine order
    %   ev = suspectedEvents(obj)       SuspectedEvent struct array (see mgv2.ui.validateEvents), estimated positions only
    %   L = mapLayers(obj)     overlay layers (see mgv2.ui.validateMapLayers), e.g. coverage cell states
    %   i = sourceInfo(obj)    struct: connected (logical), detector_version (string), status_text (string)
    %                          optional events_as_of_tick and events_as_of_t_s: the tick and time the events and layers
    %                          were computed at. The tick must change whenever their content changes: the session then
    %                          re-validates and redraws only on a change, and the operator sees the age.
    %   reset(obj)             clear all run state; called when the operator resets the scenario
    %   The adapter receives public samples only and must not be given target truth.
    %
    %   Optional, with harmless defaults, so an existing adapter keeps working:
    %   bindRun(obj, world, missionCfg)  the session's own public world and mission, once per engine, before its first
    %                                    pose and sample. Also called after reset and after a scenario change.
    %   onPose(obj, pose)                every executed PoseSample exactly once, in order, starting with tick 0
    %   ins = inspect(obj, eventId)      checksum-verified evidence (see mgv2.ui.validateInspection), or an error.
    %                                    Never a substitute frame.
    %   bindEvidence(obj, provider)      once per session, before the first bindRun. c = provider() returns a read-only
    %                                    copy of the session's current run (see MissionSession.evidenceContext).
    methods (Abstract)
        onSample(obj, sample)
        ev = suspectedEvents(obj)
        L = mapLayers(obj)
        i = sourceInfo(obj)
        reset(obj)
    end
    methods
        function bindRun(~, ~, ~), end
        function onPose(~, ~), end
        function bindEvidence(~, ~), end
        function ins = inspect(~, eventId) %#ok<STOUT>
            error('mgv2:InspectUnavailable', 'This anomaly source provides no evidence inspection for event %s.', string(eventId));
        end
    end
end
