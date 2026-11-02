classdef V2007TestDoubleSource < mgv2.ui.AnomalySource
    %V2007TESTDOUBLESOURCE Test double for the V2-006 seam. It is NOT a detector and is never used by the application.
    %   The event and layer values are arbitrary test inputs set by the test itself; they only exercise the
    %   validation and display path and carry no scientific meaning.
    properties
        Events = struct([]); Layers = struct([]); Seen = strings(0); Resets = 0
        Binds = 0; BoundWorld = []; BoundMission = []; Poses = zeros(0, 1); Reads = 0; Info = struct()
        Inspection = []; InspectError = ""
    end
    methods
        function onSample(obj, s), obj.Seen(end+1) = s.frame_id; end
        function ev = suspectedEvents(obj)
            %SUSPECTEDEVENTS The placeholder run "r" stands for the run this double is bound to.
            obj.Reads = obj.Reads + 1; ev = obj.Events;
            for k = 1:numel(ev), if ev(k).run_id == "r", ev(k).run_id = obj.BoundMission.run_id; end, end
        end
        function L = mapLayers(obj), L = obj.Layers; end
        function i = sourceInfo(obj)
            i = struct('connected', true, 'detector_version', "test-double", 'status_text', "TEST DOUBLE");
            for f = string(fieldnames(obj.Info))', i.(f) = obj.Info.(f); end
        end
        function reset(obj), obj.Resets = obj.Resets + 1; obj.Seen = strings(0); obj.Poses = zeros(0, 1); end
        function bindRun(obj, world, cfg), obj.Binds = obj.Binds + 1; obj.BoundWorld = world; obj.BoundMission = cfg; end
        function onPose(obj, p), obj.Poses(end+1, 1) = double(p.tick_id); end
        function ins = inspect(obj, ~)
            if strlength(obj.InspectError) > 0, error('mgv2:EvidenceMismatch', '%s', obj.InspectError); end
            ins = obj.Inspection;
        end
    end
    methods (Static)
        function e = event(varargin)
            e = struct('event_id', "T-1", 'run_id', "r", 't_s', 1, 'x_est_m', 2, 'y_est_m', 3, 'model_score', 0.5, 'confidence_kind', "UNCALIBRATED", ...
                'modality_flags', "RGB", 'evidence_refs', {{}}, 'uncertainty_m', NaN, 'status', "SUSPECTED", 'detector_version', "test-double");
            for k = 1:2:numel(varargin), e.(varargin{k}) = varargin{k+1}; end
        end
        function ins = inspection(varargin)
            %INSPECTION Arbitrary crops and values that only exercise the display path.
            item = @(sensor, crop) struct('ref_id', "E-" + sensor, 'frame_id', "r/" + sensor + "/000001", 'sensor_id', sensor, 'tick_id', 4, 'pose_id', 4, 't_s', 0.2, ...
                'sample_checksum', "abc", 'verified_against_sensor_log', true, 'crop', crop);
            ins = struct('event_id', "T-1", 'status', "SUSPECTED", 'simulated', true, 'time_window_s', [0.2 1], 'sensors_used', ["RGB_NADIR" "THERMAL_LWIR"], ...
                'score_text', "0.500 (uncalibrated)", 'estimated_enu_m', [2 3 0], 'uncertainty_m', 1.5, 'missing_modalities', strings(0, 1), ...
                'items', [item("RGB_NADIR", uint8(100 * ones(9, 9, 3))), item("THERMAL_LWIR", 290 + magic(9) / 100)]);
            for k = 1:2:numel(varargin), ins.(varargin{k}) = varargin{k+1}; end
        end
        function l = layer(varargin)
            l = struct('id', "cov", 'display_name', "coverage", 'kind', "points", 'revision', 1, 'color', [1 0 1], 'x_enu_m', [1 2], 'y_enu_m', [3 4]);
            for k = 1:2:numel(varargin), l.(varargin{k}) = varargin{k+1}; end
        end
    end
end
