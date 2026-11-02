classdef ScenePanel < mgv2.ui.PanelBase
    %SCENEPANEL Live 3-D aircraft and terrain: wraps the V2-003 SceneRenderer. Displays the pose it is given.
    %   panel.bind(world), then panel.present(view). The camera dropdown only changes the viewpoint.
    properties (SetAccess = private, Transient, NonCopyable)
        Axes; Renderer; CameraDropdown; World; Viewport
    end
    methods
        function bind(obj, world)
            obj.World = world; obj.makeRenderer();
        end
        function present(obj, view)
            p = view.pose; obj.presentPose(p);
            obj.setStatus(sprintf("t=%.2f s | tick %d | %s | E %.1f N %.1f U %.1f m", p.t_s, p.tick_id, p.phase, p.position_enu_m), "NONE");
        end
        function presentPose(obj, p)
            %PRESENTPOSE Scene-only update. It leaves the labels alone because any label change adds a costly UI flush.
            if isempty(obj.Renderer.LastPose) || obj.Renderer.LastPose.tick_id ~= p.tick_id, obj.Renderer.update(p); end
        end
        function resetDisplay(obj)
            delete(obj.Renderer); obj.makeRenderer();   % the renderer's trail has no reset of its own
        end
        function delete(obj)
            if ~isempty(obj.Renderer) && isvalid(obj.Renderer), delete(obj.Renderer); end
        end
    end
    methods (Access = protected)
        function buildBody(obj)
            obj.TitleLabel.Text = '3-D SCENE [SIMULATED]';
            obj.CameraDropdown = uidropdown(obj.Grid, 'Items', ["follow","chase","isometric","topdown","orbit"], 'FontSize', 11, ...
                'ValueChangedFcn', @(src, ~) obj.Renderer.setCameraMode(src.Value));
            obj.CameraDropdown.Layout.Row = 1; obj.CameraDropdown.Layout.Column = 2;
            obj.Grid.RowHeight{1} = 24;
            % The perspective view is not clipped by its axes. A panel clips it, so the header stays clear (as in V2-005).
            t = mgv2.ui.theme();
            obj.Viewport = uipanel(obj.Grid, 'BorderType', 'none', 'BackgroundColor', t.sky);
            obj.Viewport.Layout.Row = 3; obj.Viewport.Layout.Column = [1 2];
            g = uigridlayout(obj.Viewport, [1 1], 'Padding', 0, 'BackgroundColor', t.sky);
            obj.Axes = obj.makeAxes(g);
        end
    end
    methods (Access = private)
        function makeRenderer(obj)
            obj.Renderer = mgv2.scene.SceneRenderer(obj.World, Parent=obj.Axes);
            % The renderer's HUD and banner are figure-level annotations meant for a dedicated figure. Here they
            % would cover other panels, and this application shows the same information itself.
            obj.Renderer.Handles.hud.Visible = 'off'; obj.Renderer.Handles.banner.Visible = 'off';
            obj.Renderer.setCameraMode(obj.CameraDropdown.Value);
        end
    end
end
