classdef MissionControlApp < handle
    %MISSIONCONTROLAPP Integrated desktop dashboard for one simulated mission. SIMULATION ONLY.
    %   app = mgv2.ui.MissionControlApp(Name=Value)      see mgv2MissionControl for the options
    %   app.command("start")   same as pressing the button: "start"|"pause"|"resume"|"abort"|"reset"
    %   delete(app)            closes the window and releases every object it created
    %
    %   One run loop lives inside the START/RESUME command and returns on pause, end or close. There is
    %   no timer. drawnow in the loop lets the other buttons interrupt it; re-entry is refused. Panels receive
    %   only MissionSession views, and refresh is decimated so that engine ticks are never skipped: the 3-D scene every
    %   SceneEvery ticks, everything else every RenderEvery ticks. Paced runs drop a scene-only refresh when behind the
    %   clock, and the drop is counted. Scene refreshes are update plus a synchronous drawnow, not measured screen FPS.
    %   Full-panel work is split across two frames so it does not pile up on the tick that also generates sensor
    %   samples: frames fall on odd ticks, leaving the sampling tick free of drawing. Images and map draw one tick after
    %   their samples, telemetry and labels RenderEvery/2 ticks after that. Every label keeps its sample's own time.

    properties (Constant)
        CompactWidth = 1100
        CompactHeight = 720
        FrameOffset = 1           % ticks between a sampling tick and its frame
    end
    properties (SetAccess = private)
        Figure; Session; Panels = struct(); Banner; Controls; Outer; Content
        LayoutMode = ""
        Running = false
        RealTime; RenderEvery; SceneEvery; MaxTicksPerRun
        Perf
        StartupSeconds = NaN      % constructor including the first paint, kept apart from run statistics
    end
    properties (Access = private)
        LastStamp = NaN; PerfClock
        StatusDue = false         % a status frame was dropped: the next sensor frame draws everything
    end
    properties
        AfterRefreshFcn = []      % test and instrumentation hook: fcn(app) after each refresh
    end

    methods
        function app = MissionControlApp(opts)
            arguments
                opts.Visible (1,1) string = "on"
                opts.RealTime (1,1) double {mustBeNonnegative} = 1
                opts.RenderEvery (1,1) double {mustBeInteger, mustBePositive} = 4
                opts.SceneEvery (1,1) double {mustBeInteger, mustBePositive} = 2
                opts.MaxTicksPerRun (1,1) double {mustBePositive} = inf
                opts.Position double = []
                opts.Palette (1,1) string = "IRONBOW"
                opts.MissionConfig struct = mgv2.mission.defaultConfig()
                opts.SensorConfig struct = mgv2.sensors.defaultSensorConfig()
                opts.Environment struct = mgv2.sensors.defaultEnvironment()
                opts.AnomalySource (1,1) mgv2.ui.AnomalySource = mgv2.ui.NullAnomalySource()
            end
            t0 = tic; app.PerfClock = tic;
            app.RealTime = opts.RealTime; app.RenderEvery = opts.RenderEvery; app.SceneEvery = opts.SceneEvery; app.MaxTicksPerRun = opts.MaxTicksPerRun;
            app.Session = mgv2.ui.MissionSession(MissionConfig=opts.MissionConfig, SensorConfig=opts.SensorConfig, ...
                Environment=opts.Environment, AnomalySource=opts.AnomalySource);
            app.clearPerf();
            pos = opts.Position; if isempty(pos), pos = mgv2.ui.MissionControlApp.defaultPosition(); end
            t = mgv2.ui.theme();
            app.Figure = uifigure('Name', 'MineGuard V2 Mission Control (SIMULATION ONLY)', 'Position', pos, 'Color', t.bg, 'Visible', 'off', ...
                'AutoResizeChildren', 'off', 'CloseRequestFcn', @(~, ~) delete(app), 'Tag', 'mgv2_mission_control');
            theme(app.Figure, "dark");      % the layout is dark in any desktop theme, so its controls and table must match
            app.Outer = uigridlayout(app.Figure, [3 1], 'RowHeight', {30, 36, '1x'}, 'ColumnWidth', {'1x'}, 'Padding', [4 4 4 4], 'RowSpacing', 4, 'BackgroundColor', t.bg);
            app.Banner = mgv2.ui.SimulationBanner(app.Outer); app.Banner.Layout.Row = 1;
            app.Controls = mgv2.ui.ControlBar(app.Outer); app.Controls.Layout.Row = 2;
            app.Controls.OnCommand = @(c) app.command(c);
            app.Content = uigridlayout(app.Outer, 'Padding', 0, 'RowSpacing', 4, 'ColumnSpacing', 4, 'BackgroundColor', t.bg);
            app.Content.Layout.Row = 3;
            s = app.Session;
            app.Panels.scene = mgv2.ui.ScenePanel(app.Content); app.Panels.scene.bind(s.World);
            app.Panels.map = mgv2.ui.MapPanel(app.Content); app.Panels.map.bind(s.World, s.MissionConfig, s.Engine.Route);
            app.Panels.rgb = mgv2.ui.RgbPanel(app.Content);
            app.Panels.thermal = mgv2.ui.ThermalPanel(app.Content); app.Panels.thermal.Palette = opts.Palette;
            app.Panels.lidar = mgv2.ui.LidarPanel(app.Content);
            app.Panels.telemetry = mgv2.ui.TelemetryPanel(app.Content);
            app.Panels.events = mgv2.ui.EventInspectorPanel(app.Content);
            app.applyLayout();
            app.Figure.SizeChangedFcn = @(~, ~) app.applyLayout();
            app.refresh();
            app.Figure.Visible = opts.Visible;
            drawnow;
            app.StartupSeconds = toc(t0); app.clearPerf();
        end

        function delete(app)
            if ~isempty(app.Figure) && isvalid(app.Figure)
                app.Figure.CloseRequestFcn = ''; app.Figure.SizeChangedFcn = '';
                delete(app.Figure);
            end
        end

        function command(app, cmd)
            %COMMAND Operator command. The enabling rules in ControlBar apply to the buttons; this guards the rest.
            s = app.Session;
            switch string(cmd)
                case "start"
                    if s.state() == "READY" && ~app.Running, s.start(); app.runLoop(); end
                case "pause"
                    if s.state() == "ACTIVE", s.pauseRun(); app.safeRefresh(); end
                case "resume"
                    if s.state() == "PAUSED" && ~app.Running, s.resumeRun(); app.runLoop(); end
                case "abort"
                    if ismember(s.state(), ["ACTIVE","PAUSED"]), s.abortRun(); app.safeRefresh(); end
                case "reset"
                    if ~app.Running && s.state() ~= "READY"
                        s.reset();
                        for f = string(fieldnames(app.Panels))', app.Panels.(f).resetDisplay(); end
                        app.safeRefresh(); app.clearPerf();
                    end
                otherwise
                    error('mgv2:InvalidCommand', 'Unknown command "%s".', string(cmd));
            end
        end

        function p = perfSummary(app)
            %PERFSUMMARY Measured wall-clock figures of this run so far. Not an acceptance result.
            P = app.Perf; p = struct('ticks', P.ticks, 'sim_s', P.sim_s, 'wall_s', P.wall_s, 'sim_to_wall', P.sim_s / max(P.wall_s, eps), 'late_ticks', P.late, ...
                'refreshes', numel(P.present_ms), 'stalls_over_100ms', nnz(P.frame_ms > 100), ...
                'skipped_scene', P.skipped, 'max_behind_s', P.max_behind, 'refresh_rate', numel(P.present_ms) / max(P.wall_s, eps), ...
                'gaps_over_100ms', nnz(P.gap_ms > 100), 'gaps_over_250ms', nnz(P.gap_ms > 250), 'gaps_over_1s', nnz(P.gap_ms > 1000));
            m = struct('step_ms', P.step_ms, 'present_ms', P.present_ms, 'drawnow_ms', P.drawnow_ms, 'frame_ms', P.frame_ms, 'gap_ms', P.gap_ms, 'scene_ms', P.panel_ms.scene, 'map_ms', P.panel_ms.map, ...
                'rgb_ms', P.panel_ms.rgb, 'thermal_ms', P.panel_ms.thermal, 'lidar_ms', P.panel_ms.lidar, 'telemetry_ms', P.panel_ms.telemetry, 'events_ms', P.panel_ms.events);
            for f = string(fieldnames(m))'
                v = sort(m.(f));
                if isempty(v), p.(f) = struct('median', NaN, 'p95', NaN, 'max', NaN);
                else, p.(f) = struct('median', median(v), 'p95', v(ceil(0.95 * numel(v))), 'max', v(end));
                end
            end
        end
    end

    methods (Access = private)
        function runLoop(app)
            %RUNLOOP Advance the engine until paused, terminal, the per-run budget, or window close.
            app.Running = true; guard = onCleanup(@() app.endRun()); %#ok<NASGU>
            app.LastStamp = NaN; s = app.Session; ticks = 0; base = s.Engine.time(); tw = tic; simBefore = app.Perf.sim_s; wallBefore = app.Perf.wall_s;
            while ticks < app.MaxTicksPerRun
                if app.RealTime > 0
                    lag = (s.Engine.time() - base) / app.RealTime - toc(tw);
                    if lag > 0, pause(lag); if ~isvalid(app), return; end
                    elseif lag < -0.05, app.Perf.late = app.Perf.late + 1;
                    end
                    app.Perf.max_behind = max(app.Perf.max_behind, -lag);
                end
                t0 = tic; advanced = s.step();
                if ~advanced, break; end
                app.Perf.step_ms(end+1, 1) = 1e3 * toc(t0); ticks = ticks + 1; app.Perf.ticks = app.Perf.ticks + 1;
                app.Perf.sim_s = simBefore + s.Engine.time() - base; app.Perf.wall_s = wallBefore + toc(tw);
                n = s.Engine.TickId - app.FrameOffset; behind = app.RealTime > 0 && (s.Engine.time() - base) / app.RealTime - toc(tw) < -0.05;
                if s.Engine.isTerminal() || mod(app.RenderEvery, 2) ~= 0 && mod(n, app.RenderEvery) == 0 || app.StatusDue && mod(n, app.RenderEvery) == 0
                    app.StatusDue = false; app.refresh();
                elseif mod(n, app.RenderEvery) == 0
                    app.refreshSensors();
                elseif mod(app.RenderEvery, 2) == 0 && mod(n, app.RenderEvery) == app.RenderEvery / 2
                    if behind, app.StatusDue = true; app.Perf.skipped = app.Perf.skipped + 1; else, app.refreshStatus(); end
                elseif mod(n, app.SceneEvery) == 0
                    if behind, app.Perf.skipped = app.Perf.skipped + 1; else, app.refreshScene(); end   % the clock has priority
                end
                if ~isvalid(app), return; end
            end
            app.Running = false;
            if s.state() == "ACTIVE", s.pauseRun(); end     % budget used: hold the clock, RESUME continues the sequence
            app.safeRefresh();
        end

        function endRun(app)
            if isvalid(app), app.Running = false; end   % also on an error, so the commands are not left locked
        end

        function safeRefresh(app)
            if isvalid(app), app.refresh(); end
        end

        function refresh(app)
            %REFRESH Draw one view and measure what the display costs (wall clock, never used for timestamps).
            tf = tic; v = app.Session.view();
            v.perf = struct('sim_to_wall', app.Perf.sim_s / max(app.Perf.wall_s, eps));
            if app.Perf.wall_s == 0, v.perf.sim_to_wall = NaN; end
            for f = string(fieldnames(app.Panels))'
                t0 = tic; app.Panels.(f).present(v); app.Perf.panel_ms.(f)(end+1, 1) = 1e3 * toc(t0);
            end
            app.Controls.present(v, app.Running);
            app.finishRefresh(tf);
        end

        function refreshSensors(app)
            %REFRESHSENSORS Scene, images and map: everything tied to the samples of this tick.
            tf = tic; v = app.Session.view();
            t0 = tic; app.Panels.scene.presentPose(v.pose); app.Perf.panel_ms.scene(end+1, 1) = 1e3 * toc(t0);
            for f = ["rgb", "thermal", "map"]
                t0 = tic; app.Panels.(f).present(v); app.Perf.panel_ms.(f)(end+1, 1) = 1e3 * toc(t0);
            end
            app.finishRefresh(tf);
        end

        function refreshStatus(app)
            %REFRESHSTATUS Scene plus telemetry, LiDAR, events and the labels and commands of the clock readout.
            tf = tic; v = app.Session.view();
            v.perf = struct('sim_to_wall', app.Perf.sim_s / max(app.Perf.wall_s, eps));
            for f = ["scene", "lidar", "telemetry", "events"]
                t0 = tic; app.Panels.(f).present(v); app.Perf.panel_ms.(f)(end+1, 1) = 1e3 * toc(t0);
            end
            app.Controls.present(v, app.Running);
            app.finishRefresh(tf);
        end

        function refreshScene(app)
            %REFRESHSCENE 3-D scene only, between full refreshes.
            tf = tic; p = app.Session.pose();
            t0 = tic; app.Panels.scene.presentPose(p); app.Perf.panel_ms.scene(end+1, 1) = 1e3 * toc(t0);
            app.finishRefresh(tf);
        end

        function finishRefresh(app, tf)
            app.Perf.present_ms(end+1, 1) = 1e3 * toc(tf);
            t0 = tic; drawnow; if ~isvalid(app), return; end
            app.Perf.drawnow_ms(end+1, 1) = 1e3 * toc(t0); app.Perf.frame_ms(end+1, 1) = 1e3 * toc(tf);
            now = toc(app.PerfClock);
            if ~isnan(app.LastStamp), app.Perf.gap_ms(end+1, 1) = 1e3 * (now - app.LastStamp); end
            app.LastStamp = now;
            if ~isempty(app.AfterRefreshFcn), app.AfterRefreshFcn(app); end
        end

        function clearPerf(app)
            e = zeros(0, 1);
            app.Perf = struct('ticks', 0, 'sim_s', 0, 'wall_s', 0, 'late', 0, 'skipped', 0, 'max_behind', 0, 'gap_ms', e, 'step_ms', e, 'present_ms', e, 'drawnow_ms', e, 'frame_ms', e, ...
                'panel_ms', struct('scene', e, 'map', e, 'rgb', e, 'thermal', e, 'lidar', e, 'telemetry', e, 'events', e));
        end

        function applyLayout(app)
            %APPLYLAYOUT Wide: all panels on one screen. Compact: two scrolling columns. Banner and controls stay fixed.
            if ~isvalid(app) || ~isvalid(app.Figure), return; end
            pos = app.Figure.Position;
            if pos(3) < app.CompactWidth || pos(4) < app.CompactHeight, mode = "compact"; else, mode = "wide"; end
            if mode == app.LayoutMode, return; end
            app.LayoutMode = mode; c = app.Content; P = app.Panels;
            if mode == "wide"
                c.Scrollable = 'off'; c.ColumnWidth = repmat({'1x'}, 1, 6); c.RowHeight = {'2x', '1.35x', 178};
                app.Outer.RowHeight{1} = 30;
                L = {'scene', 1, [1 3]; 'map', 1, [4 6]; 'rgb', 2, [1 2]; 'thermal', 2, [3 4]; 'lidar', 2, [5 6]; 'telemetry', 3, [1 4]; 'events', 3, [5 6]};
            else
                c.Scrollable = 'on'; c.ColumnWidth = {'1x', '1x'}; c.RowHeight = {300, 240, 240, 196, 170};
                app.Outer.RowHeight{1} = 48;
                L = {'scene', 1, 1; 'map', 1, 2; 'rgb', 2, 1; 'thermal', 2, 2; 'lidar', 3, [1 2]; 'telemetry', 4, [1 2]; 'events', 5, [1 2]};
            end
            for k = 1:size(L, 1)
                h = P.(L{k, 1}); h.Layout.Row = L{k, 2}; h.Layout.Column = L{k, 3};
            end
        end
    end

    methods (Static)
        function pos = defaultPosition()
            %DEFAULTPOSITION Fit the display, leaving room for the menu bar and window title.
            sz = get(groot, 'ScreenSize');
            w = min(1500, sz(3) - 24); h = min(940, sz(4) - 90);
            pos = [sz(1) + max(0, round((sz(3) - w) / 2)), sz(2) + max(30, round((sz(4) - h) / 2) - 20), w, h];
        end
    end
end
