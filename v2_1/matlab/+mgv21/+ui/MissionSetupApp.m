classdef MissionSetupApp < handle
    %MISSIONSETUPAPP V2.1 mission SETUP window (V21-005). SIMULATION ONLY.
    %   app = mgv21.ui.MissionSetupApp(Visible="on", OnLaunch=@(pub, world, priv) ..., Position=[x y w h])
    %   The guide chooses an environment preset, edits the survey boundary, home and grid, previews the planned
    %   route, and places PRIVATE synthetic target hypotheses (NONE / MANUAL / RANDOM). LOCK & START fixes the
    %   scenario with mgv21.placement.lockScenario, removes every target marker, disables all editing and calls
    %   OnLaunch(pub, world, priv) exactly once. Without OnLaunch the window simply closes after the lock.
    %
    %   Only frozen mg-v21-contract/1.0 functions are called (V21_CONTRACT.md §3). The placement spec and the
    %   private scenario live only in private properties; priv is dropped as soon as OnLaunch returns.
    %   Public read-only state holds public data only (see publicState).
    %
    %   Test API (same effect as the controls): selectPreset(id), setRectangle(xmin, xmax, ymin, ymax),
    %   setPolygon(P), setHome(xy), setGrid(name, value), setMode(mode), setTool(tool), setSignature(sig),
    %   setBurialDepth(d), clickMap(x, y), setRandom(count, seed, ClutterSeed=, VisibleFraction=), lockAndStart().
    %   delete(app) closes the window; no timer is created.

    properties (Constant)
        PickRadius = 2                    % m: a Move/Delete click selects the nearest marker within this radius
        DefaultBurialDepth = 0.1          % m: UI default for a MANUAL target (the contract fixes no default)
        GridNames = ["line_spacing_m", "heading_deg", "alt_agl_m", "speed_mps"]
        Tools = ["ADD", "MOVE", "DELETE"]
    end
    properties (SetAccess = private)
        Figure; MapAxes; Controls = struct()
        Phase (1,1) string = "SETUP"      % "SETUP" or "LOCKED"
        PresetId (1,1) string = ""
        Survey = struct()                 % SurveySpec as edited (normalised by validateSurvey when valid)
        Pub = []                          % PublicMissionConfig of the current valid survey, [] when invalid
        World = []                        % public V2 world of the preset (mgv21.scenario.buildWorld)
        ValidationText (1,1) string = ""
        ValidationErrorId (1,1) string = ""   % identifier of the last survey error, "" when valid
        RouteVisible (1,1) logical = false
        NumSetupMarkers (1,1) double = 0  % markers drawn from mgv21.placement.setupMarkers
        NumManualTargets (1,1) double = 0
        Mode (1,1) string = "NONE"
        Tool (1,1) string = "ADD"
        Signature (1,1) string = "VISIBLE_DISTURBANCE"
        BurialDepth (1,1) double = 0.1
        PlacementMessage (1,1) string = ""
        PlacementRefused (1,1) logical = false
        LaunchCount (1,1) double = 0
    end
    properties
        OnLaunch = []                     % fcn(pub, world, priv) after a successful lock; [] closes the window
    end
    properties (Access = private)
        Spec                              % PlacementSpec (private, SETUP panel only)
        PrivSlot = []                     % PrivateScenario, only between lockScenario and the end of OnLaunch
        H = struct()
        WorldKey = []                     % scene_config the current World was built from
        MoveFrom = 0                      % row of Spec.manual picked by the first Move click, 0 if none
        Handling = false
    end

    methods
        function obj = MissionSetupApp(opts)
            arguments
                opts.Visible (1,1) string = "on"
                opts.OnLaunch = []
                opts.Position double = []
                opts.Preset (1,1) string = ""
            end
            if ~isempty(opts.OnLaunch) && ~isa(opts.OnLaunch, 'function_handle')
                error('mgv21ui:InvalidOption', 'OnLaunch must be a function handle fcn(pub, world, priv).');
            end
            obj.OnLaunch = opts.OnLaunch;
            pid = opts.Preset;
            if strlength(pid) == 0, pid = mgv21.contract().default_preset; end
            obj.Spec = mgv21.placement.defaultPlacement("NONE");
            obj.BurialDepth = obj.DefaultBurialDepth;
            obj.buildUi(opts.Position);
            obj.selectPreset(pid);
            obj.Figure.Visible = opts.Visible;
            drawnow;
        end

        function delete(obj)
            obj.PrivSlot = [];
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                obj.Figure.CloseRequestFcn = '';
                delete(obj.Figure);
            end
        end

        % ---------------------------------------------------------------- survey
        function selectPreset(obj, id)
            %SELECTPRESET Load the preset's default survey, rebuild the world and preview the route.
            obj.requireSetup();
            id = string(id);
            p = mgv21.scenario.environmentPreset(id);          % mgv21:UnknownPreset for a bad id
            obj.PresetId = id;
            obj.Survey = mgv21.scenario.defaultSurvey(id);
            obj.World = []; obj.WorldKey = []; obj.MoveFrom = 0;
            obj.Spec = mgv21.placement.defaultPlacement(obj.Mode);   % targets of another terrain are dropped
            obj.Controls.preset.Value = char(id);
            obj.Controls.presetInfo.Text = sprintf('%s (%s)\n%s', p.title, p.environment_mode, p.description);
            obj.syncPlacementFields();
            obj.preview();
        end

        function setRectangle(obj, xmin, xmax, ymin, ymax)
            obj.requireSetup();
            s = obj.Survey;
            try
                s.polygon_enu_m = mgv21.scenario.rectangleBoundary(xmin, xmax, ymin, ymax);
            catch err
                obj.Pub = []; obj.showSurveyError(err); obj.drawMission([]); obj.syncControls(); return
            end
            s.boundary_kind = "RECTANGLE";
            obj.Survey = s; obj.preview();
        end

        function setPolygon(obj, P)
            obj.requireSetup();
            s = obj.Survey; s.boundary_kind = "POLYGON"; s.polygon_enu_m = double(P);
            obj.Survey = s; obj.preview();
        end

        function setHome(obj, xy)
            obj.requireSetup();
            obj.Survey.home_enu_m = double(reshape(xy, 1, []));
            obj.preview();
        end

        function setGrid(obj, name, value)
            obj.requireSetup();
            name = string(name);
            if ~ismember(name, obj.GridNames)
                error('mgv21ui:InvalidOption', 'Grid field must be one of: %s.', strjoin(obj.GridNames, ', '));
            end
            obj.Survey.(name) = double(value);
            obj.preview();
        end

        function preview(obj)
            %PREVIEW Validate the survey and draw the planned route; on any error show the message and no route.
            if obj.Phase ~= "SETUP", return; end
            obj.Pub = []; plan = [];
            try
                [s, ~] = mgv21.scenario.validateSurvey(obj.Survey, obj.PresetId);   % geometry first, no terrain
                pub = mgv21.scenario.buildPublicMission(obj.PresetId, s);
                obj.ensureWorld(pub);
                for pass = 1:2      % the world follows the scene config (home pad); rebuild once if it moved
                    [s, ~] = mgv21.scenario.validateSurvey(s, obj.PresetId, obj.World);
                    [pub, plan] = mgv21.scenario.buildPublicMission(obj.PresetId, s, World=obj.World);
                    if ~obj.ensureWorld(pub) || pass == 2, break; end
                end
                mgv21.scenario.assertPublic(pub, "MissionSetupApp.Pub");
                obj.Survey = s; obj.Pub = pub;
                obj.setValidation(sprintf('Survey valid: %d survey lines, %.0f m of survey path. Simulated route preview only.', ...
                    plan.n_lines, plan.survey_length_m), "");
            catch err
                if err.identifier == "mgv2:TruthLeak", rethrow(err); end
                plan = []; obj.Pub = [];
                obj.showSurveyError(err);
            end
            obj.drawMission(plan);
            obj.syncControls();
        end

        % ---------------------------------------------------------------- placement
        function setMode(obj, mode)
            obj.requireSetup();
            mode = upper(string(mode));
            obj.Spec = mgv21.placement.defaultPlacement(mode);
            obj.Mode = mode; obj.MoveFrom = 0;
            obj.setPlacementMessage("", false);
            obj.syncPlacementFields(); obj.drawMarkers(); obj.syncControls();
        end

        function setTool(obj, tool)
            obj.requireSetup();
            tool = upper(string(tool));
            if ~ismember(tool, obj.Tools)
                error('mgv21ui:InvalidOption', 'Tool must be one of: %s.', strjoin(obj.Tools, ', '));
            end
            obj.Tool = tool; obj.MoveFrom = 0; obj.drawMarkers(); obj.syncControls();
        end

        function setSignature(obj, sig)
            obj.requireSetup();
            sig = upper(string(sig));
            if ~ismember(sig, mgv21.contract().signatures)
                error('mgv21ui:InvalidOption', 'Signature must be one of: %s.', strjoin(mgv21.contract().signatures, ', '));
            end
            obj.Signature = sig; obj.syncControls();
        end

        function setBurialDepth(obj, d)
            obj.requireSetup();
            obj.BurialDepth = double(d); obj.syncControls();
        end

        function setRandom(obj, count, seed, opts)
            %SETRANDOM RANDOM placement settings. Values are checked by lockScenario (mgv21:InvalidPlacement).
            arguments
                obj
                count (1,1) double
                seed (1,1) double
                opts.ClutterSeed double = []
                opts.VisibleFraction double = []
            end
            obj.requireSetup();
            if obj.Mode ~= "RANDOM"
                error('mgv21ui:WrongMode', 'RANDOM settings need placement mode RANDOM (current mode %s).', obj.Mode);
            end
            obj.Spec.count = count; obj.Spec.seed = seed;
            if ~isempty(opts.ClutterSeed), obj.Spec.clutter_seed = opts.ClutterSeed; end
            if ~isempty(opts.VisibleFraction), obj.Spec.visible_fraction = opts.VisibleFraction; end
            obj.syncPlacementFields(); obj.syncControls();
        end

        function clickMap(obj, x, y)
            %CLICKMAP A map click in ENU metres, with the current MANUAL tool.
            if obj.Phase ~= "SETUP"
                obj.setPlacementMessage("Setup is locked: target placement is closed.", true); return
            end
            if obj.Mode ~= "MANUAL"
                obj.setPlacementMessage("Map clicks place targets only in MANUAL mode.", true); return
            end
            if isempty(obj.Pub)
                obj.setPlacementMessage("Fix the survey before placing targets.", true); return
            end
            xy = double([x y]);
            try
                switch obj.Tool
                    case "ADD"
                        [ok, reason] = mgv21.placement.checkLocation(obj.Spec, obj.Pub, obj.World, xy);
                        if ok
                            obj.Spec = mgv21.placement.addTarget(obj.Spec, xy, obj.Signature, obj.BurialDepth);
                            obj.setPlacementMessage(sprintf("Synthetic target added at E %.1f N %.1f m.", xy), false);
                        else
                            obj.setPlacementMessage("REFUSED: " + string(reason), true);
                        end
                    case "MOVE"
                        if obj.MoveFrom == 0
                            k = obj.nearestTarget(xy);
                            if k == 0
                                obj.setPlacementMessage(sprintf("No marker within %g m: click on a marker to move it.", obj.PickRadius), true);
                            else
                                obj.MoveFrom = k;
                                obj.setPlacementMessage("Marker selected: click its new position.", false);
                            end
                        else
                            k = obj.MoveFrom;
                            others = mgv21.placement.deleteTarget(obj.Spec, k);   % the moved target must not block itself
                            [ok, reason] = mgv21.placement.checkLocation(others, obj.Pub, obj.World, xy);
                            if ok
                                obj.Spec = mgv21.placement.moveTarget(obj.Spec, k, xy); obj.MoveFrom = 0;
                                obj.setPlacementMessage(sprintf("Synthetic target moved to E %.1f N %.1f m.", xy), false);
                            else
                                obj.setPlacementMessage("REFUSED: " + string(reason) + " (marker still selected)", true);
                            end
                        end
                    case "DELETE"
                        k = obj.nearestTarget(xy);
                        if k == 0
                            obj.setPlacementMessage(sprintf("No marker within %g m to delete.", obj.PickRadius), true);
                        else
                            obj.Spec = mgv21.placement.deleteTarget(obj.Spec, k);
                            obj.setPlacementMessage("Synthetic target deleted.", false);
                        end
                end
            catch err
                if ~startsWith(err.identifier, "mgv21:"), rethrow(err); end
                obj.setPlacementMessage("REFUSED: " + err.message, true);
            end
            obj.drawMarkers(); obj.syncControls();
        end

        function ok = lockAndStart(obj)
            %LOCKANDSTART Fix the private scenario, hide every marker, disable editing, then call OnLaunch once.
            ok = false;
            if obj.Phase ~= "SETUP", return; end
            if isempty(obj.Pub)
                obj.setPlacementMessage("LOCK REFUSED: the survey is not valid.", true); return
            end
            try
                obj.PrivSlot = mgv21.placement.lockScenario(obj.Spec, obj.Pub, obj.World);
            catch err
                obj.PrivSlot = [];
                if ismember(string(err.identifier), ["mgv21:InvalidPlacement", "mgv21:PlacementInfeasible"])
                    obj.setPlacementMessage("LOCK REFUSED: " + err.message, true); return
                end
                rethrow(err);
            end
            drop = onCleanup(@() obj.dropPrivate());   % also when OnLaunch throws
            obj.Phase = "LOCKED"; obj.MoveFrom = 0; ok = true;
            obj.setPlacementMessage("LOCKED: scenario fixed. Private synthetic targets are hidden for the run.", false);
            obj.drawMarkers(); obj.syncControls(); drawnow;
            obj.LaunchCount = obj.LaunchCount + 1;
            if isempty(obj.OnLaunch)
                obj.dropPrivate(); delete(obj);
            else
                obj.OnLaunch(obj.Pub, obj.World, obj.PrivSlot);
            end
        end

        function st = publicState(obj)
            %PUBLICSTATE Every public data property as one plain struct (handles and callbacks excluded).
            st = struct('Phase', obj.Phase, 'PresetId', obj.PresetId, 'Survey', obj.Survey, 'Pub', {obj.Pub}, ...
                'World', {obj.World}, 'ValidationText', obj.ValidationText, 'ValidationErrorId', obj.ValidationErrorId, ...
                'RouteVisible', obj.RouteVisible, 'NumSetupMarkers', obj.NumSetupMarkers, 'NumManualTargets', obj.NumManualTargets, ...
                'Mode', obj.Mode, 'Tool', obj.Tool, 'Signature', obj.Signature, 'BurialDepth', obj.BurialDepth, ...
                'PlacementMessage', obj.PlacementMessage, 'PlacementRefused', obj.PlacementRefused, 'LaunchCount', obj.LaunchCount);
        end
    end

    methods (Access = private)
        function buildUi(obj, pos)
            t = mgv2.ui.theme();
            if isempty(pos), pos = mgv2.ui.MissionControlApp.defaultPosition(); end
            fig = uifigure('Name', 'MineGuard V2.1 Mission Setup (SIMULATION ONLY)', 'Position', pos, 'Color', t.bg, ...
                'Visible', 'off', 'CloseRequestFcn', @(~, ~) delete(obj), 'Tag', 'mgv21_mission_setup');
            theme(fig, "dark");
            obj.Figure = fig;
            outer = uigridlayout(fig, [2 1], 'RowHeight', {48, '1x'}, 'ColumnWidth', {'1x'}, 'Padding', [4 4 4 4], 'RowSpacing', 4, 'BackgroundColor', t.bg);
            banner = mgv2.ui.SimulationBanner(outer); banner.Layout.Row = 1;
            body = uigridlayout(outer, [1 2], 'ColumnWidth', {380, '1x'}, 'RowHeight', {'1x'}, 'Padding', 0, 'ColumnSpacing', 6, 'BackgroundColor', t.bg);
            body.Layout.Row = 2;

            rows = {22, 22, 64, 22, 22, 22, 22, 22, 22, 120, 22, 22, 22, 22, 22, 22, 22, 26, 22, 34, 22, 22, 22, 22, 22, 22, 22, 22, 48, 34};
            g = uigridlayout(body, [numel(rows) 2], 'RowHeight', rows, 'ColumnWidth', {150, '1x'}, 'Padding', [6 6 6 6], ...
                'RowSpacing', 3, 'ColumnSpacing', 6, 'Scrollable', 'on', 'BackgroundColor', t.panel);
            g.Layout.Column = 1;
            C = struct(); r = 0;
            function next()
                r = r + 1;
            end
            function h = place(h, span)
                h.Layout.Row = r;
                if span, h.Layout.Column = [1 2]; else, h.Layout.Column = 2; end
            end
            function section(txt)
                next(); place(uilabel(g, 'Text', txt, 'FontWeight', 'bold', 'FontColor', t.sky), true);
            end
            function h = row(txt, h)
                next(); lb = uilabel(g, 'Text', txt, 'FontColor', t.text); lb.Layout.Row = r; lb.Layout.Column = 1; place(h, false);
            end
            function h = num(tag, cb)
                h = uieditfield(g, 'numeric', 'Tag', tag, 'ValueChangedFcn', @(~, ~) obj.guard(cb));
            end

            section('ENVIRONMENT PRESET (SIMULATED)');
            ids = mgv21.scenario.presetIds();
            C.preset = row('Preset', uidropdown(g, 'Items', cellstr(ids), 'Tag', 'setup_preset', ...
                'ValueChangedFcn', @(src, ~) obj.guard(@() obj.selectPreset(src.Value))));
            next(); C.presetInfo = place(uilabel(g, 'Text', '', 'WordWrap', 'on', 'FontColor', t.muted, 'FontSize', 11, 'VerticalAlignment', 'top'), true);
            section('SURVEY BOUNDARY (LOCAL ENU, m)');
            C.kind = row('Boundary', uidropdown(g, 'Items', {'RECTANGLE', 'POLYGON'}, 'Tag', 'setup_kind', ...
                'ValueChangedFcn', @(src, ~) obj.guard(@() obj.onKind(src.Value))));
            rectCb = @() obj.onRectangleFields();
            C.xmin = row('x min (E)', num('setup_xmin', rectCb)); C.xmax = row('x max (E)', num('setup_xmax', rectCb));
            C.ymin = row('y min (N)', num('setup_ymin', rectCb)); C.ymax = row('y max (N)', num('setup_ymax', rectCb));
            next(); C.polygon = place(uitable(g, 'ColumnName', {'x east [m]', 'y north [m]'}, 'ColumnEditable', [true true], ...
                'Tag', 'setup_polygon', 'CellEditCallback', @(src, ~) obj.guard(@() obj.setPolygon(src.Data))), true);
            C.homeX = row('Home x (E)', num('setup_home_x', @() obj.onHomeFields()));
            C.homeY = row('Home y (N)', num('setup_home_y', @() obj.onHomeFields()));
            section('GRID AND ROUTE');
            labels = ["Line spacing [m]", "Heading [deg]", "Altitude AGL [m]", "Speed [m/s]"];
            for k = 1:numel(obj.GridNames)
                f = obj.GridNames(k);
                C.(f) = row(char(labels(k)), num(char("setup_" + f), @() obj.setGrid(f, obj.Controls.(f).Value)));
            end
            next(); C.previewBtn = place(uibutton(g, 'Text', 'Preview route', 'Tag', 'setup_preview', ...
                'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.preview())), true);
            section('PRIVATE SYNTHETIC TARGETS (SIMULATION)');
            next(); place(uilabel(g, 'Text', 'Hypothetical targets for the simulation only. They are hidden after LOCK.', ...
                'WordWrap', 'on', 'FontColor', t.muted, 'FontSize', 11), true);
            C.mode = row('Placement mode', uidropdown(g, 'Items', cellstr(mgv21.contract().placement_modes), 'Tag', 'setup_mode', ...
                'ValueChangedFcn', @(src, ~) obj.guard(@() obj.setMode(src.Value))));
            C.tool = row('Map tool', uidropdown(g, 'Items', {'ADD', 'MOVE', 'DELETE'}, 'Tag', 'setup_tool', ...
                'ValueChangedFcn', @(src, ~) obj.guard(@() obj.setTool(src.Value))));
            C.signature = row('Surface signature', uidropdown(g, 'Items', cellstr(mgv21.contract().signatures), 'Tag', 'setup_signature', ...
                'ValueChangedFcn', @(src, ~) obj.guard(@() obj.setSignature(src.Value))));
            C.depth = row('Burial depth [m]', uieditfield(g, 'numeric', 'Limits', [0 Inf], 'Tag', 'setup_depth', ...
                'ValueChangedFcn', @(src, ~) obj.guard(@() obj.setBurialDepth(src.Value))));
            lim = mgv21.contract().limits; seedLim = [0 2^32 - 1];
            randCb = @() obj.onRandomFields();
            C.count = row('Random count', uieditfield(g, 'numeric', 'Limits', lim.target_count, 'RoundFractionalValues', 'on', 'Tag', 'setup_count', 'ValueChangedFcn', @(~, ~) obj.guard(randCb)));
            C.seed = row('Random seed', uieditfield(g, 'numeric', 'Limits', seedLim, 'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%.0f', 'Tag', 'setup_seed', 'ValueChangedFcn', @(~, ~) obj.guard(randCb)));
            C.clutterSeed = row('Clutter seed', uieditfield(g, 'numeric', 'Limits', seedLim, 'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%.0f', 'Tag', 'setup_clutter_seed', 'ValueChangedFcn', @(~, ~) obj.guard(randCb)));
            C.visibleFraction = row('Visible fraction', uieditfield(g, 'numeric', 'Limits', [0 1], 'Tag', 'setup_visible_fraction', 'ValueChangedFcn', @(~, ~) obj.guard(randCb)));
            next(); C.placementMsg = place(uilabel(g, 'Text', '', 'WordWrap', 'on', 'FontColor', t.muted, 'FontSize', 11, 'Tag', 'setup_placement_msg'), true);
            next(); C.lock = place(uibutton(g, 'Text', 'LOCK & START', 'FontWeight', 'bold', 'Tag', 'setup_lock', ...
                'ButtonPushedFcn', @(~, ~) obj.guard(@() obj.lockAndStart())), true);

            right = uigridlayout(body, [2 1], 'RowHeight', {'fit', '1x'}, 'ColumnWidth', {'1x'}, 'Padding', [6 6 6 6], 'RowSpacing', 4, 'BackgroundColor', t.panel);
            right.Layout.Column = 2;
            C.validation = uilabel(right, 'Text', '', 'WordWrap', 'on', 'FontWeight', 'bold', 'FontColor', t.muted, 'Tag', 'setup_validation');
            ax = uiaxes(right, 'Color', t.panel, 'Tag', 'setup_map'); ax.Layout.Row = 2;
            ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
            title(ax, 'MISSION SETUP MAP [SIMULATED, VIRTUAL COORDINATES]', 'Color', t.text);
            xlabel(ax, 'E [m]'); ylabel(ax, 'N [m]');
            set(ax, 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w', 'Layer', 'top', 'Box', 'on', 'YDir', 'normal');
            hold(ax, 'on'); axis(ax, 'equal');
            ax.ButtonDownFcn = @(~, ~) obj.guard(@() obj.onAxesClick());
            obj.MapAxes = ax; obj.Controls = C;

            np = {'PickableParts', 'none'};
            obj.H.boundary = plot(ax, NaN, NaN, '-', 'Color', [1 0.82 0.10], 'LineWidth', 2, 'DisplayName', 'survey boundary', 'Tag', 'setup_boundary', np{:});
            obj.H.route = plot(ax, NaN, NaN, '--', 'Color', [1 1 1], 'LineWidth', 1, 'DisplayName', 'planned route', 'Tag', 'setup_route', np{:});
            obj.H.home = plot(ax, NaN, NaN, 's', 'MarkerSize', 9, 'MarkerFaceColor', [0.95 0.95 0.2], 'MarkerEdgeColor', 'k', 'DisplayName', 'home', 'Tag', 'setup_home', np{:});
            obj.H.markVisible = plot(ax, NaN, NaN, 'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', [1 0.35 0.75], 'LineStyle', 'none', ...
                'DisplayName', 'synthetic target (visible disturbance)', 'Tag', 'setup_marker_visible', np{:});
            obj.H.markNone = plot(ax, NaN, NaN, 'o', 'MarkerSize', 8, 'LineWidth', 1.5, 'Color', [0.75 0.55 1], 'LineStyle', 'none', ...
                'DisplayName', 'synthetic target (no surface signature)', 'Tag', 'setup_marker_none', np{:});
            obj.H.moveSel = plot(ax, NaN, NaN, 'o', 'MarkerSize', 16, 'LineWidth', 2, 'Color', [1 1 1], 'HandleVisibility', 'off', 'Tag', 'setup_move_selected', np{:});
            legend(ax, [obj.H.boundary obj.H.route obj.H.home obj.H.markVisible obj.H.markNone], 'Location', 'southoutside', ...
                'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'FontSize', 9, 'NumColumns', 3);
            obj.H.terrain = gobjects(0);
        end

        function guard(obj, fcn)
            %GUARD Run one control callback; a callback arriving while another runs is ignored.
            if obj.Handling, return; end
            obj.Handling = true; done = onCleanup(@() obj.endHandling());
            fcn();
        end

        function endHandling(obj)
            if isvalid(obj), obj.Handling = false; end
        end

        function requireSetup(obj)
            if obj.Phase ~= "SETUP"
                error('mgv21ui:Locked', 'The scenario is locked: setup can no longer be edited.');
            end
        end

        function onAxesClick(obj)
            cp = obj.MapAxes.CurrentPoint;
            obj.clickMap(cp(1, 1), cp(1, 2));
        end

        function onKind(obj, kind)
            P = obj.Survey.polygon_enu_m;
            if string(kind) == "RECTANGLE"
                obj.setRectangle(min(P(:, 1)), max(P(:, 1)), min(P(:, 2)), max(P(:, 2)));
            else
                obj.setPolygon(P);
            end
        end

        function onRectangleFields(obj)
            C = obj.Controls;
            obj.setRectangle(C.xmin.Value, C.xmax.Value, C.ymin.Value, C.ymax.Value);
        end

        function onHomeFields(obj)
            obj.setHome([obj.Controls.homeX.Value, obj.Controls.homeY.Value]);
        end

        function onRandomFields(obj)
            C = obj.Controls;
            obj.setRandom(C.count.Value, C.seed.Value, ClutterSeed=C.clutterSeed.Value, VisibleFraction=C.visibleFraction.Value);
        end

        function changed = ensureWorld(obj, pub)
            %ENSUREWORLD Build the public world for this scene config unless it is already the current one.
            changed = isempty(obj.World) || ~isequal(obj.WorldKey, pub.scene_config);
            if changed
                obj.World = mgv21.scenario.buildWorld(pub); obj.WorldKey = pub.scene_config;
            end
        end

        function k = nearestTarget(obj, xy)
            m = obj.Spec.manual; k = 0;
            if isempty(m) || height(m) == 0, return; end
            [d, i] = min(hypot(m.x_east_m - xy(1), m.y_north_m - xy(2)));
            if d <= obj.PickRadius, k = i; end
        end

        function dropPrivate(obj)
            if isvalid(obj), obj.PrivSlot = []; end
        end

        function showSurveyError(obj, err)
            obj.setValidation("INVALID SURVEY: " + string(err.message), string(err.identifier));
        end

        function setValidation(obj, txt, errId)
            t = mgv2.ui.theme();
            obj.ValidationText = string(txt); obj.ValidationErrorId = string(errId);
            obj.Controls.validation.Text = char(txt);
            if strlength(obj.ValidationErrorId) > 0 || startsWith(obj.ValidationText, "INVALID")
                obj.Controls.validation.FontColor = t.stale;
            else
                obj.Controls.validation.FontColor = t.valid;
            end
        end

        function setPlacementMessage(obj, txt, refused)
            t = mgv2.ui.theme();
            obj.PlacementMessage = string(txt); obj.PlacementRefused = refused;
            obj.Controls.placementMsg.Text = char(txt);
            if refused, obj.Controls.placementMsg.FontColor = t.stale; else, obj.Controls.placementMsg.FontColor = t.valid; end
        end

        function drawMission(obj, plan)
            ax = obj.MapAxes; w = obj.World;
            if ~isempty(w) && (isempty(obj.H.terrain) || ~isvalid(obj.H.terrain) || ~isequal(obj.H.terrain.UserData, obj.WorldKey))
                if ~isempty(obj.H.terrain) && isvalid(obj.H.terrain), delete(obj.H.terrain); end
                obj.H.terrain = image(ax, w.x, w.y, reshape(w.vertex_rgb, numel(w.y), numel(w.x), 3), 'AlphaData', 0.62, ...
                    'Tag', 'setup_terrain', 'PickableParts', 'none', 'HitTest', 'off', 'HandleVisibility', 'off');
                obj.H.terrain.UserData = obj.WorldKey;
                uistack(obj.H.terrain, 'bottom');
                e = w.config.extent_enu_m; xlim(ax, e(1, :)); ylim(ax, e(2, :));
            elseif isempty(w) && ~isempty(obj.H.terrain) && isvalid(obj.H.terrain)
                delete(obj.H.terrain); obj.H.terrain = gobjects(0);
            end
            s = obj.Survey; P = [];
            if isfield(s, 'polygon_enu_m') && size(s.polygon_enu_m, 2) == 2 && ~isempty(s.polygon_enu_m), P = s.polygon_enu_m; end
            if isempty(P)
                set(obj.H.boundary, 'XData', NaN, 'YData', NaN);
            else
                P = [P; P(1, :)];
                if isempty(obj.Pub), sty = {'LineStyle', ':', 'Color', [1 0.45 0.40]}; else, sty = {'LineStyle', '-', 'Color', [1 0.82 0.10]}; end
                set(obj.H.boundary, 'XData', P(:, 1), 'YData', P(:, 2), sty{:});
            end
            h = [NaN NaN];
            if isfield(s, 'home_enu_m') && numel(s.home_enu_m) == 2, h = double(s.home_enu_m(:)'); end
            set(obj.H.home, 'XData', h(1), 'YData', h(2));
            if isempty(plan) || isempty(obj.Pub)
                set(obj.H.route, 'XData', NaN, 'YData', NaN); obj.RouteVisible = false;
            else
                route = mgv2.mission.buildRoute(obj.Pub.mission, plan);
                set(obj.H.route, 'XData', route.xy(:, 1), 'YData', route.xy(:, 2)); obj.RouteVisible = true;
            end
            obj.drawMarkers();
        end

        function drawMarkers(obj)
            %DRAWMARKERS Only mgv21.placement.setupMarkers(spec, phase) is drawn; it is empty unless SETUP and MANUAL.
            M = mgv21.placement.setupMarkers(obj.Spec, obj.Phase);
            n = 0;
            if isempty(M) || height(M) == 0
                set([obj.H.markVisible obj.H.markNone], 'XData', NaN, 'YData', NaN);
            else
                vis = string(M.surface_signature) == "VISIBLE_DISTURBANCE";
                obj.setPoints(obj.H.markVisible, M.x_east_m(vis), M.y_north_m(vis));
                obj.setPoints(obj.H.markNone, M.x_east_m(~vis), M.y_north_m(~vis));
                n = height(M);
            end
            obj.NumSetupMarkers = n;
            obj.NumManualTargets = height(obj.Spec.manual);
            if obj.MoveFrom > 0 && obj.Phase == "SETUP"
                m = obj.Spec.manual;
                set(obj.H.moveSel, 'XData', m.x_east_m(obj.MoveFrom), 'YData', m.y_north_m(obj.MoveFrom));
            else
                set(obj.H.moveSel, 'XData', NaN, 'YData', NaN);
            end
        end

        function syncPlacementFields(obj)
            C = obj.Controls; sp = obj.Spec;
            obj.setNum(C.count, sp.count); obj.setNum(C.seed, sp.seed);
            obj.setNum(C.clutterSeed, sp.clutter_seed); obj.setNum(C.visibleFraction, sp.visible_fraction);
        end

        function syncControls(obj)
            %SYNCCONTROLS Field values follow the survey; enabling follows phase, boundary kind and placement mode.
            C = obj.Controls; s = obj.Survey; setup = obj.Phase == "SETUP";
            rect = ~isfield(s, 'boundary_kind') || string(s.boundary_kind) == "RECTANGLE";
            if isfield(s, 'boundary_kind') && ismember(string(s.boundary_kind), ["RECTANGLE", "POLYGON"])
                C.kind.Value = char(s.boundary_kind);
            end
            if isfield(s, 'polygon_enu_m') && size(s.polygon_enu_m, 2) == 2 && ~isempty(s.polygon_enu_m)
                P = double(s.polygon_enu_m);
                obj.setNum(C.xmin, min(P(:, 1))); obj.setNum(C.xmax, max(P(:, 1)));
                obj.setNum(C.ymin, min(P(:, 2))); obj.setNum(C.ymax, max(P(:, 2)));
                C.polygon.Data = P;
            end
            if isfield(s, 'home_enu_m') && numel(s.home_enu_m) == 2
                obj.setNum(C.homeX, s.home_enu_m(1)); obj.setNum(C.homeY, s.home_enu_m(2));
            end
            for f = obj.GridNames
                if isfield(s, f), obj.setNum(C.(f), s.(f)); end
            end
            C.mode.Value = char(obj.Mode); C.tool.Value = char(obj.Tool); C.signature.Value = char(obj.Signature);
            obj.setNum(C.depth, obj.BurialDepth);
            obj.enable(["preset", "kind", "homeX", "homeY", "previewBtn", "mode", "polygon", obj.GridNames], setup);
            obj.enable(["xmin", "xmax", "ymin", "ymax"], setup && rect);
            C.polygon.ColumnEditable = [true true] & setup & ~rect;
            obj.enable(["tool", "signature", "depth"], setup && obj.Mode == "MANUAL");
            obj.enable(["count", "seed", "clutterSeed", "visibleFraction"], setup && obj.Mode == "RANDOM");
            obj.enable("lock", setup && ~isempty(obj.Pub));
            if setup, C.lock.Text = 'LOCK & START'; else, C.lock.Text = 'LOCKED'; end
        end

        function enable(obj, names, tf)
            s = 'off'; if tf, s = 'on'; end          % uitable accepts only char on/off/inactive, not OnOffSwitchState
            for f = names, obj.Controls.(f).Enable = s; end
        end
    end

    methods (Static, Access = private)
        function setPoints(h, x, y)
            if isempty(x), set(h, 'XData', NaN, 'YData', NaN); else, set(h, 'XData', x(:)', 'YData', y(:)'); end
        end

        function setNum(h, v)
            %SETNUM Show a value in a numeric field when the field can hold it; the model value is never changed here.
            if isnumeric(v) && isscalar(v) && isfinite(v) && v >= h.Limits(1) && v <= h.Limits(2)
                h.Value = double(v);
            end
        end
    end
end
