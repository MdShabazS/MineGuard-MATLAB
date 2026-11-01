classdef V2007TestDoubleSource < mgv2.ui.AnomalySource
    %V2007TESTDOUBLESOURCE Test double for the V2-006 seam. It is NOT a detector and is never used by the application.
    %   The event and layer values are arbitrary test inputs set by the test itself; they only exercise the
    %   validation and display path and carry no scientific meaning.
    properties
        Events = struct([]); Layers = struct([]); Seen = strings(0); Resets = 0
    end
    methods
        function onSample(obj, s), obj.Seen(end+1) = s.frame_id; end
        function ev = suspectedEvents(obj), ev = obj.Events; end
        function L = mapLayers(obj), L = obj.Layers; end
        function i = sourceInfo(~), i = struct('connected', true, 'detector_version', "test-double", 'status_text', "TEST DOUBLE"); end
        function reset(obj), obj.Resets = obj.Resets + 1; obj.Seen = strings(0); end
    end
    methods (Static)
        function e = event(varargin)
            e = struct('event_id', "T-1", 'run_id', "r", 't_s', 1, 'x_est_m', 2, 'y_est_m', 3, 'model_score', 0.5, 'confidence_kind', "UNCALIBRATED", ...
                'modality_flags', "RGB", 'evidence_refs', {{}}, 'uncertainty_m', NaN, 'status', "SUSPECTED", 'detector_version', "test-double");
            for k = 1:2:numel(varargin), e.(varargin{k}) = varargin{k+1}; end
        end
        function l = layer(varargin)
            l = struct('id', "cov", 'display_name', "coverage", 'kind', "points", 'revision', 1, 'color', [1 0 1], 'x_enu_m', [1 2], 'y_enu_m', [3 4]);
            for k = 1:2:numel(varargin), l.(varargin{k}) = varargin{k+1}; end
        end
    end
end
