classdef Recorder < handle
    %RECORDER Keeps every public sample of one run in memory for export (V2-008). SIMULATION ONLY.
    %   rec = mgv2.run.Recorder(); sensorSystem.subscribe(@(s) rec.add(s));
    %   C = rec.samples("RGB_NADIR")   cell row of that sensor's samples in emission order
    %   Nothing is written to disk during a run, so recording cannot slow the clock with file I/O.
    %   Samples arrive already checked by mgv2.sensors.validateSample; the recorder neither changes nor drops any.
    %   Memory: about 0.4 MB per simulated second at the default rates (RGB 320x240 and thermal 160x120 at 5 Hz).

    properties (SetAccess = private)
        Count = 0
    end
    properties (Access = private)
        Store      % struct: sensor_id -> cell row, grown by doubling
        N          % struct: sensor_id -> samples held
    end

    methods
        function rec = Recorder()
            rec.Store = struct(); rec.N = struct();
            for id = mgv2.sensors.SensorSystem.Order, rec.Store.(id) = cell(1, 64); rec.N.(id) = 0; end
        end

        function add(rec, s)
            id = char(s.sensor_id); n = rec.N.(id) + 1;
            if n > numel(rec.Store.(id)), rec.Store.(id){2 * n} = []; end
            rec.Store.(id){n} = s; rec.N.(id) = n; rec.Count = rec.Count + 1;
        end

        function C = samples(rec, id)
            id = char(id); C = rec.Store.(id)(1:rec.N.(id));
        end
    end
end
