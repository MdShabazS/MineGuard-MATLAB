classdef LidarPanel < mgv2.ui.PanelBase
    %LIDARPANEL LIDAR_TERRAIN valid returns as an ENU scatter3. Invalid rays are counted, never drawn as zeros.
    properties (SetAccess = private, Transient, NonCopyable)
        Axes; Points; Overlay
    end
    properties (Access = private)
        LastFrame = ""
        Held = []        % axes limits now in use: they change only when a scan leaves them
    end
    methods
        function present(obj, view)
            st = mgv2.ui.sampleStatus("LIDAR_TERRAIN", view); s = st.sample; txt = st.text;
            if ~isempty(s)
                n = numel(s.valid_ray_mask);
                txt = sprintf("%s | %d/%d returns | %d invalid rays", txt, s.return_count, n, n - s.return_count);
                if isfinite(s.altitude_agl_m), txt = sprintf("%s | AGL(obs) %.2f m", txt, s.altitude_agl_m); end
            end
            obj.setStatus(txt, st.state);
            if isempty(s) || s.frame_id == obj.LastFrame, return; end
            obj.LastFrame = s.frame_id;
            P = s.points_enu_m(s.valid_ray_mask, :);
            if isempty(P), P = [NaN NaN NaN]; end
            set(obj.Points, 'XData', P(:, 1), 'YData', P(:, 2), 'ZData', P(:, 3), 'CData', P(:, 3));
            obj.holdLimits(P);
            if s.valid, obj.setOverlay(obj.Overlay, ''); else, obj.setOverlay(obj.Overlay, "NO VALID RETURNS: " + s.invalid_reason); end
        end
        function resetDisplay(obj)
            obj.LastFrame = ""; obj.Held = []; set(obj.Points, 'XData', NaN, 'YData', NaN, 'ZData', NaN, 'CData', NaN);
        end
    end
    methods (Access = private)
        function holdLimits(obj, P)
            %HOLDLIMITS Snap limits to a 10 m grid (2 m in height) and keep them until a scan leaves them, which avoids
            %   the tick and layout pass that automatic limits trigger on every scan.
            if any(~isfinite(P(:))), return; end
            lo = min(P, [], 1); hi = max(P, [], 1);
            if ~isempty(obj.Held) && all(lo >= obj.Held(1, :)) && all(hi <= obj.Held(2, :)), return; end
            g = [10 10 2]; L = [floor(lo ./ g) .* g; ceil(hi ./ g) .* g];
            L(2, :) = max(L(2, :), L(1, :) + g);
            obj.Held = L; set(obj.Axes, 'XLim', L(:, 1)', 'YLim', L(:, 2)', 'ZLim', L(:, 3)');
        end
    end
    methods (Access = protected)
        function buildBody(obj)
            obj.TitleLabel.Text = 'LIDAR TERRAIN [SIMULATED, ENU POINTS]';
            ax = obj.makeAxes(); obj.Axes = ax;
            obj.Points = scatter3(ax, NaN, NaN, NaN, 6, NaN, 'filled', 'Tag', 'lidar_points');
            view(ax, -35, 35); grid(ax, 'on'); colormap(ax, parula);
            ax.DataAspectRatio = [1 1 1];
            set(ax, 'Color', [0.08 0.08 0.1], 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w', 'FontSize', 9);
            xlabel(ax, 'E [m]'); ylabel(ax, 'N [m]'); zlabel(ax, 'U [m]');
            obj.Overlay = text(ax, 0.5, 0.5, '', 'Units', 'normalized', 'Color', mgv2.ui.theme().invalid, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Interpreter', 'none');
        end
    end
end
