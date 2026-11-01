classdef testV2007MissionControlUI < matlab.uitest.TestCase
    %TESTV2007MISSIONCONTROLUI V2-007 Stage 1 GUI tests. They open real windows and press real buttons. SIMULATED.
    %   From the repository root:  addpath('v2/matlab'); runtests('v2/matlab/tests/testV2007MissionControlUI.m')
    %   Needs a graphics desktop. Every display assertion compares against the sample the sensors actually produced.

    properties
        App
    end

    methods (TestClassSetup)
        function setup(tc)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(here)));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(here));
        end
    end

    methods (TestMethodTeardown)
        function closeApp(tc)
            if ~isempty(tc.App) && isvalid(tc.App), delete(tc.App); end
            tc.App = [];
        end
    end

    methods (Access = private)
        function app = open(tc, varargin)
            app = mgv2MissionControl('RealTime', 0, varargin{:}); tc.App = app;
        end
        function app = flown(tc, ticks, varargin)
            app = tc.open('MaxTicksPerRun', ticks, varargin{:});
            tc.press(app.Controls.Buttons.start); drawnow;
        end
        function settle(~, cond)
            %SETTLE Window resizing is applied asynchronously by the desktop: wait for it, bounded at 10 s.
            t0 = tic;
            while ~cond() && toc(t0) < 10, drawnow; pause(0.05); end
        end
        function assertWarningVisible(tc, app)
            f = app.Figure.Position; b = app.Banner;
            tc.settle(@() abs(b.Position(3) - (f(3) - 8)) <= 1 && b.Position(2) + b.Position(4) <= f(4) + 1);
            tc.verifyEqual(string(b.Label.Text), mgv2.ui.theme().warning);
            tc.verifyTrue(strcmp(b.Visible, 'on') && strcmp(b.Label.Visible, 'on'));
            p = b.Position;
            tc.verifyGreaterThan(p(3), 0.9 * (f(3) - 8), 'banner must span the window');
            tc.verifyGreaterThanOrEqual(p(4), 24);
            tc.verifyLessThanOrEqual(p(2) + p(4), f(4) + 1, 'banner must stay inside the window');
        end
        function txt = visibleText(~, app)
            %VISIBLETEXT Every string a user could read in the window, including legends and table headers.
            all = findall(app.Figure); txt = strings(0);
            for k = 1:numel(all)
                h = all(k);
                for p = ["Text","String","Title","Name","Items","ColumnName","DisplayName"]
                    if isprop(h, p)
                        v = h.(p);
                        if ischar(v) || isstring(v) || iscellstr(v), txt = [txt; string(v(:))]; end %#ok<AGROW>
                    end
                end
                if isa(h, 'matlab.ui.control.Table') && ~isempty(h.Data), txt = [txt; string(h.Data(:))]; end %#ok<AGROW>
            end
            for ax = findall(app.Figure, '-isa', 'matlab.graphics.axis.AbstractAxes')'
                txt = [txt; string(ax.XLabel.String); string(ax.YLabel.String); string(ax.Title.String)]; %#ok<AGROW>
            end
        end
    end

    methods (Test)
        function startupAndClose(tc)
            before = numel(findall(groot, 'Type', 'figure'));
            app = tc.open(); fig = app.Figure;
            tc.verifyTrue(isvalid(fig)); tc.verifyEqual(string(fig.Visible), "on");
            tc.verifyEqual(app.Session.state(), "READY");
            tc.verifyEqual(app.Session.Engine.TickId, 0);
            tc.verifyEqual(string(app.Controls.Buttons.start.Enable), "on");
            tc.verifyEqual(string(app.Controls.Buttons.pause.Enable), "off");
            tc.verifySubstring(string(app.Controls.Readout.Text), "CONFIGURED");
            tc.verifySubstring(string(app.Controls.Readout.Text), "seed " + app.Session.MissionConfig.seed);
            close(fig); drawnow;                    % the same path as the window close button
            tc.verifyFalse(isvalid(fig)); tc.verifyFalse(isvalid(app));
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), before);
        end

        function startAdvancesThenBudgetHolds(tc)
            app = tc.flown(40);
            tc.verifyEqual(app.Session.Engine.TickId, 40);
            tc.verifyEqual(app.Session.state(), "PAUSED");
            tc.verifySubstring(string(app.Controls.Readout.Text), "tick 40");
            tc.verifyEqual(string(app.Controls.Buttons.resume.Enable), "on");
            tc.verifyEqual(string(app.Controls.Buttons.start.Enable), "off");
        end

        function pauseButtonFreezesAndResumeContinues(tc)
            app = tc.open('MaxTicksPerRun', 60);
            % pressing during the run has to happen inside the run loop's refresh, which the framework warns about
            old = warning('off', 'MATLAB:uiautomation:Driver:WarnInHGCallbacks'); restore = onCleanup(@() warning(old)); %#ok<NASGU>
            app.AfterRefreshFcn = @(a) tc.pressOnceAt(a, 16);
            tc.press(app.Controls.Buttons.start); drawnow;
            app.AfterRefreshFcn = [];
            tc.verifyEqual(app.Session.Engine.TickId, 16, 'pause pressed during the run must stop at that tick');
            tc.verifyEqual(app.Session.state(), "PAUSED");
            frame = app.Session.Sensors.latest("RGB_NADIR").frame_id; label = string(app.Panels.rgb.StatusLabel.Text);
            tc.verifyFalse(app.Session.step(), 'a paused engine executes no tick');
            app.command("pause"); drawnow;
            tc.verifyEqual(app.Session.Sensors.latest("RGB_NADIR").frame_id, frame);
            tc.verifyEqual(string(app.Panels.rgb.StatusLabel.Text), label);
            tc.press(app.Controls.Buttons.resume); drawnow;
            tc.verifyEqual(app.Session.Engine.TickId, 76);
        end

        function abortAndResetAreDeterministic(tc)
            app = tc.flown(40);
            first = app.Session.Sensors.latest("RGB_NADIR").image_rgb_uint8;
            tc.press(app.Controls.Buttons.abort); drawnow;
            tc.verifyEqual(app.Session.Engine.Phase, "ABORTED");
            tc.verifyEqual(string(app.Controls.Buttons.resume.Enable), "off");
            tc.verifyEqual(string(app.Controls.Buttons.abort.Enable), "off");
            tc.press(app.Controls.Buttons.reset); drawnow;
            tc.verifyEqual(app.Session.Engine.TickId, 0);
            tc.verifyEqual(app.Session.state(), "READY");
            tc.verifySize(app.Panels.map.H.flown.XData, [1 1]);
            tc.press(app.Controls.Buttons.start); drawnow;
            tc.verifyEqual(app.Session.Sensors.latest("RGB_NADIR").image_rgb_uint8, first, 'same seed must give the same frame after reset');
        end

        function sceneShowsActualPose(tc)
            app = tc.flown(120); p = app.Session.Engine.snapshot(); r = app.Panels.scene.Renderer;
            M = r.Handles.aircraft.Matrix;
            tc.verifyEqual(M(1:3, 4)', p.position_enu_m, 'AbsTol', 1e-12);
            tc.verifyEqual(M(1:3, 1:3), mgv2.frames.quatToRotm(p.orientation_quat), 'AbsTol', 1e-12);
            tc.verifyEqual(r.Axes, app.Panels.scene.Axes);
            tc.verifyEqual(size(r.Handles.terrain.Vertices, 1), size(app.Session.World.V, 1));
            tc.verifyEqual(string(r.Handles.hud.Visible), "off");
            tc.verifySubstring(string(app.Panels.scene.StatusLabel.Text), sprintf("t=%.2f s", p.t_s));
            drawnow; shot = getframe(app.Panels.scene.Axes);
            tc.verifyGreaterThan(std(double(shot.cdata(:))), 5, 'the 3-D view must not be blank');
            for m = string(app.Panels.scene.CameraDropdown.Items)
                tc.choose(app.Panels.scene.CameraDropdown, m); drawnow;
                tc.verifyEqual(r.CameraMode, m);
            end
        end

        function rgbShowsActualSample(tc)
            app = tc.flown(120); s = app.Session.Sensors.latest("RGB_NADIR");
            tc.verifyEqual(app.Panels.rgb.Image.CData, s.image_rgb_uint8);
            tc.verifyEqual(string(app.Panels.rgb.StatusLabel.Text), sprintf("t=%.2f s | tick %d | VALID", s.t_s, s.tick_id));
            drawnow; shot = getframe(app.Panels.rgb.Axes);
            tc.verifyGreaterThan(std(double(shot.cdata(:))), 2);
        end

        function thermalShowsKelvinWithLegend(tc)
            app = tc.flown(120); s = app.Session.Sensors.latest("THERMAL_LWIR"); P = app.Panels.thermal;
            lim = [s.display_min_K s.display_max_K];
            tc.verifyEqual(P.Image.CData, mgv2.sensors.thermalPalette(s.temperature_K, "IRONBOW", lim));
            tc.verifyEqual(string(P.Colorbar.Visible), "on");
            tc.verifyEqual(P.Colorbar.Limits, lim, 'AbsTol', 1e-9);
            tc.verifySubstring(string(P.Colorbar.Label.String), "[K]");
            tc.verifyEqual(string(P.StatusLabel.Text), sprintf("t=%.2f s | tick %d | VALID", s.t_s, s.tick_id));
        end

        function paletteChangesDisplayNotKelvin(tc)
            a = tc.flown(40); k1 = a.Session.Sensors.latest("THERMAL_LWIR"); c1 = a.Panels.thermal.Image.CData; delete(a);
            b = tc.flown(40, 'Palette', "WHITE_HOT"); k2 = b.Session.Sensors.latest("THERMAL_LWIR");
            tc.verifyEqual(k2.temperature_K, k1.temperature_K);
            tc.verifyNotEqual(b.Panels.thermal.Image.CData, c1);
        end

        function lidarShowsValidReturnsOnly(tc)
            app = tc.flown(120); s = app.Session.Sensors.latest("LIDAR_TERRAIN"); h = app.Panels.lidar.Points;
            tc.assertGreaterThan(s.return_count, 0, 'at this tick the aircraft is in range');
            P = s.points_enu_m(s.valid_ray_mask, :);
            tc.verifyEqual([h.XData(:) h.YData(:) h.ZData(:)], P);
            tc.verifySubstring(string(app.Panels.lidar.StatusLabel.Text), sprintf("t=%.2f s | tick %d | VALID", s.t_s, s.tick_id));
            tc.verifySubstring(string(app.Panels.lidar.StatusLabel.Text), sprintf("%d/%d returns", s.return_count, numel(s.valid_ray_mask)));
        end

        function invalidLidarAtTickZeroIsLabelled(tc)
            app = tc.open(); s = app.Session.Sensors.latest("LIDAR_TERRAIN");
            tc.assertFalse(s.valid, 'on the pad the default LiDAR sample is out of range');
            tc.verifySubstring(string(app.Panels.lidar.StatusLabel.Text), "INVALID " + s.invalid_reason);
            tc.verifySubstring(string(app.Panels.lidar.Overlay.String), s.invalid_reason);
            tc.verifyTrue(all(isnan(app.Panels.lidar.Points.XData)), 'no invented points');
        end

        function dropoutLabelsWithoutInventingData(tc)
            cfg = mgv2.sensors.defaultSensorConfig();
            cfg.THERMAL_LWIR.dropout_model.intervals_s = [1 100]; cfg.RGB_NADIR.dropout_model.intervals_s = [1 100];
            app = tc.flown(60, 'SensorConfig', cfg);
            r = app.Session.Sensors.latest("RGB_NADIR"); t = app.Session.Sensors.latest("THERMAL_LWIR");
            tc.assertFalse(r.valid); tc.assertFalse(t.valid);
            tc.verifySubstring(string(app.Panels.rgb.StatusLabel.Text), "INVALID SENSOR_DROPOUT");
            tc.verifySubstring(string(app.Panels.rgb.Overlay.String), "SENSOR_DROPOUT");
            tc.verifySubstring(string(app.Panels.thermal.StatusLabel.Text), sprintf("t=%.2f s", t.t_s));
            tc.verifyEqual(string(app.Panels.thermal.Colorbar.Visible), "off", 'no temperature scale without temperatures');
            tc.verifyEqual(app.Panels.map.H.footprint.XData, NaN, 'no footprint from an invalid frame');
        end

        function staleSampleIsNeverRestamped(tc)
            app = tc.flown(40); v = app.Session.view(); s = v.samples.RGB_NADIR;
            v.pose.tick_id = v.pose.tick_id + v.period.RGB_NADIR + 1;
            st = mgv2.ui.sampleStatus("RGB_NADIR", v);
            tc.verifyEqual(st.state, "STALE");
            tc.verifySubstring(st.text, sprintf("t=%.2f s | tick %d", s.t_s, s.tick_id));
            app.Panels.rgb.present(v); drawnow;
            tc.verifySubstring(string(app.Panels.rgb.StatusLabel.Text), "STALE");
        end

        function telemetryUsesActualValuesAndBattery(tc)
            app = tc.flown(120); p = app.Session.Engine.snapshot(); n = app.Session.Sensors.latest("VIRTUAL_GNSS_INS"); T = app.Panels.telemetry;
            f = string(T.FlightLabel.Text);
            tc.verifySubstring(f, "Phase: " + p.phase);
            tc.verifySubstring(f, sprintf("AGL: %.2f m", p.altitude_agl_m));
            tc.verifySubstring(f, sprintf("Speed: %.2f m/s", norm(p.velocity_enu_mps)));
            tc.verifySubstring(f, "Battery: NOT MODELLED");
            tc.verifySubstring(string(T.NavLabel.Text), sprintf("Virtual lat: %.6f deg", n.virtual_lat_deg));
            tc.verifySubstring(string(T.HealthLabel.Text), "THERMAL_LWIR");
        end

        function mapIsOfflineAndShowsActualGeometry(tc)
            app = tc.flown(120); M = app.Panels.map; cfg = app.Session.MissionConfig; p = app.Session.Engine.snapshot();
            ax = M.Axes;
            tc.verifyClass(ax, 'matlab.ui.control.UIAxes', 'the offline map is a local axes, not a web basemap');
            tc.verifyEmpty(findall(app.Figure, '-isa', 'matlab.graphics.axis.GeographicAxes'));
            tc.verifyEqual(string(M.H.terrain.Visible), "on");
            tc.verifyEqual(M.H.boundary.XData(1:4)', cfg.survey_polygon_enu_m(:, 1));
            tc.verifyEqual(M.H.home.XData, cfg.home_enu_m(1));
            tc.verifyEqual(M.H.route.XData(:), app.Session.Engine.Route.xy(:, 1));
            tc.verifyEqual([M.H.uav.XData M.H.uav.YData], p.position_enu_m(1:2));
            s = app.Session.Sensors.latest("RGB_NADIR");
            tc.verifyEqual(M.H.footprint.XData(:), s.footprint_enu_m(:, 1));
            tc.verifySubstring(string(M.StatusLabel.Text), "OFFLINE LOCAL ENU");
            drawnow; shot = getframe(ax);
            tc.verifyGreaterThan(std(double(shot.cdata(:))), 5);
        end

        function eventPanelSaysDetectorNotConnected(tc)
            app = tc.flown(120);
            tc.verifyEqual(string(app.Panels.events.StatusLabel.Text), "DETECTOR NOT CONNECTED");
            tc.verifyEmpty(app.Panels.events.Table.Data);
            tc.verifySubstring(string(app.Panels.map.StatusLabel.Text), "DETECTOR NOT CONNECTED");
            tc.verifyEmpty(findall(app.Panels.map.Axes, '-regexp', 'Tag', '^layer_'), 'no event or coverage markers without a detector');
        end

        function noTruthOrForbiddenClaimsDisplayed(tc)
            app = tc.flown(120);
            mgv2.sensors.assertPublic(rmfield(app.Session.view(), 'layers'), "view");   % every field name at any depth
            txt = tc.visibleText(app); low = lower(txt);
            for w = mgv2.sensors.contract().forbidden
                tc.verifyFalse(any(contains(low, w)), "displayed text contains forbidden name " + w);
            end
            tc.verifyFalse(any(~cellfun(@isempty, regexp(cellstr(txt), '\<(SAFE|CLEARED|CONFIRMED)\>', 'once'))));
            tc.verifyFalse(any(contains(low, "confirmed mine")));
        end

        function warningAlwaysVisible(tc)
            app = tc.open('MaxTicksPerRun', 40); tc.assertWarningVisible(app);
            tc.press(app.Controls.Buttons.start); tc.assertWarningVisible(app);
            for pos = {[60 60 1400 860], [60 60 900 600], [60 60 760 520], [60 60 1400 500]}
                app.Figure.Position = pos{1}; tc.assertWarningVisible(app);
            end
            tc.press(app.Controls.Buttons.abort); tc.assertWarningVisible(app);
            tc.press(app.Controls.Buttons.reset); tc.assertWarningVisible(app);
        end

        function layoutAdaptsToWindowSize(tc)
            app = tc.open('Position', [60 60 1400 860]); drawnow;
            tc.verifyEqual(app.LayoutMode, "wide");
            tc.verifyEqual(string(app.Content.Scrollable), "off");
            ps = app.Panels.scene.Position; pl = app.Panels.lidar.Position;
            tc.verifyGreaterThan(ps(3), 500); tc.verifyGreaterThan(pl(4), 120);
            app.Figure.Position = [60 60 900 600]; tc.settle(@() app.LayoutMode == "compact");
            tc.verifyEqual(app.LayoutMode, "compact");
            tc.verifyEqual(string(app.Content.Scrollable), "on");
            tc.settle(@() abs(app.Panels.scene.Position(3) - 400) < 80);
            tc.verifyGreaterThan(app.Panels.scene.Position(3), 300, 'compact panels must remain usable');
            app.Figure.Position = [60 60 1400 860]; tc.settle(@() app.LayoutMode == "wide");
            tc.verifyEqual(app.LayoutMode, "wide");
            tc.verifyEqual(string(app.Content.Scrollable), "off");
            tc.verifyEqual(app.Panels.scene.Layout.Column, [1 3]);
        end

        function defaultPositionFitsDisplay(tc)
            pos = mgv2.ui.MissionControlApp.defaultPosition(); sz = get(groot, 'ScreenSize');
            tc.verifyLessThanOrEqual(pos(1) + pos(3), sz(1) + sz(3));
            tc.verifyLessThanOrEqual(pos(2) + pos(4), sz(2) + sz(4));
        end

        function graphicsDoNotLeak(tc)
            app = tc.flown(40); drawnow; n1 = numel(findall(app.Figure));
            tc.press(app.Controls.Buttons.resume); drawnow; n2 = numel(findall(app.Figure));
            tc.verifyEqual(n2, n1, 'running must not add graphics objects');
            tc.press(app.Controls.Buttons.abort); tc.press(app.Controls.Buttons.reset); drawnow; n3 = numel(findall(app.Figure));
            tc.press(app.Controls.Buttons.start); tc.press(app.Controls.Buttons.abort); tc.press(app.Controls.Buttons.reset); drawnow; n4 = numel(findall(app.Figure));
            tc.verifyEqual(n4, n3, 'reset must not accumulate graphics objects');
        end

        function closeReleasesEverything(tc)
            t0 = numel(timerfindall); f0 = numel(findall(groot, 'Type', 'figure'));
            for k = 1:3
                app = tc.flown(20); r = app.Panels.scene.Renderer; ses = app.Session; fig = app.Figure;
                tc.verifyEqual(numel(timerfindall), t0, 'the application must not create a timer');
                delete(app); drawnow;
                tc.verifyFalse(isvalid(fig)); tc.verifyFalse(isvalid(r)); tc.verifyTrue(isvalid(ses));
            end
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), f0);
            tc.verifyEqual(numel(timerfindall), t0);
        end

        function closingDuringRunStopsCleanly(tc)
            app = tc.open('MaxTicksPerRun', 200); fig = app.Figure;
            app.AfterRefreshFcn = @(a) tc.closeAt(a, 12);
            tc.press(app.Controls.Buttons.start); drawnow;
            tc.verifyFalse(isvalid(fig)); tc.verifyFalse(isvalid(app));
        end

        function reentryIsRefusedAndOneSubscription(tc)
            src = V2007TestDoubleSource(); app = tc.open('MaxTicksPerRun', 40, 'AnomalySource', src);
            app.AfterRefreshFcn = @(a) a.command("start");   % a second start while running must do nothing
            tc.press(app.Controls.Buttons.start); drawnow;
            tc.verifyEqual(app.Session.Engine.TickId, 40);
            tc.verifyEqual(numel(src.Seen), height(app.Session.Sensors.Log), 'each sample delivered exactly once');
            tc.verifyEqual(numel(unique(src.Seen)), numel(src.Seen));
            app.AfterRefreshFcn = [];
            tc.press(app.Controls.Buttons.abort); tc.press(app.Controls.Buttons.reset); drawnow;
            tc.verifyEqual(src.Resets, 1);
            tc.verifyEqual(numel(src.Seen), height(app.Session.Sensors.Log), 'the new sensors deliver once, the old ones never');
        end

        function adapterSeamDisplaysValidatedOutput(tc)
            src = V2007TestDoubleSource(); src.Events = V2007TestDoubleSource.event(); src.Layers = V2007TestDoubleSource.layer();
            app = tc.flown(20, 'AnomalySource', src);
            tc.verifySubstring(string(app.Panels.events.StatusLabel.Text), "1 SUSPECTED");
            tc.verifySubstring(string(app.Panels.events.Table.ColumnName{5}), "uncalibrated");
            tc.verifyEqual(app.Panels.events.Table.Data{1, 3}, 2);
            h = findall(app.Panels.map.Axes, 'Tag', 'layer_cov'); tc.verifySize(h, [1 1]);
            n = numel(findall(app.Figure)); tc.press(app.Controls.Buttons.resume); drawnow;
            tc.verifyEqual(numel(findall(app.Figure)), n, 'an unchanged revision must not redraw');
            src.Layers = struct([]); tc.press(app.Controls.Buttons.resume); drawnow;
            tc.verifyEmpty(findall(app.Panels.map.Axes, 'Tag', 'layer_cov'));
        end

        function adapterSeamRejectsBadRecords(tc)
            D = @V2007TestDoubleSource.event; Lk = @V2007TestDoubleSource.layer;
            tc.verifyError(@() mgv2.ui.validateEvents(D('status', "CONFIRMED")), 'mgv2:InvalidEvent');
            tc.verifyError(@() mgv2.ui.validateEvents(D('x_est_m', NaN)), 'mgv2:InvalidEvent');
            tc.verifyError(@() mgv2.ui.validateEvents(D('detector_version', "")), 'mgv2:InvalidEvent');
            tc.verifyError(@() mgv2.ui.validateEvents(struct('event_id', "x")), 'mgv2:InvalidEvent');
            tc.verifyError(@() mgv2.ui.validateEvents(D('target_id', 3)), 'mgv2:TruthLeak');
            tc.verifyError(@() mgv2.ui.validateMapLayers(Lk('kind', "heat")), 'mgv2:InvalidMapLayer');
            tc.verifyError(@() mgv2.ui.validateMapLayers(Lk('display_name', "cleared area")), 'mgv2:InvalidMapLayer');
            tc.verifyError(@() mgv2.ui.validateMapLayers(Lk('ground_truth', 1)), 'mgv2:TruthLeak');
            tc.verifyEmpty(mgv2.ui.validateEvents(struct([]))); tc.verifyEmpty(mgv2.ui.validateMapLayers([]));
        end
    end

    methods
        function pressOnceAt(tc, app, tick)
            if app.Session.Engine.TickId == tick && ~app.Session.Engine.Paused, tc.press(app.Controls.Buttons.pause); end
        end
        function closeAt(~, app, tick)
            if app.Session.Engine.TickId >= tick, close(app.Figure); end
        end
    end
end
