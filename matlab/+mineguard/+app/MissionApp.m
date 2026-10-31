classdef MissionApp < handle
    %MISSIONAPP MineGuard mission-replay dashboard: programmatic uifigure app (MG-011, MG-010 spec).
    %   Create it through mineguard.app.openMissionApp(runBundle). It is a source-backed
    %   uifigure fallback rather than a binary .mlapp, chosen for reviewable, diffable code and
    %   reproducible tests.
    %   State machine (MG-010 Section 4): IDLE -> READY -> RUNNING <-> PAUSED -> COMPLETE; FAILED; CLOSED.
    %   The replay cursor is a pose index; "step" advances exactly one stored pose time. Data in
    %   the bundle is never modified, and reset does not regenerate anything.
    %   SIMULATION ONLY. No hardware, telemetry link or network I/O is used.

    properties (Constant)
        Banner = "SIMULATION — synthetic data; not validated for real landmine detection or clearance."
        TimerPeriod = 0.1          % wall seconds per playback tick
        Speeds = [0.5 1 2 5 10 20] % simulated seconds per wall second
    end
    properties (SetAccess = private)
        Bundle                     % immutable redacted run bundle
        State string = "IDLE"
        Cursor double = 0          % index into poses (0 = no data)
        Speed double = 1
        StatusText string = ""
        LastExport struct = struct()
        TickDurations double = zeros(0, 1)   % measured render time per tick [s]
    end
    properties (Access = private)
        Fig; Grid; H                % uifigure, layout and handle struct
        PlayTimer
        Busy logical = false
        Visited double             % linear index of the survey cell containing each pose (MG-005 rule)
        CellNx; CellNy; CellDx; CellDy; Bounds
        TimeTh; TimeEm
        LastEventKey string = "<none>"   % redraw the events table only when the visible set changes
        LastTick uint64 = uint64(0)      % wall-clock reference for the replay rate
    end

    methods
        function app = MissionApp(rb)
            app.Bundle = rb;
            try
                app.precompute();
                app.buildUI();
            catch err
                if ~isempty(app.Fig) && isvalid(app.Fig), delete(app.Fig); end   % never leave a half-built UI
                app.State = "FAILED";
                rethrow(err);
            end
            if height(rb.poses) == 0
                app.State = "READY";
                app.StatusText = "EMPTY run: no recorded poses. Replay controls are disabled.";
            else
                app.Cursor = 1;
                app.State = "READY";
                app.StatusText = "Loaded run " + rb.scenario_id + ". Press Play Simulation.";
            end
            app.render();
        end

        % ---------------- replay controls (also used by the UI callbacks) ----------------
        function play(app)
            if ~ismember(app.State, ["READY","PAUSED"]) || app.nPoses() == 0, return; end
            if app.Cursor >= app.nPoses(), app.Cursor = 1; end
            app.State = "RUNNING";
            app.StatusText = "Replaying simulated run at " + app.Speed + "x simulated time.";
            app.ensureTimer();
            app.LastTick = tic;
            start(app.PlayTimer);
            app.render();
        end
        function pause(app)
            if app.State ~= "RUNNING", return; end
            app.stopTimer();
            app.State = "PAUSED";
            app.StatusText = "Paused at t = " + sprintf('%.2f', app.currentTime()) + " s (simulated).";
            app.render();
        end
        function step(app)
            if ~ismember(app.State, ["READY","PAUSED"]) || app.nPoses() == 0, return; end
            app.Cursor = min(app.nPoses(), app.Cursor + 1);
            app.State = "PAUSED";
            if app.Cursor == app.nPoses(), app.State = "COMPLETE"; end
            app.StatusText = "Stepped to pose " + app.Cursor + " of " + app.nPoses() + ".";
            app.render();
        end
        function seek(app, t)
            if ~ismember(app.State, ["READY","RUNNING","PAUSED","COMPLETE"]) || app.nPoses() == 0, return; end
            if ~(isnumeric(t) && isscalar(t) && isfinite(t))
                app.StatusText = "Seek ignored: time must be a finite number."; app.render(); return
            end
            app.stopTimer();
            T = app.Bundle.poses.t_s;
            k = find(T <= t, 1, 'last');
            if isempty(k), k = 1; end
            app.Cursor = k;
            app.State = "PAUSED";
            app.StatusText = "Seek to t = " + sprintf('%.2f', T(k)) + " s (simulated).";
            app.render();
        end
        function reset(app)
            if app.State == "CLOSED" || app.State == "IDLE", return; end
            app.stopTimer();
            app.Cursor = double(app.nPoses() > 0);
            app.State = "READY";
            app.StatusText = "Reset to the initial cursor (no data regenerated).";
            app.render();
        end
        function setSpeed(app, s)
            if ~ismember(s, app.Speeds)
                app.StatusText = "Unsupported speed."; app.render(); return
            end
            app.Speed = s;
            if isfield(app.H, 'speed') && isvalid(app.H.speed), app.H.speed.Value = string(s) + "x"; end
            app.render();
        end
        function tick(app)
            % One playback tick: advance by Speed x (wall time since the previous tick) simulated
            % seconds, so "1x" is real time. Poses are never skipped in the data, only in rendering.
            % Reaching the end gives COMPLETE.
            if app.State ~= "RUNNING" || app.Busy, return; end
            app.Busy = true;
            c = onCleanup(@() app.clearBusy());
            T = app.Bundle.poses.t_s;
            dtw = toc(app.LastTick); app.LastTick = tic;
            target = T(app.Cursor) + app.Speed * dtw;
            k = find(T <= target, 1, 'last');
            app.Cursor = max(app.Cursor + 1, k);
            if app.Cursor >= app.nPoses()
                app.Cursor = app.nPoses();
                app.stopTimer();
                app.State = "COMPLETE";
                app.StatusText = "Replay complete (end of recorded data).";
            end
            t0 = tic; app.render(); drawnow limitrate;
            app.TickDurations(end+1, 1) = toc(t0);
        end

        function ok = exportRun(app, folder)
            % Export the redacted run data, provenance summary and a PNG snapshot to a new
            % subfolder of FOLDER. With no argument a folder dialog opens; a cancel (0 or "")
            % writes nothing. Files go to a temporary folder, are read back and verified, and only
            % then are they moved into place. Any failure leaves no claimed export.
            ok = false;
            if nargin < 2
                folder = uigetdir(pwd, 'Select export destination (redacted simulation data)');
            end
            if isequal(folder, 0) || (isstring(folder) || ischar(folder)) && strlength(string(folder)) == 0
                app.StatusText = "Export cancelled: no files written."; app.render(); return
            end
            folder = string(folder);
            stamp = string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyyMMdd''T''HHmmss''Z'''));
            name = "MG011-export-" + app.Bundle.scenario_id + "-" + stamp;
            final = fullfile(folder, name);
            tmp = fullfile(tempdir, name + "-partial");
            try
                if ~isfolder(folder), error('mineguard:ExportFailed', 'Destination folder does not exist: %s', folder); end
                if isfolder(final), error('mineguard:ExportFailed', 'Destination already exists: %s', final); end
                mkdir(tmp);
                files = app.writeExport(tmp, stamp);
                app.verifyExport(tmp, files);
                [st, msg] = movefile(tmp, final);
                if ~st, error('mineguard:ExportFailed', 'Could not move export into place: %s', msg); end
                app.LastExport = struct('folder', final, 'files', {files}, 'utc', stamp);
                app.StatusText = "Export verified: " + numel(files) + " files in " + final;
                ok = true;
            catch err
                if isfolder(tmp), rmdir(tmp, 's'); end
                app.StatusText = "Export FAILED (no export claimed): " + string(err.message);
            end
            app.render();
        end

        function s = viewState(app)
            % Snapshot of what the dashboard currently shows (used by tests and UI-20).
            n = app.Cursor;
            s = struct('state', app.State, 'cursor', n, 't_s', app.currentTime(), ...
                'trace_points', n, 'visible_event_ids', app.visibleEvents().event_id', ...
                'visible_thermal', nnz(app.visibleSamples("thermal").valid), ...
                'visible_em', nnz(app.visibleSamples("em").valid), ...
                'visited_cells', nnz(app.visitedUpTo(n)), 'banner', string(app.H.banner.Text), ...
                'status', app.StatusText, 'telemetry', string(app.H.telemetry.Value), ...
                'provenance_text', string(app.H.meta.Value), 'events_text', string(app.H.eventsNote.Text), ...
                'play_enabled', string(app.H.play.Enable), 'step_enabled', string(app.H.step.Enable), ...
                'seek_enabled', string(app.H.seek.Enable), 'speed', app.Speed, ...
                'thermal_ylabel', string(app.H.axT.YLabel.String), 'em_ylabel', string(app.H.axE.YLabel.String), ...
                'map_xlabel', string(app.H.map.XLabel.String), 'map_ylabel', string(app.H.map.YLabel.String));
        end
        function f = figureHandle(app)
            f = app.Fig;
        end
        function h = uiHandles(app)
            % Graphics handles (for UI gesture tests and screenshots); the data stay immutable.
            h = app.H;
        end
        function close(app)
            app.stopTimer();
            if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer), delete(app.PlayTimer); end
            app.PlayTimer = [];
            if ~isempty(app.Fig) && isvalid(app.Fig), delete(app.Fig); end
            app.State = "CLOSED";
        end
        function delete(app)
            if app.State ~= "CLOSED", app.close(); end
        end
    end

    methods (Access = private)
        function n = nPoses(app), n = height(app.Bundle.poses); end
        function t = currentTime(app)
            if app.Cursor == 0, t = NaN; else, t = app.Bundle.poses.t_s(app.Cursor); end
        end
        function clearBusy(app), app.Busy = false; end

        function ensureTimer(app)
            if isempty(app.PlayTimer) || ~isvalid(app.PlayTimer)
                app.PlayTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', app.TimerPeriod, ...
                    'BusyMode', 'drop', 'Tag', 'MineGuardMissionAppTimer', 'TimerFcn', @(~, ~) app.tick());
            end
        end
        function stopTimer(app)
            if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer) && strcmp(app.PlayTimer.Running, 'on')
                stop(app.PlayTimer);
            end
        end

        function precompute(app)
            rb = app.Bundle; b = double(rb.geometry.bounds_enu_m); app.Bounds = b;
            s = 1;
            if isfield(rb, 'display_settings') && isfield(rb.display_settings, 'grid_spacing_m'), s = rb.display_settings.grid_spacing_m; end
            app.CellNx = max(1, ceil((b(2) - b(1)) / s - 1e-9)); app.CellNy = max(1, ceil((b(4) - b(3)) / s - 1e-9));
            app.CellDx = (b(2) - b(1)) / app.CellNx; app.CellDy = (b(4) - b(3)) / app.CellNy;
            P = rb.poses;
            if height(P) > 0
                ix = min(app.CellNx, max(1, floor((P.x_east_m - b(1)) / app.CellDx) + 1));
                iy = min(app.CellNy, max(1, floor((P.y_north_m - b(3)) / app.CellDy) + 1));
                app.Visited = sub2ind([app.CellNy app.CellNx], iy, ix);   % cell visited by each pose (MG-005 rule)
            else
                app.Visited = zeros(0, 1);
            end
            app.TimeTh = rb.thermal_samples.t_s; app.TimeEm = rb.em_samples.t_s;
        end
        function m = visitedUpTo(app, n)
            m = false(app.CellNy, app.CellNx);
            if n > 0, m(app.Visited(1:n)) = true; end
        end
        function E = visibleEvents(app)
            E = app.Bundle.events;
            if app.Cursor == 0, E = E([], :); return; end
            E = E(E.valid & E.t_s <= app.currentTime(), :);
            E = sortrows(E, {'t_s','event_id'});
        end
        function S = visibleSamples(app, kind)
            S = app.Bundle.(kind + "_samples");
            if app.Cursor == 0, S = S([], :); return; end
            S = S(S.t_s <= app.currentTime(), :);
        end

        % ---------------- UI construction ----------------
        function buildUI(app)
            rb = app.Bundle;
            app.Fig = uifigure('Name', 'MineGuard Mission Replay — SIMULATION', 'Position', [60 60 1360 800], ...
                'CloseRequestFcn', @(~, ~) app.close());
            app.Grid = uigridlayout(app.Fig, [4 3], 'RowHeight', {30, 26, '1x', 150}, 'ColumnWidth', {250, '1x', 420}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 8);
            H = struct();
            H.header = uilabel(app.Grid, 'FontWeight', 'bold', 'FontSize', 15);
            H.header.Layout.Row = 1; H.header.Layout.Column = [1 3];
            H.banner = uilabel(app.Grid, 'Text', app.Banner, 'FontWeight', 'bold', 'FontColor', [1 1 1], ...
                'BackgroundColor', [0.70 0.15 0.10], 'HorizontalAlignment', 'center', 'FontSize', 13);
            H.banner.Layout.Row = 2; H.banner.Layout.Column = [1 3];

            % Left: mission / replay panel
            left = uipanel(app.Grid, 'Title', 'Mission / Replay (simulation only)');
            left.Layout.Row = 3; left.Layout.Column = 1;
            lg = uigridlayout(left, [11 2], 'RowHeight', {28, 28, 28, 22, 28, 22, 28, 28, '1x', 28, 22}, 'ColumnWidth', {'1x', '1x'});
            H.play = uibutton(lg, 'Text', 'Play Simulation', 'ButtonPushedFcn', @(~, ~) app.play());
            H.play.Layout.Column = [1 2];
            H.pause = uibutton(lg, 'Text', 'Pause', 'ButtonPushedFcn', @(~, ~) app.pause());
            H.step = uibutton(lg, 'Text', 'Step', 'ButtonPushedFcn', @(~, ~) app.step());
            H.reset = uibutton(lg, 'Text', 'Reset', 'ButtonPushedFcn', @(~, ~) app.reset());
            H.fullrun = uicheckbox(lg, 'Text', 'Show Full Run', 'Value', false, 'ValueChangedFcn', @(~, ~) app.render());
            H.seekLabel = uilabel(lg, 'Text', 'Seek t_s [s]:'); uilabel(lg, 'Text', '');
            T = rb.poses.t_s; tmax = 1; if ~isempty(T) && T(end) > 0, tmax = T(end); end
            H.seek = uislider(lg, 'Limits', [0 tmax], 'MajorTicks', [], 'MinorTicks', [], ...
                'ValueChangedFcn', @(src, ~) app.seek(src.Value));
            H.seek.Layout.Column = [1 2];
            uilabel(lg, 'Text', 'Replay speed:');
            H.speed = uidropdown(lg, 'Items', string(app.Speeds) + "x", 'Value', "1x", ...
                'ValueChangedFcn', @(src, ~) app.setSpeed(str2double(erase(src.Value, "x"))));
            H.export = uibutton(lg, 'Text', 'Export run data…', 'ButtonPushedFcn', @(~, ~) app.exportRun());
            H.export.Layout.Column = [1 2];
            H.telemetry = uitextarea(lg, 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);
            H.telemetry.Layout.Row = [8 10]; H.telemetry.Layout.Column = [1 2];
            H.status = uilabel(lg, 'Text', '', 'WordWrap', 'on', 'FontColor', [0.1 0.1 0.5]);
            H.status.Layout.Row = 11; H.status.Layout.Column = [1 2];

            % Centre: survey map
            H.map = uiaxes(app.Grid);
            H.map.Layout.Row = 3; H.map.Layout.Column = 2;
            title(H.map, 'Survey map (ENU metres) — virtual kinematic replay');
            xlabel(H.map, 'x east [m]'); ylabel(H.map, 'y north [m]');
            axis(H.map, 'equal'); hold(H.map, 'on'); box(H.map, 'on'); grid(H.map, 'on');

            % Right: sensors and events
            right = uigridlayout(app.Grid, [4 1], 'RowHeight', {'1x', '1x', 22, '1.2x'}, 'Padding', [0 0 0 0]);
            right.Layout.Row = 3; right.Layout.Column = 3;
            H.axT = uiaxes(right); title(H.axT, 'Thermal (synthetic)'); ylabel(H.axT, 'temperature [K]', 'Interpreter', 'none'); xlabel(H.axT, 't_s [s]'); hold(H.axT, 'on'); grid(H.axT, 'on');
            H.axE = uiaxes(right); title(H.axE, 'EM coil (synthetic)'); ylabel(H.axE, 'normalized response [-]', 'Interpreter', 'none'); xlabel(H.axE, 't_s [s]'); hold(H.axE, 'on'); grid(H.axE, 'on');
            H.eventsNote = uilabel(right, 'Text', '', 'FontWeight', 'bold');
            H.events = uitable(right, 'ColumnName', {'event_id','t_s [s]','x_est [m]','y_est [m]','status','confidence'}, ...
                'RowName', {}, 'FontSize', 11, 'ColumnWidth', {64, 46, 52, 52, 78, '1x'});   % method shown in metadata panel

            % Bottom: provenance / evaluation / warnings
            bottom = uigridlayout(app.Grid, [1 2], 'ColumnWidth', {'1x', '1x'}, 'Padding', [0 0 0 0]);
            bottom.Layout.Row = 4; bottom.Layout.Column = [1 3];
            H.meta = uitextarea(bottom, 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);
            H.eval = uitextarea(bottom, 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);
            H.axT.Subtitle.Interpreter = 'none'; H.axE.Subtitle.Interpreter = 'none';   % show reason codes literally
            app.H = H;
            app.drawStatic();
            app.fillMetadata();
        end

        function drawStatic(app)
            rb = app.Bundle; H = app.H; b = double(rb.geometry.bounds_enu_m);
            plot(H.map, b([1 2 2 1 1]), b([3 3 4 4 3]), 'k-', 'LineWidth', 1.5, 'DisplayName', 'survey bounds');
            polys = rb.geometry.exclusion_polygons_enu_m;
            for k = 1:numel(polys)
                patch(H.map, polys{k}(:,1), polys{k}(:,2), [0.85 0.3 0.3], 'FaceAlpha', 0.35, 'EdgeColor', [0.6 0 0], ...
                    'DisplayName', 'exclusion (no-fly)');
            end
            if isfield(rb, 'route_enu_m') && ~isempty(rb.route_enu_m)
                plot(H.map, rb.route_enu_m(:,1), rb.route_enu_m(:,2), ':', 'Color', [0.5 0.5 0.5], 'DisplayName', 'planned waypoints');
            end
            app.H.cells = image(H.map, 'XData', b(1:2), 'YData', b(3:4), 'CData', zeros(1, 1, 3), 'AlphaData', 0);   % visited cells (MG-005 rule)
            app.H.full = plot(H.map, NaN, NaN, '-', 'Color', [0.75 0.75 0.95], 'DisplayName', 'Full Run (all poses)');
            app.H.trace = plot(H.map, NaN, NaN, '-', 'Color', [0 0.35 0.8], 'LineWidth', 1.4, 'DisplayName', 'virtual UAV trace (to t)');
            app.H.ev = plot(H.map, NaN, NaN, 'p', 'MarkerSize', 13, 'MarkerFaceColor', [1 0.6 0], 'MarkerEdgeColor', 'k', 'DisplayName', 'SUSPECTED event (est.)');
            app.H.uav = plot(H.map, NaN, NaN, 'o', 'MarkerSize', 10, 'MarkerFaceColor', [0 0.6 0.2], 'MarkerEdgeColor', 'k', 'DisplayName', 'virtual UAV');
            pad = 0.03 * max(b(2) - b(1), b(4) - b(3));
            xlim(H.map, [b(1) - pad, b(2) + pad]); ylim(H.map, [b(3) - pad, b(4) + pad]);
            legend(H.map, 'Location', 'southoutside', 'NumColumns', 3, 'FontSize', 8, 'AutoUpdate', 'off');
            th = rb.thermal_samples; em = rb.em_samples;
            app.H.thLine = plot(H.axT, NaN, NaN, '-', 'Color', [0.85 0.33 0.1], 'DisplayName', 'temperature_K (valid)');
            app.H.thBad = plot(H.axT, NaN, NaN, 'x', 'Color', [0.4 0.4 0.4], 'DisplayName', 'invalid (gap)');
            app.H.emLine = plot(H.axE, NaN, NaN, '-', 'Color', [0.1 0.45 0.75], 'DisplayName', 'response_norm (valid)');
            app.H.emBad = plot(H.axE, NaN, NaN, 'x', 'Color', [0.4 0.4 0.4], 'DisplayName', 'invalid (gap)');
            legend(H.axT, 'Location', 'northeast', 'FontSize', 8, 'AutoUpdate', 'off', 'Interpreter', 'none'); legend(H.axE, 'Location', 'northeast', 'FontSize', 8, 'AutoUpdate', 'off', 'Interpreter', 'none');
            tl = [0 1]; if height(rb.poses) > 0 && rb.poses.t_s(end) > 0, tl = [0 rb.poses.t_s(end)]; end
            xlim(H.axT, tl); xlim(H.axE, tl);
            vt = th.temperature_K(th.valid); if ~isempty(vt) && max(vt) > min(vt), ylim(H.axT, [min(vt) max(vt)] + [-0.05 0.05] * (max(vt) - min(vt) + eps)); end
            ve = em.response_norm(em.valid); if ~isempty(ve) && max(ve) > min(ve), ylim(H.axE, [min(ve) max(ve)] + [-0.05 0.05] * (max(ve) - min(ve) + eps)); end
        end

        function fillMetadata(app)
            rb = app.Bundle; p = rb.provenance;
            f = @(k) local_str(p.(k));
            lines = [ "RUN METADATA (replay only — values from run record; unknown = NOT_RECORDED)"
                "scenario_id: " + f('scenario_id') + "   seed: " + f('seed') + "   split: " + f('split_id')
                "method: " + f('method_name') + "   missing_modality_rule: " + f('missing_modality_rule') + "   threshold (model score): " + f('threshold')
                "detector model: " + f('detector_model_version') + "   sensors: " + f('sensor_settings_version')
                "simulation version: " + f('model_version') + "   MATLAB: " + f('matlab_release') + "   git SHA: " + f('git_sha')
                "run_id: " + f('run_id') + "   run time (UTC): " + f('run_timestamp_utc')
                "flags: " + f('simulation_flags')
                "3-D view: NOT AVAILABLE (2-D replay only)   Hardware/telemetry link: NONE (simulation)" ];
            app.H.meta.Value = lines;
            ev = "AGGREGATE SYNTHETIC EVALUATION (cell-level, evaluable survey cells; MG-008)";
            if isfield(rb, 'result')
                r = rb.result;
                ev(end+1) = "split: " + r.split_id + "   algorithm: " + r.algorithm;
                ev(end+1) = sprintf("TP %d   FP %d   TN %d   FN %d", r.tp, r.fp, r.tn, r.fn);
                ev(end+1) = "precision: " + local_ratio(r.precision) + "   recall: " + local_ratio(r.recall) + ...
                    "   F1: " + local_ratio(r.f1) + "   FPR: " + local_ratio(r.false_alarm_rate);
                if isfield(rb, 'result_report') && isfield(rb.result_report, 'evaluable_cell_count')
                    ev(end+1) = "evaluable cells: " + rb.result_report.evaluable_cell_count + "   excluded (unassessed): " + rb.result_report.excluded_cell_count;
                end
                ev(end+1) = "Localization (separate, event-to-object): mean error " + local_ratio(r.localization_error_m) + " m";
            else
                ev(end+1) = "Evaluation: NOT RUN / NOT RECORDED for this replay.";
            end
            if isfield(rb, 'comparison') && ~ismember('planner', rb.comparison.Properties.VariableNames)
                ev(end+1) = "Method comparison: " + height(rb.comparison) + " rows supplied with run metadata (held-out, same conditions).";
            else
                ev(end+1) = "Method comparison: NOT RUN.";
            end
            if isfield(rb, 'comparison') && ismember('planner', rb.comparison.Properties.VariableNames) && any(string(rb.comparison.planner) == "ppo")
                ev(end+1) = "PPO vs fixed-grid comparison: supplied (MG-019; " + height(rb.comparison) + " planner rows; see openComparisonApp).";
            else
                ev(end+1) = "PPO comparison: NOT RUN (MG-013/MG-019 not integrated into this replay).";
            end
            % MG-017 (MG016-R01): never let a display fixture read as held-out performance.
            if startsWith(string(rb.scenario_id), "MG015-DEMO")
                ev(end+1) = "DISPLAY FIXTURE (S0, 0.3 m altitude / 0.5 m cells): NOT held-out performance.";
            end
            h = mineguard.releaseInfo().heldout;
            ev(end+1) = sprintf("Locked held-out TEST (%s, %s/%s): TP %d FP %d TN %d FN %d - NEGATIVE.", ...
                h.families, h.method, h.rule, h.tp, h.fp, h.tn, h.fn);
            ev(end+1) = "Not evidence of real mine detection, clearance or field safety.";
            app.H.eval.Value = ev;
        end

        % ---------------- rendering ----------------
        function render(app)
            if isempty(app.Fig) || ~isvalid(app.Fig), return; end
            rb = app.Bundle; H = app.H; n = app.Cursor; P = rb.poses;
            H.header.Text = "MINEGUARD SIMULATION  |  scenario " + rb.scenario_id + "  |  replay: " + app.State + ...
                "  |  t_sim = " + local_t(app.currentTime()) + "  |  " + local_str(rb.provenance.model_version);
            empty = app.nPoses() == 0;
            on = @(c) local_onoff(c);
            H.play.Enable = on(~empty && ismember(app.State, ["READY","PAUSED"]));
            H.pause.Enable = on(app.State == "RUNNING");
            H.step.Enable = on(~empty && ismember(app.State, ["READY","PAUSED"]));
            H.reset.Enable = on(~empty && app.State ~= "CLOSED");
            H.seek.Enable = on(~empty);
            H.status.Text = app.StatusText;
            if n > 0
                H.trace.XData = P.x_east_m(1:n); H.trace.YData = P.y_north_m(1:n);
                H.uav.XData = P.x_east_m(n); H.uav.YData = P.y_north_m(n);
                if abs(H.seek.Value - P.t_s(n)) > 1e-9, H.seek.Value = min(max(P.t_s(n), H.seek.Limits(1)), H.seek.Limits(2)); end
            else
                H.trace.XData = NaN; H.trace.YData = NaN; H.uav.XData = NaN; H.uav.YData = NaN;
            end
            if H.fullrun.Value && ~empty
                H.full.XData = P.x_east_m; H.full.YData = P.y_north_m;
            else
                H.full.XData = NaN; H.full.YData = NaN;
            end
            vm = app.visitedUpTo(n);
            C = zeros(app.CellNy, app.CellNx, 3); C(:,:,1) = 0.55; C(:,:,2) = 0.85; C(:,:,3) = 0.55;
            b = app.Bounds;
            H.cells.XData = [b(1) + app.CellDx / 2, b(2) - app.CellDx / 2];
            H.cells.YData = [b(3) + app.CellDy / 2, b(4) - app.CellDy / 2];
            H.cells.CData = C; H.cells.AlphaData = 0.45 * double(vm);
            E = app.visibleEvents();
            if height(E) > 0
                H.ev.XData = E.x_est_m; H.ev.YData = E.y_est_m;
            else
                H.ev.XData = NaN; H.ev.YData = NaN;
            end
            key = strjoin([""; E.event_id], "|");
            if key ~= app.LastEventKey
                conf = repmat("Uncalibrated / unavailable", height(E), 1);
                hasC = ~isnan(E.confidence_0_1);
                conf(hasC) = "Model score " + compose("%.3f", E.confidence_0_1(hasC));
                H.events.Data = table(E.event_id, round(E.t_s, 2), round(E.x_est_m, 2), round(E.y_est_m, 2), E.status, conf);
                app.LastEventKey = key;
            end
            if height(rb.events) == 0
                H.eventsNote.Text = "No suspected events in this simulated run.";
            else
                H.eventsNote.Text = "SUSPECTED events up to current time: " + height(E) + " of " + height(rb.events) + " in run";
            end
            app.renderSensor("thermal", H.thLine, H.thBad, "temperature_K");
            app.renderSensor("em", H.emLine, H.emBad, "response_norm");
            H.telemetry.Value = app.telemetryLines();
        end

        function renderSensor(app, kind, hLine, hBad, col)
            S = app.visibleSamples(kind);
            y = S.(col); y(~S.valid) = NaN;                     % gaps, never zeros
            hLine.XData = S.t_s; hLine.YData = y;
            ax = hLine.Parent; yl = ylim(ax);
            bad = ~S.valid;
            hBad.XData = S.t_s(bad); hBad.YData = repmat(yl(1), nnz(bad), 1);
            if nnz(bad) > 0
                r = unique(S.invalid_reason(bad));
                sub = "invalid readings: " + nnz(bad) + " (" + strjoin(r, ", ") + ")";
            else
                sub = "invalid readings: 0";
            end
            if string(ax.Subtitle.String) ~= sub, ax.Subtitle.String = sub; end
        end

        function L = telemetryLines(app)
            rb = app.Bundle; P = rb.poses; n = app.Cursor;
            if n == 0
                L = ["VIRTUAL TELEMETRY"; "No recorded poses (EMPTY run)."]; return
            end
            d = sum(hypot(diff(P.x_east_m(1:n)), diff(P.y_north_m(1:n))));
            L = [ "VIRTUAL TELEMETRY (simulated)"
                "t_sim: " + local_t(P.t_s(n)) + "   pose " + n + "/" + app.nPoses()
                sprintf("ENU x %.2f  y %.2f m", P.x_east_m(n), P.y_north_m(n))
                sprintf("z_up (datum) %.2f m", P.z_up_m(n))
                "progress: " + sprintf('%.1f', 100 * n / app.nPoses()) + " %   dist so far: " + sprintf('%.1f', d) + " m"
                "cells visited so far: " + nnz(app.visitedUpTo(n)) + " / " + app.CellNx * app.CellNy ];
            if ismember('virtual_lat_deg', P.Properties.VariableNames) && isfinite(P.virtual_lat_deg(n))
                L(end+1) = sprintf("VIRTUAL geotag lat %.6f lon %.6f (synthetic)", P.virtual_lat_deg(n), P.virtual_lon_deg(n));
            else
                L(end+1) = "Virtual GPS unavailable";
            end
            if ismember('waypoint_id', P.Properties.VariableNames), L(end+1) = "waypoint: " + P.waypoint_id(n); end
            if isfield(rb, 'coverage')
                c = rb.coverage;
                L(end+1) = sprintf("run coverage (MG-005): %.3f (%d/%d)", c.coverage_fraction, c.visited_valid_cells, c.total_valid_cells);
                L(end+1) = sprintf("route: %.1f m, %.1f s simulated", c.distance_m, c.mission_time_s);
            end
        end

        % ---------------- export ----------------
        function files = writeExport(app, dirp, stamp)
            rb = app.Bundle;
            files = ["poses.csv","thermal_samples.csv","em_samples.csv","events.csv","summary.json","run_bundle_redacted.mat","snapshot.png"];
            writetable(rb.poses, fullfile(dirp, files(1)));
            writetable(rb.thermal_samples, fullfile(dirp, files(2)));
            writetable(rb.em_samples, fullfile(dirp, files(3)));
            writetable(rb.events, fullfile(dirp, files(4)));
            summary = struct('banner', app.Banner, 'export_created_utc', stamp, 'scenario_id', rb.scenario_id, ...
                'provenance', rb.provenance, ...
                'rows', struct('poses', height(rb.poses), 'thermal_samples', height(rb.thermal_samples), ...
                    'em_samples', height(rb.em_samples), 'events', height(rb.events)), ...
                'columns', struct('poses', {rb.poses.Properties.VariableNames}, 'thermal_samples', {rb.thermal_samples.Properties.VariableNames}, ...
                    'em_samples', {rb.em_samples.Properties.VariableNames}, 'events', {rb.events.Properties.VariableNames}), ...
                'events_note', local_eventsNote(height(rb.events)), 'replay_state_at_export', app.State, ...
                'replay_t_s_at_export', app.currentTime(), 'redaction', "allowlisted view bundle (MG-010 §2.2); no hidden truth");
            if isfield(rb, 'result'), summary.result = rb.result; else, summary.result = "NOT RUN"; end
            fid = fopen(fullfile(dirp, files(5)), 'w'); fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true)); fclose(fid);
            runBundle = rb;
            save(fullfile(dirp, files(6)), 'runBundle');
            exportapp(app.Fig, fullfile(dirp, files(7)));
        end

        function verifyExport(app, dirp, files)
            rb = app.Bundle;
            names = ["poses","thermal_samples","em_samples","events"];
            for k = 1:4
                f = fullfile(dirp, files(k));
                if ~isfile(f), error('mineguard:ExportFailed', 'Missing %s after write.', files(k)); end
                T = readtable(f, 'TextType', 'string', 'Delimiter', ',');
                src = rb.(names(k));
                if height(src) > 0 && height(T) ~= height(src)
                    error('mineguard:ExportFailed', 'Row count mismatch in %s (%d vs %d).', files(k), height(T), height(src));
                end
                hdr = string(strsplit(strtrim(string(fgetl_first(f))), ','));
                if ~isequal(hdr, string(src.Properties.VariableNames))
                    error('mineguard:ExportFailed', 'Column header mismatch in %s.', files(k));
                end
            end
            js = jsondecode(fileread(fullfile(dirp, files(5))));
            if string(js.scenario_id) ~= rb.scenario_id || js.rows.events ~= height(rb.events)
                error('mineguard:ExportFailed', 'summary.json does not match the run.');
            end
            m = load(fullfile(dirp, files(6)));
            if ~isequaln(m.runBundle, rb)
                error('mineguard:ExportFailed', 'MAT round-trip differs from the run bundle.');
            end
            img = imread(fullfile(dirp, files(7)));
            if isempty(img) || size(img, 1) < 100
                error('mineguard:ExportFailed', 'Snapshot PNG unreadable.');
            end
        end
    end
end

function s = local_str(v)
if isstring(v) || ischar(v), s = string(v); elseif isnumeric(v) || islogical(v), s = strjoin(string(v), ","); else, s = "NOT_RECORDED"; end
if strlength(s) == 0, s = "NOT_RECORDED"; end
end
function s = local_ratio(v)
if isnan(v), s = "Undefined (zero denominator)"; else, s = sprintf('%.3f', v); end
end
function s = local_t(t)
if isnan(t), s = "—"; else, s = sprintf('%.2f s', t); end
end
function s = local_onoff(c)
if c, s = "on"; else, s = "off"; end
end
function s = local_eventsNote(n)
if n == 0, s = "No suspected events in this simulated run."; else, s = n + " SUSPECTED events (estimated positions; not confirmed)."; end
end
function line = fgetl_first(f)
fid = fopen(f, 'r'); c = onCleanup(@() fclose(fid)); line = fgetl(fid);
end
