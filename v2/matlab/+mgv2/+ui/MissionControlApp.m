classdef MissionControlApp < handle
    %MISSIONCONTROLAPP Integrated desktop dashboard for one simulated mission. SIMULATION ONLY.
    %   app = mgv2.ui.MissionControlApp(Name=Value)      see mgv2MissionControl for the options
    %   app.command("start")   same as pressing the button: "start"|"pause"|"resume"|"abort"|"reset"
    %   app.configure(scenario, seed)   same as the scenario and seed controls, before a start
    %   app.toggleExpand("rgb")         panel fills the window, or is restored
    %   app.selectEvent(id)             show verified evidence of one public event
    %   folder = app.exportRun()        same as EXPORT: package of the finished live run under ExportRoot (V2-008)
    %   app.replay(folder)              same as REPLAY: verify a package and load it for replay; START plays it
    %   An export or replay failure is shown on the control bar and never reported as success.
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
        Expanded = ""             % panel filling the window, or ""
        Running = false
        RealTime; RenderEvery; SceneEvery; MaxTicksPerRun
        Perf
        StartupSeconds = NaN      % constructor including the first paint, kept apart from run statistics
        ExportRoot                % folder that receives run packages
        LastExport = ""           % package written for the current run, "" if none
        LastReplay = struct('done', false, 'match', false, 'detail', "")   % replayCheck after a replay ended
    end
    properties (Access = private)
        LastStamp = NaN; PerfClock
        StatusDue = false         % a status frame was dropped: the next sensor frame draws everything
        EndedGeneration = NaN     % generation whose end OnRunEnded already reported
    end
    properties
        AfterRefreshFcn = []      % test and instrumentation hook: fcn(app) after each refresh
        OnRunEnded = []           % fcn(app) once when a live run reaches a terminal phase (V2.1 post-run evaluation)
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
                opts.ExportRoot (1,1) string = mgv2.ui.MissionControlApp.defaultExportRoot()
                opts.SceneConfig struct = mgv2.scene.defaultSceneConfig()
                opts.SurfaceFeatures = []          % PRIVATE: passed to the session's sensors only (V2.1)
                opts.CommitmentSalt (1,1) string = ""   % PRIVATE salt of the export commitment (V2.1)
            end
            app.ExportRoot = opts.ExportRoot;
            t0 = tic; app.PerfClock = tic;
            app.RealTime = opts.RealTime; app.RenderEvery = opts.RenderEvery; app.SceneEvery = opts.SceneEvery; app.MaxTicksPerRun = opts.MaxTicksPerRun;
            app.Session = mgv2.ui.MissionSession(MissionConfig=opts.MissionConfig, SensorConfig=opts.SensorConfig, ...
                Environment=opts.Environment, AnomalySource=opts.AnomalySource, SceneConfig=opts.SceneConfig, ...
                SurfaceFeatures=opts.SurfaceFeatures, CommitmentSalt=opts.CommitmentSalt);
            app.clearPerf();
            pos = opts.Position; if isempty(pos), pos = mgv2.ui.MissionControlApp.defaultPosition(); end
            t = mgv2.ui.theme();
            app.Figure = uifigure('Name', 'MineGuard V2 Mission Control (SIMULATION ONLY)', 'Position', pos, 'Color', t.bg, 'Visible', 'off', ...
                'AutoResizeChildren', 'off', 'CloseRequestFcn', @(~, ~) delete(app), 'Tag', 'mgv2_mission_control');
            theme(app.Figure, "dark");      % the layout is dark in any desktop theme, so its controls and table must match
            app.Outer = uigridlayout(app.Figure, [3 1], 'RowHeight', {30, 78, '1x'}, 'ColumnWidth', {'1x'}, 'Padding', [4 4 4 4], 'RowSpacing', 4, 'BackgroundColor', t.bg);
            app.Banner = mgv2.ui.SimulationBanner(app.Outer); app.Banner.Layout.Row = 1;
            app.Controls = mgv2.ui.ControlBar(app.Outer); app.Controls.Layout.Row = 2;
            app.Controls.OnCommand = @(c) app.command(c);
            app.Controls.OnConfigure = @(sc, seed) app.configure(sc, seed);
            app.Content = uigridlayout(app.Outer, 'Padding', 0, 'RowSpacing', 4, 'ColumnSpacing', 4, 'BackgroundColor', t.bg);
            app.Content.Layout.Row = 3;
            s = app.Session;
            app.Panels.scene = mgv2.ui.ScenePanel(app.Content); app.Panels.scene.bind(s.World);
            app.Panels.map = mgv2.ui.MapPanel(app.Content); app.Panels.map.bind(s.World, s.MissionConfig, s.Engine.Route);
            app.Panels.rgb = mgv2.ui.RgbPanel(app.Content);
            app.Panels.thermal = mgv2.ui.ThermalPanel(app.Content); app.Panels.thermal.setPalette(opts.Palette);
            app.Panels.lidar = mgv2.ui.LidarPanel(app.Content);
            app.Panels.telemetry = mgv2.ui.TelemetryPanel(app.Content);
            app.Panels.events = mgv2.ui.EventInspectorPanel(app.Content);
            app.Panels.map.OnPick = @(x, y) app.pickOnMap(x, y);
            app.Panels.events.OnSelect = @(id) app.selectEvent(id);
            for f = string(fieldnames(app.Panels))', app.Panels.(f).OnExpand = @() app.toggleExpand(f); end
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
            if ~isempty(app.Session) && isvalid(app.Session), delete(app.Session); end   % releases the source for another session
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
                    if ismember(s.state(), ["ACTIVE","PAUSED"]), s.abortRun(); app.safeRefresh(); app.notifyEnded(); end
                case "reset"
                    if ~app.Running && s.state() ~= "READY"
                        s.reset(); app.LastExport = ""; app.Controls.setNotice("", false);   % a notice belongs to the run it describes
                        for f = string(fieldnames(app.Panels))', app.Panels.(f).resetDisplay(); end
                        app.safeRefresh(); app.clearPerf();
                    end
                case "export"
                    app.exportRun();
                case "replay"
                    if app.Running || s.state() == "ACTIVE", return; end
                    folder = app.LastExport;
                    if strlength(folder) == 0
                        folder = uigetdir(app.ExportRoot, 'Choose a MineGuard run package');
                        if isequal(folder, 0), return; end
                    end
                    app.replay(folder);
                otherwise
                    error('mgv2:InvalidCommand', 'Unknown command "%s".', string(cmd));
            end
        end

        function folder = exportRun(app)
            %EXPORTRUN Package the finished live run. The result, or the reason for failure, is shown on the control bar.
            folder = "";
            if app.Running, return; end
            try
                folder = app.Session.exportRun(app.ExportRoot); app.LastExport = folder;
                app.Controls.setNotice("Exported " + folder, false);
            catch err
                app.Controls.setNotice("EXPORT FAILED: " + err.message, true);
                if ~startsWith(err.identifier, "mgv2:"), rethrow(err); end
            end
            app.safeRefresh();
        end

        function replay(app, folder)
            %REPLAY Verify a package and load it for replay. A refused package changes nothing and the reason is shown.
            if app.Running || app.Session.state() == "ACTIVE", return; end
            try
                app.Session.loadReplay(folder);
            catch err
                app.Controls.setNotice("REPLAY REFUSED: " + err.message, true);
                if ~startsWith(err.identifier, "mgv2:"), rethrow(err); end
                return
            end
            app.LastReplay = struct('done', false, 'match', false, 'detail', "");
            for f = string(fieldnames(app.Panels))', app.Panels.(f).resetDisplay(); end
            app.Controls.setNotice("Replay of " + app.Session.packageName() + " ready: press START", false);
            app.safeRefresh(); app.clearPerf();
        end

        function configure(app, scenario, seed)
            %CONFIGURE New scenario or mission seed before a start. Refused once a run has begun.
            if app.Running || app.Session.state() ~= "READY", return; end
            app.Session.configure(scenario, seed); app.LastExport = ""; app.Controls.setNotice("", false);
            for f = string(fieldnames(app.Panels))', app.Panels.(f).resetDisplay(); end
            app.safeRefresh(); app.clearPerf();
        end

        function toggleExpand(app, name)
            %TOGGLEEXPAND Let one panel fill the window for inspection. All panels keep receiving every view.
            name = string(name);
            if ~isfield(app.Panels, name), error('mgv2:InvalidCommand', 'Unknown panel "%s".', name); end
            if app.Expanded == name, name = ""; end
            if app.Expanded ~= "", app.Panels.(app.Expanded).setExpanded(false); end
            app.Expanded = name;
            if name ~= "", app.Panels.(name).setExpanded(true); end
            app.LayoutMode = ""; app.applyLayout();
        end

        function selectEvent(app, eventId)
            %SELECTEVENT Open the inspector on one public event id. An evidence failure is displayed, never replaced.
            eventId = string(eventId); P = app.Panels; ev = app.Session.view(false).events; P.events.select(eventId); k = [];
            if ~isempty(ev), k = find(string({ev.event_id}) == eventId); end
            if isscalar(k), P.map.setSelected(ev(k).x_est_m, ev(k).y_est_m); else, P.map.setSelected(NaN, NaN); end
            if app.Expanded ~= "events", app.toggleExpand("events"); end
            try
                P.events.showInspection(app.Session.inspectCurrentRun(eventId));
            catch err
                P.events.showInspectionError(eventId, err.message);
                if startsWith(err.identifier, "MATLAB:"), rethrow(err); end
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
        function pickOnMap(app, x, y)
            %PICKONMAP A click on a map marker selects the nearest listed event.
            ev = app.Session.view(false).events;
            if isempty(ev), return; end
            [~, k] = min(hypot([ev.x_est_m] - x, [ev.y_est_m] - y));
            app.selectEvent(ev(k).event_id);
        end

        function runLoop(app)
            %RUNLOOP Advance the engine until paused, terminal, the per-run budget, or window close.
            app.Running = true; guard = onCleanup(@() app.endRun());
            app.LastStamp = NaN; s = app.Session; ticks = 0; base = s.Engine.time(); tw = tic; simBefore = app.Perf.sim_s; wallBefore = app.Perf.wall_s;
            while ticks < app.MaxTicksPerRun
                if app.RealTime > 0
                    lag = (s.Engine.time() - base) / app.RealTime - toc(tw);
                    if lag > 0, pause(lag); if ~isvalid(app), return; end
                    elseif lag < -0.05, app.Perf.late = app.Perf.late + 1;
                    end
                    app.Perf.max_behind = max(app.Perf.max_behind, -lag);
                end
                t0 = tic;
                try
                    advanced = s.step();
                catch err
                    s.abortOnFault(err.message); advanced = false;      % shown in telemetry; a resume could not recover the lost samples
                end
                if ~advanced, break; end
                app.Perf.step_ms(end+1, 1) = 1e3 * toc(t0); ticks = ticks + 1; app.Perf.ticks = app.Perf.ticks + 1;
                app.Perf.sim_s = simBefore + s.Engine.time() - base; app.Perf.wall_s = wallBefore + toc(tw);
                n = s.Engine.TickId - app.FrameOffset; behind = app.RealTime > 0 && (s.Engine.time() - base) / app.RealTime - toc(tw) < -0.05;
                if s.Engine.isTerminal() || mod(app.RenderEvery, 2) ~= 0 && mod(n, app.RenderEvery) == 0 || app.StatusDue && mod(n, app.RenderEvery) == 0
                    app.StatusDue = false; app.refresh();
                elseif mod(n, app.RenderEvery) == 0
                    app.refreshSensors();
                elseif mod(app.RenderEvery, 2) == 0 && mod(n, app.RenderEvery) == app.RenderEvery / 2
                    if behind, s.view(); app.StatusDue = true; app.Perf.skipped = app.Perf.skipped + 1; else, app.refreshStatus(); end
                elseif mod(n, app.SceneEvery) == 0
                    if behind, app.Perf.skipped = app.Perf.skipped + 1; else, app.refreshScene(); end   % the clock has priority
                end
                if ~isvalid(app), return; end
            end
            app.Running = false;
            if s.state() == "ACTIVE", s.pauseRun(); end     % budget used: hold the clock, RESUME continues the sequence
            app.notifyEnded();
            if s.Mode == "REPLAY" && s.state() == "ENDED"
                r = s.replayCheck(); app.LastReplay = r;
                app.Controls.setNotice("Replay ended: " + r.detail, ~r.match);
            end
            app.safeRefresh();
        end

        function notifyEnded(app)
            %NOTIFYENDED Call OnRunEnded once per live run that reached a terminal phase (never for a replay).
            s = app.Session;
            if ~isvalid(app) || isempty(app.OnRunEnded) || s.Mode ~= "LIVE" || s.state() ~= "ENDED", return; end
            g = s.evidenceContext().generation;
            if isequal(app.EndedGeneration, g), return; end
            app.EndedGeneration = g; app.OnRunEnded(app);
        end

        function endRun(app)
            if isvalid(app), app.Running = false; end   % also on an error, so the commands are not left locked
        end

        function safeRefresh(app)
            if isvalid(app), app.refresh(); end
        end

        function refresh(app)
            %REFRESH Draw one view and measure what the display costs (wall clock, never used for timestamps).
            tf = tic; v = app.Session.view(); v.exported = strlength(app.LastExport) > 0;
            v.perf = struct('sim_to_wall', app.Perf.sim_s / max(app.Perf.wall_s, eps));
            if app.Perf.wall_s == 0, v.perf.sim_to_wall = NaN; end
            for f = string(fieldnames(app.Panels))'
                t0 = tic; app.Panels.(f).present(v); app.Perf.panel_ms.(f)(end+1, 1) = 1e3 * toc(t0);
            end
            app.syncSelection(v); app.Controls.present(v, app.Running);
            app.finishRefresh(tf);
        end

        function syncSelection(app, v)
            %SYNCSELECTION The ring follows the selected event's current estimate, and goes when the event is no longer listed.
            id = app.Panels.events.SelectedId; x = NaN; y = NaN;
            if strlength(id) > 0 && ~isempty(v.events)
                k = find(string({v.events.event_id}) == id);
                if isscalar(k), x = v.events(k).x_est_m; y = v.events(k).y_est_m; end
            end
            app.Panels.map.setSelected(x, y);
        end

        function refreshSensors(app)
            %REFRESHSENSORS Scene, images and map: everything tied to the samples of this tick.
            tf = tic; v = app.Session.view(false);       % the source is read once per RenderEvery, in refreshStatus
            t0 = tic; app.Panels.scene.presentPose(v.pose); app.Perf.panel_ms.scene(end+1, 1) = 1e3 * toc(t0);
            for f = ["rgb", "thermal", "map"]
                t0 = tic; app.Panels.(f).present(v); app.Perf.panel_ms.(f)(end+1, 1) = 1e3 * toc(t0);
            end
            app.finishRefresh(tf);
        end

        function refreshStatus(app)
            %REFRESHSTATUS Scene plus telemetry, LiDAR, events and the labels and commands of the clock readout.
            tf = tic; v = app.Session.view(); v.exported = strlength(app.LastExport) > 0;
            v.perf = struct('sim_to_wall', app.Perf.sim_s / max(app.Perf.wall_s, eps));
            for f = ["scene", "lidar", "telemetry", "events"]
                t0 = tic; app.Panels.(f).present(v); app.Perf.panel_ms.(f)(end+1, 1) = 1e3 * toc(t0);
            end
            app.syncSelection(v); app.Controls.present(v, app.Running);
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
            if pos(3) < app.CompactWidth || pos(4) < app.CompactHeight, app.Outer.RowHeight{1} = 48; else, app.Outer.RowHeight{1} = 30; end
            names = string(fieldnames(P))';
            for f = names, P.(f).Visible = matlab.lang.OnOffSwitchState(app.Expanded == "" || f == app.Expanded); end
            if app.Expanded ~= ""
                for f = names, P.(f).Layout.Row = 1; P.(f).Layout.Column = 1; end
                c.Scrollable = 'off'; c.RowHeight = {'1x'}; c.ColumnWidth = {'1x'};
                return
            end
            if mode == "wide"
                c.Scrollable = 'off'; c.ColumnWidth = repmat({'1x'}, 1, 6); c.RowHeight = {'2x', '1.35x', 178};
                L = {'scene', 1, [1 3]; 'map', 1, [4 6]; 'rgb', 2, [1 2]; 'thermal', 2, [3 4]; 'lidar', 2, [5 6]; 'telemetry', 3, [1 4]; 'events', 3, [5 6]};
            else
                c.Scrollable = 'on'; c.ColumnWidth = {'1x', '1x'}; c.RowHeight = {300, 240, 240, 196, 170};
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

        function r = defaultExportRoot()
            %DEFAULTEXPORTROOT <userpath>/MineGuard-runs, or the temporary folder when MATLAB has no userpath.
            u = string(userpath); if strlength(u) == 0, u = string(tempdir); end
            r = string(fullfile(u, "MineGuard-runs"));
        end
    end
end
