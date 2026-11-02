classdef (Abstract) AnomalySource < handle
    %ANOMALYSOURCE The only seam between the mission-control UI and V2-006 output. SIMULATION ONLY.
    %   A V2-006 adapter subclasses this; the UI never calls detector or map code directly.
    %   onSample(obj, sample)  called once for every emitted public V2-005 sample, in engine order
    %   ev = suspectedEvents(obj)       SuspectedEvent struct array (see mgv2.ui.validateEvents), estimated positions only
    %   L = mapLayers(obj)     overlay layers (see mgv2.ui.validateMapLayers), e.g. coverage cell states
    %   i = sourceInfo(obj)    struct: connected (logical), detector_version (string), status_text (string)
    %   reset(obj)             clear all run state; called when the operator resets the scenario
    %   The adapter receives public samples only and must not be given target truth.
    methods (Abstract)
        onSample(obj, sample)
        ev = suspectedEvents(obj)
        L = mapLayers(obj)
        i = sourceInfo(obj)
        reset(obj)
    end
end
