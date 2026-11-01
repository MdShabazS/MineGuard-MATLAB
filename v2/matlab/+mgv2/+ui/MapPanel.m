classdef MapPanel < mgv2.ui.PanelBase
    %MAPPANEL Offline local ENU mission map: terrain, boundary, home, planned and flown route, UAV, RGB footprint.
    %   It needs no internet or map toolbox. Coverage and suspect overlays come only from V2-006 through view.layers;
    %   this panel computes neither. Unobserved ground is never coloured as cleared.
    properties (SetAccess = private, Transient, NonCopyable)
        Axes; H = struct(); LayerHandles = struct(); LayerRevisions = struct()
    end
    properties (Access = private)
        Flown; NFlown = 0; LastTick = -1; LastFootprint = ""
    end
    methods
        function bind(obj, world, cfg, route)
            ax = obj.Axes; hold(ax, 'on');
            obj.H.terrain = image(ax, world.x, world.y, reshape(world.vertex_rgb, numel(world.y), numel(world.x), 3), 'AlphaData', 0.62, 'Tag', 'map_terrain');
            ax.YDir = 'normal'; axis(ax, 'equal');
            e = world.config.extent_enu_m; xlim(ax, e(1, :)); ylim(ax, e(2, :));
            P = [cfg.survey_polygon_enu_m; cfg.survey_polygon_enu_m(1, :)];
            obj.H.boundary = plot(ax, P(:, 1), P(:, 2), '-', 'Color', [1 0.82 0.10], 'LineWidth', 2, 'DisplayName', 'survey boundary', 'Tag', 'map_boundary');
            obj.H.route = plot(ax, route.xy(:, 1), route.xy(:, 2), '--', 'Color', [1 1 1], 'LineWidth', 1, 'DisplayName', 'planned route', 'Tag', 'map_route');
            cap = ceil(cfg.constraints.timeout_s / cfg.dt_s) + 2; obj.Flown = nan(cap, 2);
            obj.H.flown = plot(ax, NaN, NaN, '-', 'Color', [0.15 0.45 1], 'LineWidth', 1.8, 'DisplayName', 'flown route', 'Tag', 'map_flown');
            obj.H.footprint = patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', [0.3 0.9 1], 'FaceAlpha', 0.2, 'EdgeColor', [0.3 0.9 1], 'DisplayName', 'RGB footprint', 'Tag', 'map_footprint');
            obj.H.home = plot(ax, cfg.home_enu_m(1), cfg.home_enu_m(2), 's', 'MarkerSize', 9, 'MarkerFaceColor', [0.95 0.95 0.2], 'MarkerEdgeColor', 'k', 'DisplayName', 'home', 'Tag', 'map_home');
            obj.H.heading = plot(ax, NaN, NaN, '-', 'Color', [1 0.3 0.1], 'LineWidth', 2, 'HandleVisibility', 'off', 'Tag', 'map_heading');
            obj.H.uav = plot(ax, NaN, NaN, 'o', 'MarkerSize', 8, 'MarkerFaceColor', [1 0.3 0.1], 'MarkerEdgeColor', 'w', 'DisplayName', 'UAV', 'Tag', 'map_uav');
            obj.H.legend = legend(ax, [obj.H.boundary obj.H.route obj.H.flown obj.H.footprint obj.H.home obj.H.uav], 'Location', 'eastoutside', 'TextColor', 'w', ...
                'Color', [0.1 0.11 0.13], 'FontSize', 9);
            xlabel(ax, 'E [m]'); ylabel(ax, 'N [m]');
            set(ax, 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w', 'Layer', 'top', 'Box', 'on');
        end

        function present(obj, view)
            p = view.pose; xy = p.position_enu_m(1:2);
            if double(p.tick_id) ~= obj.LastTick
                obj.LastTick = double(p.tick_id); obj.NFlown = obj.NFlown + 1; obj.Flown(obj.NFlown, :) = xy;
                n = obj.NFlown;
                set(obj.H.flown, 'XData', obj.Flown(1:n, 1), 'YData', obj.Flown(1:n, 2));
                set(obj.H.uav, 'XData', xy(1), 'YData', xy(2));
                set(obj.H.heading, 'XData', xy(1) + [0 6 * cos(p.yaw_rad)], 'YData', xy(2) + [0 6 * sin(p.yaw_rad)]);
            end
            s = view.samples.RGB_NADIR;
            if ~isempty(s) && s.frame_id ~= obj.LastFootprint
                obj.LastFootprint = s.frame_id;
                if s.valid && size(s.footprint_enu_m, 1) >= 3
                    set(obj.H.footprint, 'XData', s.footprint_enu_m(:, 1), 'YData', s.footprint_enu_m(:, 2));
                else
                    set(obj.H.footprint, 'XData', NaN, 'YData', NaN);
                end
            end
            obj.drawLayers(view.layers);
            ov = "anomaly overlays: " + view.source.status_text;
            obj.setStatus(sprintf("OFFLINE LOCAL ENU | t=%.2f s | E %.1f N %.1f m | %s", p.t_s, xy, ov), "NONE");
        end

        function resetDisplay(obj)
            obj.NFlown = 0; obj.LastTick = -1; obj.Flown(:) = NaN; obj.LastFootprint = "";
            set(obj.H.flown, 'XData', NaN, 'YData', NaN);
            f = fieldnames(obj.LayerHandles);
            for k = 1:numel(f), delete(obj.LayerHandles.(f{k})); end
            obj.LayerHandles = struct(); obj.LayerRevisions = struct();
        end
    end
    methods (Access = protected)
        function buildBody(obj)
            obj.TitleLabel.Text = 'MISSION MAP [SIMULATED, VIRTUAL COORDINATES]';
            obj.Axes = obj.makeAxes();
        end
    end
    methods (Access = private)
        function drawLayers(obj, L)
            live = strings(0);
            for k = 1:numel(L)
                f = matlab.lang.makeValidName(char(L(k).id)); live(end+1) = f; %#ok<AGROW>
                if isfield(obj.LayerRevisions, f) && isequal(obj.LayerRevisions.(f), L(k).revision), continue; end
                if isfield(obj.LayerHandles, f), delete(obj.LayerHandles.(f)); end
                obj.LayerHandles.(f) = obj.drawLayer(L(k)); obj.LayerRevisions.(f) = L(k).revision;
            end
            for f = setdiff(string(fieldnames(obj.LayerHandles))', live)
                delete(obj.LayerHandles.(f)); obj.LayerHandles = rmfield(obj.LayerHandles, f); obj.LayerRevisions = rmfield(obj.LayerRevisions, f);
            end
        end

        function h = drawLayer(obj, l)
            ax = obj.Axes; x = l.x_enu_m; y = l.y_enu_m; tag = "layer_" + string(l.id);
            switch string(l.kind)
                case "points", h = plot(ax, x, y, 'd', 'MarkerSize', 9, 'MarkerFaceColor', l.color, 'MarkerEdgeColor', 'k', 'HandleVisibility', 'off', 'Tag', tag);
                case "polyline", h = plot(ax, x, y, '-', 'Color', l.color, 'LineWidth', 1.5, 'HandleVisibility', 'off', 'Tag', tag);
                case "polygon", h = patch(ax, 'XData', x, 'YData', y, 'FaceColor', l.color, 'FaceAlpha', 0.3, 'EdgeColor', l.color, 'HandleVisibility', 'off', 'Tag', tag);
                case "raster", h = image(ax, x, y, l.cdata, 'AlphaData', l.alpha, 'HandleVisibility', 'off', 'Tag', tag);
            end
        end
    end
end
