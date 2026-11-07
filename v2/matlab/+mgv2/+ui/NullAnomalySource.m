classdef NullAnomalySource < mgv2.ui.AnomalySource
    %NULLANOMALYSOURCE Default source until V2-006 is available: no events, no layers, never invents output.
    methods
        function onSample(~, ~), end
        function ev = suspectedEvents(~), ev = struct([]); end
        function L = mapLayers(~), L = struct([]); end
        function i = sourceInfo(~)
            i = struct('connected', false, 'detector_version', "", 'status_text', "DETECTOR NOT CONNECTED");
        end
        function reset(~), end
    end
end
