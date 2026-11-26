classdef MissionOverlay < handle
    %MISSIONOVERLAY VIRTUAL V2.1 mission drawn on the BITM satellite preview, moving with the mission clock (V22-T5).
    %   ov = mgv22.sat.MissionOverlay(preview, pub)   preview: open mgv22.sat.SatellitePreview; pub: V2.1 PublicMissionConfig
    %   ov.update(pose)              pose with tick_id and position_enu_m (e.g. engine snapshot) moves the drone and trail
    %   ov.syncFromPoseLog(T, tick)  replay/tests: show the pose log as it was at a tick
    %   ov.bindEngine(eng)           follow a MissionEngine tick by tick (safe after delete)
    %   ov.restart()                 clear the trail and put the drone back home (a new engine: reset, new run, replay)
    %   Uses ONLY public mission geometry (checked with mgv21.scenario.assertPublic) and poses. Never draws targets,
    %   truth, suspected events or any other marker on real imagery; every layer is labelled VIRTUAL.
    %   ENU (0,0) of the simulation is placed at the site anchor; altitude is not drawn.

    properties (SetAccess = private)
        Preview
        Boundary = []; Route = []; Home = []; Drone = []; Trail = []
        BoundaryLLA = zeros(0, 3); RouteLLA = zeros(0, 3); HomeLLA = zeros(0, 3)
        TrailLLA = zeros(0, 2)
        LastTick = NaN
    end
    properties (Access = private)
        Bound = false
    end

    methods
        function obj = MissionOverlay(preview, pub)
            if ~(isa(preview, 'mgv22.sat.SatellitePreview') && preview.isOpen())
                error('mgv22:PreviewNotOpen', 'Open the satellite preview before adding the mission overlay.');
            end
            mgv21.scenario.assertPublic(pub, "PublicMissionConfig");          % no truth, targets or private names
            obj.Preview = preview;
            m = pub.mission; anchor = preview.Site.anchor_lla;
            route = mgv2.mission.buildRoute(m, mgv2.mission.planSurvey(m));
            to3 = @(xy) [double(xy), zeros(size(xy, 1), 1)];
            poly = m.survey_polygon_enu_m; poly = [poly; poly(1, :)];
            obj.BoundaryLLA = mgv22.geo.enuToWgs84(to3(poly), anchor);
            obj.RouteLLA = mgv22.geo.enuToWgs84(to3(route.xy), anchor);
            obj.HomeLLA = mgv22.geo.enuToWgs84(to3(m.home_enu_m), anchor);
            ax = preview.Axes; held = ishold(ax); hold(ax, 'on');
            v = preview.Site.virtual_label;
            obj.Boundary = geoplot(ax, obj.BoundaryLLA(:, 1), obj.BoundaryLLA(:, 2), '-', 'Color', [1 0.77 0.12], 'LineWidth', 2, ...
                'DisplayName', v + " survey boundary");
            obj.Route = geoplot(ax, obj.RouteLLA(:, 1), obj.RouteLLA(:, 2), '--', 'Color', [0.10 0.85 0.93], 'LineWidth', 1.5, ...
                'DisplayName', v + " planned route");
            obj.Home = geoplot(ax, obj.HomeLLA(1), obj.HomeLLA(2), 'p', 'MarkerSize', 12, 'MarkerFaceColor', [0.98 0.81 0.25], ...
                'MarkerEdgeColor', 'k', 'DisplayName', v + " home pad");
            obj.Trail = geoplot(ax, NaN, NaN, '-', 'Color', [1 1 1], 'LineWidth', 1.2, 'DisplayName', "Simulated drone trail (" + v + ")");
            obj.Drone = geoplot(ax, obj.HomeLLA(1), obj.HomeLLA(2), 'o', 'MarkerSize', 9, 'MarkerFaceColor', [0.95 0.25 0.25], ...
                'MarkerEdgeColor', 'w', 'DisplayName', "Simulated drone (" + v + ")");
            if ~held, hold(ax, 'off'); end
            legend(ax, [obj.Boundary obj.Route obj.Home obj.Drone obj.Trail], 'Location', 'northeast', 'TextColor', 'w', ...
                'Color', [0.08 0.10 0.13], 'EdgeColor', [0.6 0.6 0.6]);
        end

        function update(obj, pose)
            if ~isgraphics(obj.Drone), return; end                 % the preview window was closed: nothing to draw
            ll = mgv22.sat.MissionOverlay.poseLL(pose, obj.Preview.Site.anchor_lla);
            mgv21.scenario.assertPublic(pose, "pose");
            if double(pose.tick_id) <= obj.LastTick, obj.TrailLLA = zeros(0, 2); end   % a reset or new run starts a new trail
            obj.TrailLLA(end+1, :) = ll;
            obj.LastTick = double(pose.tick_id);
            obj.draw(ll);
        end

        function syncFromPoseLog(obj, T, tick)
            if ~(istable(T) && all(ismember({'tick_id', 'position_enu_m'}, T.Properties.VariableNames)))
                error('mgv22:InvalidPose', 'Pose log must be a table with tick_id and position_enu_m.');
            end
            rows = find(T.tick_id <= tick);
            if isempty(rows), error('mgv22:InvalidPose', 'No pose at or before tick %g.', tick); end
            P = T.position_enu_m(rows, :);
            lla = mgv22.geo.enuToWgs84([P(:, 1:2), zeros(numel(rows), 1)], obj.Preview.Site.anchor_lla);
            obj.TrailLLA = lla(:, 1:2);
            obj.LastTick = double(T.tick_id(rows(end)));
            obj.draw(obj.TrailLLA(end, :));
        end

        function restart(obj)
            obj.TrailLLA = zeros(0, 2); obj.LastTick = NaN;
            if ~isempty(obj.HomeLLA), obj.draw(obj.HomeLLA(1, 1:2)); end
        end

        function bindEngine(obj, eng)
            if obj.Bound, error('mgv22:AlreadyBound', 'This overlay already follows an engine; create a new overlay for another run.'); end
            eng.subscribe(@(p) mgv22.sat.MissionOverlay.forward(obj, p));
            obj.Bound = true;
        end

        function delete(obj)
            h = [obj.Boundary obj.Route obj.Home obj.Drone obj.Trail];
            delete(h(isgraphics(h)));
        end
    end

    methods (Access = private)
        function draw(obj, ll)
            if ~isgraphics(obj.Drone), return; end
            set(obj.Drone, 'LatitudeData', ll(1), 'LongitudeData', ll(2));
            set(obj.Trail, 'LatitudeData', obj.TrailLLA(:, 1), 'LongitudeData', obj.TrailLLA(:, 2));
        end
    end

    methods (Static, Access = private)
        function ll = poseLL(pose, anchor)
            if ~(isstruct(pose) && isscalar(pose) && all(isfield(pose, {'tick_id', 'position_enu_m'})) && numel(pose.position_enu_m) >= 2)
                error('mgv22:InvalidPose', 'A pose needs tick_id and position_enu_m.');
            end
            p = double(pose.position_enu_m(:)');
            lla = mgv22.geo.enuToWgs84([p(1:2) 0], anchor);
            ll = lla(1:2);
        end

        function forward(obj, pose)
            if isvalid(obj) && isgraphics(obj.Drone), obj.update(pose); end   % the engine may outlive the overlay or its window
        end
    end
end
