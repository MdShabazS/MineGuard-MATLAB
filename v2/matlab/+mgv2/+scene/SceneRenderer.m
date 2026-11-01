classdef SceneRenderer < handle
    %SCENERENDERER 3-D view of the V2 world and aircraft driven by PoseSamples (V2-003). SIMULATION ONLY.
    %   r = mgv2.scene.SceneRenderer(world)                       new figure
    %   r = mgv2.scene.SceneRenderer(world, Parent=ax, Visible="off", TrailLength=600)
    %   r.update(pose)          pose = PoseSample (V2-002 snapshot) or any struct with position_enu_m,
    %                           orientation_quat [w x y z] (FLU->ENU), t_s, yaw_rad; phase/AGL optional
    %   r.setCameraMode(mode)   "isometric" | "follow" | "chase" | "topdown" | "orbit"
    %   r.setCameraMode("orbit", struct('orbit_az_deg', 80, 'orbit_el_deg', 25, 'orbit_dist_m', 3))
    %   delete(r)               removes every graphics object it created (and its own figure)
    %
    %   The renderer NEVER owns or advances simulation time: it only displays the pose it is given.
    %   Static geometry (terrain, objects, landmarks, boundary, pad) is drawn once; each update changes
    %   one hgtransform matrix, the shadow/stalk/marker positions, a capped trail, the camera and the
    %   HUD text. Axes are ENU metres (x east, y north, z up) with equal data aspect.

    properties (SetAccess = private)
        World
        Figure; Axes
        CameraMode = "isometric"
        CameraParams = struct()
        LastPose = []
        UpdateTimes = zeros(0, 1)      % seconds per update() call (excluding drawnow)
        Handles = struct()
    end
    properties (Access = private)
        OwnsFigure = false
        TrailXYZ; TrailN = 0; TrailCap
        ChaseYaw = NaN; ChaseT = NaN
        BodyParts
    end

    methods
        function r = SceneRenderer(world, opts)
            arguments
                world struct
                opts.Parent = []
                opts.Visible (1,1) string = "on"
                opts.TrailLength (1,1) double {mustBePositive, mustBeInteger} = 600
                opts.Position (1,4) double = [60 60 1280 760]
            end
            r.World = world; r.TrailCap = opts.TrailLength; r.TrailXYZ = nan(opts.TrailLength, 3);
            if isempty(opts.Parent)
                r.Figure = figure('Name', 'MineGuard V2 — 3-D scene (SIMULATION)', 'Color', [0.10 0.11 0.13], ...
                    'Position', opts.Position, 'Visible', opts.Visible, 'NumberTitle', 'off');
                r.Axes = axes(r.Figure, 'Position', [0.02 0.03 0.96 0.90]);
                r.OwnsFigure = true;
            else
                r.Axes = opts.Parent; r.Figure = ancestor(r.Axes, 'figure');
            end
            r.build();
        end

        function delete(r)
            if r.OwnsFigure && ~isempty(r.Figure) && isvalid(r.Figure)
                delete(r.Figure);
            else
                f = fieldnames(r.Handles);
                for k = 1:numel(f)
                    h = r.Handles.(f{k});
                    if all(isgraphics(h)), delete(h); end
                end
            end
        end

        function setCameraMode(r, mode, params)
            if nargin < 3, params = struct(); end
            mgv2.scene.cameraView(mode, struct('position_enu_m', [0 0 0], 'yaw_rad', 0), r.World, params);  % validates mode
            r.CameraMode = string(mode); r.CameraParams = params; r.ChaseYaw = NaN;
            if ~isempty(r.LastPose), r.applyCamera(r.LastPose); end
        end

        function update(r, pose)
            t0 = tic;
            mgv2.scene.SceneRenderer.checkPose(pose);
            H = r.Handles; p = pose.position_enu_m; R = mgv2.frames.quatToRotm(pose.orientation_quat);
            H.aircraft.Matrix = [R p(:); 0 0 0 1];
            zg = mgv2.scene.heightAt(r.World, p(1), p(2));
            if isfinite(zg)
                H.shadow.Matrix = makehgtform('translate', [p(1) p(2) zg + 0.03]);
                set(H.stalk, 'XData', [p(1) p(1)], 'YData', [p(2) p(2)], 'ZData', [zg p(3)]);
            end
            set(H.uavMarker, 'XData', p(1), 'YData', p(2), 'ZData', p(3) + 0.35);
            r.TrailN = r.TrailN + 1; k = mod(r.TrailN - 1, r.TrailCap) + 1; r.TrailXYZ(k, :) = p;
            ord = [k+1:r.TrailCap, 1:k];
            set(H.trail, 'XData', r.TrailXYZ(ord, 1), 'YData', r.TrailXYZ(ord, 2), 'ZData', r.TrailXYZ(ord, 3));
            r.LastPose = pose;
            r.applyCamera(pose);
            r.UpdateTimes(end+1, 1) = toc(t0);
        end

        function n = graphicsCount(r)
            %GRAPHICSCOUNT Number of graphics objects under the axes (for leak tests).
            n = numel(findall(r.Axes));
        end
    end

    methods (Access = private)
        function build(r)
            w = r.World; ax = r.Axes; H = struct();
            hold(ax, 'on'); axis(ax, 'equal');
            set(ax, 'Projection', 'perspective', 'Clipping', 'off', 'Visible', 'off');   % axes hidden: scene view
            if r.OwnsFigure, r.Figure.Color = [0.58 0.72 0.86]; end                     % sky
            xlabel(ax, 'x east [m]'); ylabel(ax, 'y north [m]'); zlabel(ax, 'z up [m]');
            e = w.config.extent_enu_m; xlim(ax, e(1,:)); ylim(ax, e(2,:)); zlim(ax, [min(w.Z(:)) - 2, max(w.Z(:)) + 40]);
            H.terrain = patch(ax, 'Faces', w.F, 'Vertices', w.V, 'FaceVertexCData', w.vertex_rgb, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', 'FaceLighting', 'gouraud', 'AmbientStrength', 0.62, 'DiffuseStrength', 0.62, ...
                'SpecularStrength', 0.03, 'SpecularExponent', 5, 'BackFaceLighting', 'lit', 'Tag', 'terrain');
            O = w.objects; groups = ["rock","bush","marker"];
            for g = groups
                rows = find(O.kind == g); Vs = zeros(0, 3); Fs = zeros(0, 3); Cs = zeros(0, 3);
                for k = rows'
                    [V, F] = mgv2.scene.objectMesh(O(k, :));
                    Fs = [Fs; F + size(Vs, 1)]; Vs = [Vs; V]; Cs = [Cs; repmat(O.rgb(k,:), size(V, 1), 1)]; %#ok<AGROW>
                end
                if isempty(Vs), H.("obj_" + g) = gobjects(0); continue; end
                H.("obj_" + g) = patch(ax, 'Faces', Fs, 'Vertices', Vs, 'FaceVertexCData', Cs, 'FaceColor', 'interp', 'EdgeColor', 'none', ...
                    'FaceLighting', 'gouraud', 'AmbientStrength', 0.4, 'SpecularStrength', 0.08, 'Tag', g);
            end
            a = linspace(0, 2 * pi, 33)'; H.landmarks = gobjects(numel(w.landmarks), 1);
            for k = 1:numel(w.landmarks)
                L = w.landmarks(k); px = L.xy(1) + L.radius_m * cos(a); py = L.xy(2) + L.radius_m * sin(a);
                H.landmarks(k) = patch(ax, px, py, mgv2.scene.heightAt(w, px, py) + 0.02, L.color, 'EdgeColor', 'none', 'Tag', 'landmark');
            end
            P = w.config.survey_polygon_enu_m; P = [P; P(1,:)]; bx = []; by = [];
            for k = 1:size(P, 1) - 1
                n = max(2, ceil(norm(P(k+1,:) - P(k,:)))); s = linspace(0, 1, n)';
                bx = [bx; P(k,1) + s * (P(k+1,1) - P(k,1))]; by = [by; P(k,2) + s * (P(k+1,2) - P(k,2))]; %#ok<AGROW>
            end
            H.boundary = plot3(ax, bx, by, mgv2.scene.heightAt(w, bx, by) + 0.12, '-', 'Color', [1 0.82 0.10], 'LineWidth', 2.2, 'Tag', 'survey_boundary');
            hp = w.config.home_enu_m; hs = w.config.home_pad_m; zh = mgv2.scene.heightAt(w, hp(1), hp(2)) + 0.02;
            H.homeH = plot3(ax, hp(1) + [-0.6 -0.6 NaN 0.6 0.6 NaN -0.6 0.6], hp(2) + [-0.9 0.9 NaN -0.9 0.9 NaN 0 0], zh + zeros(1, 8), ...
                'w-', 'LineWidth', 3, 'Tag', 'home_marking');
            na = hp + [hs + 2, 0]; zna = mgv2.scene.heightAt(w, na(1) + [0 0 -0.6 0.6], na(2) + [0 3 2.2 2.2]) + 0.05;   % north arrow (3 m)
            H.north = plot3(ax, na(1) + [0 0 -0.6 NaN 0 0.6], na(2) + [0 3 2.2 NaN 3 2.2], [zna(1) zna(2) zna(3) NaN zna(2) zna(4)], ...
                'w-', 'LineWidth', 2.5, 'Tag', 'north_arrow');
            H.northLabel = text(ax, na(1), na(2) + 3.8, zna(2) + 0.3, 'N', 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
                'HorizontalAlignment', 'center', 'Tag', 'north_label');
            H.homeEdge = plot3(ax, hp(1) + hs / 2 * [-1 1 1 -1 -1], hp(2) + hs / 2 * [-1 -1 1 1 -1], zh + zeros(1, 5), '-', ...
                'Color', [0.95 0.95 0.2], 'LineWidth', 1.5, 'Tag', 'home_pad');
            % aircraft (single hgtransform), its ground shadow, altitude stalk, screen-size marker, trail
            H.aircraft = hgtransform(ax, 'Tag', 'aircraft');
            parts = mgv2.scene.quadrotorModel(); r.BodyParts = parts;
            for k = 1:numel(parts)
                patch('Parent', H.aircraft, 'Faces', parts(k).F, 'Vertices', parts(k).V, 'FaceColor', parts(k).rgb, ...
                    'FaceAlpha', parts(k).alpha, 'EdgeColor', 'none', 'FaceLighting', 'flat', 'AmbientStrength', 0.6, 'Tag', parts(k).name);
            end
            H.shadow = hgtransform(ax, 'Tag', 'shadow');
            patch('Parent', H.shadow, 'XData', 0.30 * cos(a), 'YData', 0.30 * sin(a), 'ZData', zeros(size(a)), 'FaceColor', 'k', ...
                'FaceAlpha', 0.35, 'EdgeColor', 'none', 'FaceLighting', 'none');
            H.stalk = plot3(ax, [NaN NaN], [NaN NaN], [NaN NaN], ':', 'Color', [1 1 1 0.7], 'LineWidth', 1, 'Tag', 'altitude_stalk');
            H.uavMarker = plot3(ax, NaN, NaN, NaN, 'v', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.3 0.1], 'MarkerEdgeColor', 'w', 'Tag', 'uav_marker');
            H.trail = plot3(ax, nan(r.TrailCap, 1), nan(r.TrailCap, 1), nan(r.TrailCap, 1), '-', 'Color', [0.1 0.35 0.95], 'LineWidth', 1.6, 'Tag', 'trail');
            % lighting: sun (infinite, from SW, 50 deg up) + soft fill from the opposite side
            H.sun = light(ax, 'Style', 'infinite', 'Position', [-cosd(50) * cosd(45), -cosd(50) * sind(45), sind(50)], 'Color', [1 0.97 0.9]);
            H.fill = light(ax, 'Style', 'infinite', 'Position', [0.6 0.8 0.4], 'Color', 0.35 * [0.8 0.85 1]);
            H.hud = annotation(r.Figure, 'textbox', [0.01 0.935 0.98 0.06], 'String', 'SIMULATION', 'Color', [1 1 1], ...
                'BackgroundColor', [0.08 0.09 0.11], 'FaceAlpha', 0.75, 'EdgeColor', 'none', 'FontName', 'Consolas', 'FontSize', 11, 'Interpreter', 'tex', 'VerticalAlignment', 'middle');
            H.banner = annotation(r.Figure, 'textbox', [0.01 0.0 0.98 0.035], 'String', ...
                'SIMULATION — synthetic terrain and virtual aircraft; not a real flight, sensor feed or hazard map', ...
                'Color', [1 0.85 0.8], 'BackgroundColor', [0.45 0.05 0.05], 'FaceAlpha', 0.8, 'EdgeColor', 'none', 'FontSize', 10, 'HorizontalAlignment', 'center');
            camproj(ax, 'perspective'); r.Handles = H;
            v = mgv2.scene.cameraView("isometric", struct('position_enu_m', [0 0 0], 'yaw_rad', 0), w);
            r.setAxesCamera(v);
        end

        function applyCamera(r, pose)
            prm = r.CameraParams;
            if r.CameraMode == "chase"   % smooth the chase heading (time constant 0.6 s of SIMULATION time)
                if isnan(r.ChaseYaw) || ~isfinite(r.ChaseT) || pose.t_s < r.ChaseT
                    r.ChaseYaw = pose.yaw_rad;
                else
                    a = 1 - exp(-(pose.t_s - r.ChaseT) / 0.6);
                    r.ChaseYaw = r.ChaseYaw + a * atan2(sin(pose.yaw_rad - r.ChaseYaw), cos(pose.yaw_rad - r.ChaseYaw));
                end
                r.ChaseT = pose.t_s; prm.chase_yaw_rad = r.ChaseYaw;
            end
            r.setAxesCamera(mgv2.scene.cameraView(r.CameraMode, pose, r.World, prm));
            set(r.Handles.uavMarker, 'Visible', matlab.lang.OnOffSwitchState(ismember(r.CameraMode, ["isometric","topdown"])));
            r.refreshHud(pose);
        end

        function refreshHud(r, pose)
            ph = ""; if isfield(pose, 'phase'), ph = strrep(string(pose.phase), "_", "\_"); end   % TeX-safe (RETURN_HOME)
            agl = NaN; if isfield(pose, 'altitude_agl_m'), agl = pose.altitude_agl_m; end
            r.Handles.hud.String = sprintf(['SIMULATION  |  t_{sim} = %.2f s  |  %s  |  E %.1f  N %.1f  U %.1f m  |  AGL %.1f m  |  ', ...
                'heading %03.0f%s  |  camera: %s'], pose.t_s, ph, pose.position_enu_m, agl, mgv2.frames.headingDegFromYaw(pose.yaw_rad), char(176), r.CameraMode);
        end

        function setAxesCamera(r, v)
            set(r.Axes, 'CameraPosition', v.position, 'CameraTarget', v.target, 'CameraUpVector', v.up, ...
                'CameraViewAngle', v.view_angle_deg);
        end
    end

    methods (Static)
        function checkPose(pose)
            id = 'mgv2:InvalidPose';
            if ~isstruct(pose) || ~all(isfield(pose, {'position_enu_m','orientation_quat','t_s','yaw_rad'}))
                error(id, 'Pose must have position_enu_m, orientation_quat, t_s and yaw_rad.');
            end
            p = pose.position_enu_m; q = pose.orientation_quat;
            if ~(isnumeric(p) && numel(p) == 3 && all(isfinite(p))), error(id, 'position_enu_m must be 3 finite values.'); end
            if ~(isnumeric(q) && numel(q) == 4 && all(isfinite(q)) && abs(norm(q) - 1) < 1e-6), error(id, 'orientation_quat must be a unit [w x y z].'); end
            if ~(isscalar(pose.t_s) && isfinite(pose.t_s)), error(id, 't_s must be finite.'); end
        end
    end
end
