classdef MapView < handle
    %MAPVIEW Offline 2-D mission map display for a mgv2.map.MissionMap (axes or uiaxes). SIMULATED.
    %   v = mgv2.map.MapView(ax, world, missionMap)     draws the static layers once
    %   v.refresh()                                      updates coverage, route, pose, footprints, events
    %   Base map: the LOCAL synthetic terrain (albedo x hillshade), never online/satellite tiles, so it works
    %   offline and the title says so (AC-009). Layers: cell state overlay (MissionMap.StateNames), survey
    %   boundary, home, planned route (dashed), actual route, current pose and heading, the latest RGB /
    %   thermal footprints (dashed when the frame was invalid), SUSPECTED event markers with a 1-sigma
    %   uncertainty circle and event id.
    properties (SetAccess = private)
        Ax; Map; H
    end
    properties (Constant)
        StateRGBA = [0 0 0 0; 0.95 0.95 0.95 0.18; 0.55 0.55 0.95 0.30; 0.95 0.35 0.10 0.40; 0.10 0.75 0.95 0.30]
    end

    methods
        function v = MapView(ax, world, missionMap)
            v.Ax = ax; v.Map = missionMap; m = missionMap;
            nx = numel(world.x); ny = numel(world.y);
            A = reshape(world.vertex_rgb, ny, nx, 3);
            [gx, gy] = gradient(world.Z, world.x(2) - world.x(1));
            sh = 0.75 + 0.25 * max(min((-gx * 0.7 + gy * 0.7) * 2 + 0.5, 1), 0);   % simple NW hillshade
            hold(ax, 'on');
            image(ax, world.x, world.y, A .* sh);
            v.H.cells = image(ax, m.Xc, m.Yc, zeros(numel(m.Yc), numel(m.Xc), 3), 'AlphaData', zeros(numel(m.Yc), numel(m.Xc)));
            b = [m.Boundary; m.Boundary(1, :)];
            plot(ax, b(:,1), b(:,2), '-', 'Color', [1 0.55 0.1], 'LineWidth', 2, 'DisplayName', 'survey boundary');
            plot(ax, m.PlannedRoute(:,1), m.PlannedRoute(:,2), '--', 'Color', [1 1 1], 'LineWidth', 1, 'DisplayName', 'planned route');
            plot(ax, m.Home(1), m.Home(2), 's', 'MarkerSize', 10, 'MarkerFaceColor', [0.2 0.2 0.2], 'MarkerEdgeColor', 'w', 'DisplayName', 'home');
            v.H.route = plot(ax, NaN, NaN, '-', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.6, 'DisplayName', 'actual route');
            v.H.fpRgb = plot(ax, NaN, NaN, '-', 'Color', [0 0.9 1], 'LineWidth', 1.2, 'DisplayName', 'RGB footprint');
            v.H.fpTh = plot(ax, NaN, NaN, '-', 'Color', [1 0.2 0.2], 'LineWidth', 1.2, 'DisplayName', 'thermal footprint');
            v.H.pose = plot(ax, NaN, NaN, 'o', 'MarkerSize', 8, 'MarkerFaceColor', [1 0.9 0], 'MarkerEdgeColor', 'k', 'DisplayName', 'aircraft');
            v.H.head = quiver(ax, NaN, NaN, NaN, NaN, 0, 'Color', 'k', 'LineWidth', 1.5, 'MaxHeadSize', 2, 'HandleVisibility', 'off');
            v.H.ev = plot(ax, NaN, NaN, 'd', 'MarkerSize', 8, 'MarkerFaceColor', [0.9 0 0.9], 'MarkerEdgeColor', 'w', 'DisplayName', 'SUSPECTED event');
            v.H.evc = plot(ax, NaN, NaN, '-', 'Color', [0.9 0 0.9], 'HandleVisibility', 'off');
            v.H.evt = gobjects(0);
            for k = 2:5
                c = v.StateRGBA(k, 1:3);
                patch(ax, NaN, NaN, c, 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', char(m.StateLabels(k)));
            end
            axis(ax, 'equal'); xlim(ax, m.Bounds(1, :)); ylim(ax, m.Bounds(2, :)); set(ax, 'YDir', 'normal', 'Layer', 'top');
            xlabel(ax, 'x east (m, ENU local virtual)'); ylabel(ax, 'y north (m)');
            title(ax, {'MISSION MAP (SIMULATED) - OFFLINE LOCAL BASE MAP: synthetic terrain, no satellite tiles', ...
                'observed = valid synthetic sensor evidence only; events are SUSPECTED (uncalibrated)'}, 'FontSize', 9);
            legend(ax, 'Location', 'southoutside', 'NumColumns', 3, 'FontSize', 7, 'AutoUpdate', 'off');
            v.refresh();
        end

        function refresh(v)
            m = v.Map; C = double(m.cellState()) + 1; rgba = v.StateRGBA;
            img = reshape(rgba(C(:), 1:3), [size(C) 3]);
            set(v.H.cells, 'CData', img, 'AlphaData', reshape(rgba(C(:), 4), size(C)));
            r = m.Route; set(v.H.route, 'XData', r.x, 'YData', r.y);
            if ~isempty(r.x)
                set(v.H.pose, 'XData', r.x(end), 'YData', r.y(end));
                h = r.heading_deg(end);
                if isfinite(h), set(v.H.head, 'XData', r.x(end), 'YData', r.y(end), 'UData', 4 * sind(h), 'VData', 4 * cosd(h)); end
            end
            F = m.Footprints;
            set(v.H.fpRgb, 'XData', NaN, 'YData', NaN); set(v.H.fpTh, 'XData', NaN, 'YData', NaN);
            for id = ["RGB_NADIR","THERMAL_LWIR"]
                k = find([F.sensor_id] == id, 1, 'last');
                if isempty(k) || size(F(k).polygon_enu_m, 1) < 3, continue; end
                p = [F(k).polygon_enu_m; F(k).polygon_enu_m(1, :)]; hh = v.H.fpRgb; if id == "THERMAL_LWIR", hh = v.H.fpTh; end
                ls = '-'; if ~F(k).valid, ls = ':'; end
                set(hh, 'XData', p(:,1), 'YData', p(:,2), 'LineStyle', ls);
            end
            E = m.Events; delete(v.H.evt); v.H.evt = gobjects(0);
            if isempty(E)
                set(v.H.ev, 'XData', NaN, 'YData', NaN); set(v.H.evc, 'XData', NaN, 'YData', NaN);
            else
                x = [E.x_est_m]; y = [E.y_est_m]; s = max([E.uncertainty_m], 0.05); th = linspace(0, 2 * pi, 25)';
                cx = [x + s .* cos(th); nan(1, numel(x))]; cy = [y + s .* sin(th); nan(1, numel(x))];
                set(v.H.ev, 'XData', x, 'YData', y); set(v.H.evc, 'XData', cx(:), 'YData', cy(:));
                if numel(E) <= 30
                    v.H.evt = text(v.Ax, x + 0.8, y + 0.8, [E.event_id], 'FontSize', 7, 'Color', [0.9 0 0.9], 'Interpreter', 'none');
                end
            end
        end
    end
end
