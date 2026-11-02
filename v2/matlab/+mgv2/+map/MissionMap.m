classdef MissionMap < handle
    %MISSIONMAP Offline mission map data model: plan, actual route, tick-tied footprints, coverage cells, events.
    %   m = mgv2.map.MissionMap(world, missionCfg)              1 m cells over the mission bounds
    %   m = mgv2.map.MissionMap(world, missionCfg, CellSize=0.5)
    %   m.attach(engine, sensorSystem)   follow every executed pose and every emitted public sample
    %   m.addPose(pose); m.addSample(sample); m.setEvents(E)
    %   S = m.snapshot()                 plain public struct (mg-v2-map/1.0), passes mgv2.sensors.assertPublic
    %
    %   Cell state (display precedence, highest first), all relative to SENSOR EVIDENCE ACQUISITION only:
    %     4 VALID_OBSERVED     >= 1 valid RGB or thermal frame footprint covered the cell centre
    %     3 INVALID_OBSERVED   only invalid frames (dropout, no intersection, ...) were scheduled over it
    %     2 TRAVERSED          the aircraft passed over the cell but no camera frame covered it
    %     1 PLANNED            inside the survey boundary, not yet observed
    %     0 UNOBSERVED         outside the plan and never observed
    %   Per-modality valid counts (RGB, thermal, LiDAR returns) and invalid counts are kept separately.
    %   VALID_OBSERVED means "a valid synthetic sensor sample exists"; it never means hazard-free or released
    %   land (V2-004 §1, IMAS 07.11). Footprints are stored with the sample's tick_id, t_s, pose_id, frame_id.
    %   Invalid camera frames get their NOMINAL footprint from the public camera geometry at the sample's
    %   T_world_sensor (mgv2.scene.cameraFootprint) so the operator sees where data is missing.
    %   Works fully offline: the base map is the local synthetic terrain (mgv2.map.MapView), no tiles.

    properties (SetAccess = private)
        CellSize; Xc; Yc                 % cell centres (m)
        Boundary; Home; PlannedRoute; Bounds
        Planned                          % logical [ny nx]
        Traversed                        % count
        ValidRGB; ValidThermal; LidarReturns; Invalid
        Route                            % actual route: t_s, tick_id, x, y, z, heading_deg
        Footprints                       % struct array (tick-tied)
        Events                           % last validated SUSPECTED events
        RunId; ScenarioId
    end
    properties (Access = private)
        World
    end
    properties (Constant)
        StateNames = ["UNOBSERVED","PLANNED","TRAVERSED","INVALID_OBSERVED","VALID_OBSERVED"]
        StateLabels = ["Unobserved (no plan, no data)", "Planned, no sensor data yet", "Traversed, no camera frame", ...
            "Invalid / missing sensor data", "Valid sensor observation (evidence acquisition only; says nothing about hazards)"]
    end

    methods
        function m = MissionMap(world, missionCfg, opts)
            arguments
                world struct
                missionCfg struct
                opts.CellSize (1,1) double {mustBePositive} = 1.0
            end
            mgv2.sensors.assertPublic(missionCfg, "missionConfig");
            m.World = struct('x', world.x, 'y', world.y, 'Z', world.Z);
            m.RunId = string(missionCfg.run_id); m.ScenarioId = string(missionCfg.scenario_id);
            m.CellSize = opts.CellSize; b = missionCfg.bounds_enu_m(1:2, :); m.Bounds = b;
            m.Xc = (b(1,1) + m.CellSize / 2):m.CellSize:b(1,2); m.Yc = (b(2,1) + m.CellSize / 2):m.CellSize:b(2,2);
            m.Boundary = missionCfg.survey_polygon_enu_m; m.Home = missionCfg.home_enu_m;
            cfg = mgv2.mission.validateConfig(missionCfg);
            r = mgv2.mission.buildRoute(cfg, mgv2.mission.planSurvey(cfg)); m.PlannedRoute = r.xy;
            [X, Y] = meshgrid(m.Xc, m.Yc); sz = size(X);
            m.Planned = reshape(inpolygon(X(:), Y(:), m.Boundary(:,1), m.Boundary(:,2)), sz);
            m.Traversed = zeros(sz); m.ValidRGB = zeros(sz); m.ValidThermal = zeros(sz); m.LidarReturns = zeros(sz); m.Invalid = zeros(sz);
            m.Route = struct('t_s', zeros(0, 1), 'tick_id', zeros(0, 1), 'x', zeros(0, 1), 'y', zeros(0, 1), 'z', zeros(0, 1), 'heading_deg', zeros(0, 1));
            m.Footprints = struct('sensor_id', cell(0, 1), 'frame_id', [], 'tick_id', [], 't_s', [], 'pose_id', [], 'valid', [], ...
                'invalid_reason', [], 'polygon_enu_m', [], 'nominal', []);
            m.Events = struct([]);
        end

        function attach(m, engine, sensorSystem)
            if engine.TickId == 0, m.addPose(engine.snapshot()); end
            engine.subscribe(@(p) m.addPose(p));
            if nargin > 2, sensorSystem.subscribe(@(s) m.addSample(s)); end
        end

        function addPose(m, p)
            x = p.position_enu_m;
            m.Route.t_s(end+1, 1) = p.t_s; m.Route.tick_id(end+1, 1) = double(p.tick_id);
            m.Route.x(end+1, 1) = x(1); m.Route.y(end+1, 1) = x(2); m.Route.z(end+1, 1) = x(3);
            hd = NaN; if isfield(p, 'heading_deg'), hd = p.heading_deg; end
            m.Route.heading_deg(end+1, 1) = hd;
            [i, j] = m.cellOf(x(1), x(2));
            if ~isempty(i), m.Traversed(i, j) = m.Traversed(i, j) + 1; end
        end

        function addSample(m, s)
            mgv2.sensors.validateSample(s);
            if s.sensor_id == "VIRTUAL_GNSS_INS", return; end
            poly = s.footprint_enu_m; nominal = false;
            if ~s.valid && s.sensor_id ~= "LIDAR_TERRAIN" && all(isfinite(s.T_world_sensor), 'all')
                cam = struct('width_px', s.image_width, 'height_px', s.image_height, 'fx', s.focal_lengths_px(1), ...
                    'fy', s.focal_lengths_px(2), 'cx', s.principal_point_px(1), 'cy', s.principal_point_px(2));
                [cn, ok] = mgv2.scene.cameraFootprint(m.World, cam, s.T_world_sensor);
                if ok, poly = cn(:, 1:2); nominal = true; end
            end
            m.Footprints(end+1, 1) = struct('sensor_id', s.sensor_id, 'frame_id', s.frame_id, 'tick_id', double(s.tick_id), ...
                't_s', s.t_s, 'pose_id', double(s.pose_id), 'valid', s.valid, 'invalid_reason', s.invalid_reason, ...
                'polygon_enu_m', poly, 'nominal', nominal);
            if s.sensor_id == "LIDAR_TERRAIN"
                if s.valid
                    P = s.points_enu_m(s.valid_ray_mask, :);
                    [i, j, ok] = m.cellsOfPoints(P(:,1), P(:,2));
                    m.LidarReturns = m.LidarReturns + accumarray([i(ok) j(ok)], 1, size(m.LidarReturns));
                end
                return
            end
            if size(poly, 1) < 3, return; end
            in = m.cellsInPolygon(poly);
            if ~s.valid, m.Invalid(in) = m.Invalid(in) + 1;
            elseif s.sensor_id == "RGB_NADIR", m.ValidRGB(in) = m.ValidRGB(in) + 1;
            else, m.ValidThermal(in) = m.ValidThermal(in) + 1;
            end
        end

        function setEvents(m, E)
            for k = 1:numel(E), mgv2.detect.validateEvent(E(k)); end
            m.Events = E;
        end

        function C = cellState(m)
            C = zeros(size(m.Planned), 'uint8');
            C(m.Planned) = 1; C(m.Traversed > 0) = 2; C(m.Invalid > 0) = 3; C(m.ValidRGB > 0 | m.ValidThermal > 0) = 4;
        end

        function S = snapshot(m)
            %SNAPSHOT Plain public struct for display/export (no handles, no truth; assertPublic-checked).
            C = m.cellState(); P = m.Planned; nP = nnz(P);
            pct = @(mask) 100 * nnz(mask & P) / max(nP, 1);
            cov = struct('planned_cells', nP, 'cell_size_m', m.CellSize, ...
                'valid_rgb_pct', pct(m.ValidRGB > 0), 'valid_thermal_pct', pct(m.ValidThermal > 0), ...
                'valid_lidar_pct', pct(m.LidarReturns > 0), 'valid_any_camera_pct', pct(C == 4), ...
                'invalid_only_pct', pct(C == 3), 'traversed_only_pct', pct(C == 2), 'unobserved_pct', pct(C == 1), ...
                'meaning', "percent of planned cells with valid synthetic sensor evidence; NOT detector accuracy, NOT a land-release statement");
            ev = struct('event_id', {}, 'x_est_m', {}, 'y_est_m', {}, 'uncertainty_m', {}, 'model_score', {}, 'detection_basis', {}, 'status', {});
            for k = 1:numel(m.Events)
                e = m.Events(k);
                ev(k) = struct('event_id', e.event_id, 'x_est_m', e.x_est_m, 'y_est_m', e.y_est_m, 'uncertainty_m', e.uncertainty_m, ...
                    'model_score', e.model_score, 'detection_basis', e.detection_basis, 'status', e.status); %#ok<AGROW>
            end
            S = struct('schema_version', "mg-v2-map/1.0", 'run_id', m.RunId, 'scenario_id', m.ScenarioId, 'simulated', true, ...
                'frame', "ENU local virtual frame (m); virtual geodetic origin only", ...
                'base_map', "OFFLINE LOCAL BASE MAP: synthetic terrain albedo/hillshade (no satellite or online tiles)", ...
                'boundary_enu_m', m.Boundary, 'home_enu_m', m.Home, 'planned_route_enu_m', m.PlannedRoute, 'actual_route', m.Route, ...
                'cell_x_m', m.Xc, 'cell_y_m', m.Yc, 'cell_state', C, 'state_names', m.StateNames, 'state_labels', m.StateLabels, ...
                'valid_rgb_count', m.ValidRGB, 'valid_thermal_count', m.ValidThermal, 'lidar_return_count', m.LidarReturns, ...
                'invalid_count', m.Invalid, 'traversed_count', m.Traversed, 'footprints', m.Footprints, 'events', ev, 'coverage', cov, ...
                'label_text', "SIMULATED | observed = valid synthetic sensor evidence only | events are SUSPECTED, uncalibrated");
            mgv2.sensors.assertPublic(S, "missionMap");
        end
    end

    methods (Access = private)
        function [i, j] = cellOf(m, x, y)
            j = floor((x - m.Bounds(1,1)) / m.CellSize) + 1; i = floor((y - m.Bounds(2,1)) / m.CellSize) + 1;
            if ~(i >= 1 && i <= numel(m.Yc) && j >= 1 && j <= numel(m.Xc)), i = []; j = []; end
        end

        function [i, j, ok] = cellsOfPoints(m, x, y)
            j = floor((x - m.Bounds(1,1)) / m.CellSize) + 1; i = floor((y - m.Bounds(2,1)) / m.CellSize) + 1;
            ok = i >= 1 & i <= numel(m.Yc) & j >= 1 & j <= numel(m.Xc);
        end

        function in = cellsInPolygon(m, poly)
            % linear indices of cells whose centre lies inside the polygon (bounding-box pre-selection)
            jx = find(m.Xc >= min(poly(:,1)) & m.Xc <= max(poly(:,1))); iy = find(m.Yc >= min(poly(:,2)) & m.Yc <= max(poly(:,2)));
            if isempty(jx) || isempty(iy), in = zeros(0, 1); return; end
            [J, I] = meshgrid(jx, iy);
            k = inpolygon(m.Xc(J(:))', m.Yc(I(:))', poly(:,1), poly(:,2));
            in = sub2ind(size(m.Planned), I(k), J(k));
        end
    end
end
