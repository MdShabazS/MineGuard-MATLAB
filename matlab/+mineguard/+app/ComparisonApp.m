classdef ComparisonApp < handle
    %COMPARISONAPP Fixed-grid vs PPO side-by-side summary window (MG-019). Create via openComparisonApp.
    properties (Constant)
        Banner = "SIMULATION — synthetic data; not validated for real landmine detection or clearance."
    end
    properties (SetAccess = private)
        GridBundle
        PPOBundle
        Comparison table
        State string = "READY"
        StatusText string = ""
        LastExport struct = struct()
        Replays = {}
    end
    properties (Access = private)
        Fig
        H
    end

    methods
        function app = ComparisonApp(gb, pb, cmp)
            app.GridBundle = gb; app.PPOBundle = pb; app.Comparison = cmp;
            try
                app.build();
            catch err
                if ~isempty(app.Fig) && isvalid(app.Fig), delete(app.Fig); end
                rethrow(err);
            end
        end
        function f = figureHandle(app), f = app.Fig; end
        function h = uiHandles(app), h = app.H; end
        function s = viewState(app)
            s = struct('state', app.State, 'banner', string(app.H.banner.Text), ...
                'grid_title', string(app.H.axG.Title.String), 'ppo_title', string(app.H.axP.Title.String), ...
                'summary', string(app.H.summary.Value), 'table_rows', height(app.H.table.Data), ...
                'grid_route_points', numel(app.H.gridTrace.XData), 'ppo_route_points', numel(app.H.ppoTrace.XData), ...
                'grid_events', numel(app.H.gridEv.XData) - any(isnan(app.H.gridEv.XData)), ...
                'ppo_events', numel(app.H.ppoEv.XData) - any(isnan(app.H.ppoEv.XData)));
        end
        function a = openReplay(app, which)
            % Open the full MG-011 dashboard for "grid" or "ppo".
            if string(which) == "grid"
                if isempty(app.GridBundle)
                    app.StatusText = "Fixed-grid replay NOT AVAILABLE (route infeasible / not run)."; app.H.status.Text = app.StatusText; a = []; return
                end
                a = mineguard.app.openMissionApp(app.GridBundle);
            else
                a = mineguard.app.openMissionApp(app.PPOBundle);
            end
            app.Replays{end+1} = a;
        end
        function ok = exportComparison(app, folder)
            % Write comparison.csv, summary.txt and comparison.png into a new subfolder of FOLDER,
            % read them back, and only then report success. A cancel (0 or "") writes nothing.
            ok = false;
            if nargin < 2, folder = uigetdir(pwd, 'Select export destination'); end
            if isequal(folder, 0) || strlength(string(folder)) == 0
                app.StatusText = "Export cancelled: no files written."; app.H.status.Text = app.StatusText; return
            end
            stamp = string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyyMMdd''T''HHmmss''Z'''));
            final = fullfile(string(folder), "MG019-comparison-" + app.PPOBundle.scenario_id + "-" + stamp);
            tmp = fullfile(tempdir, "MG019-cmp-" + stamp + "-partial");
            try
                if ~isfolder(folder), error('mineguard:ExportFailed', 'Destination does not exist: %s', folder); end
                mkdir(tmp);
                writetable(app.Comparison, fullfile(tmp, 'comparison.csv'));
                fid = fopen(fullfile(tmp, 'summary.txt'), 'w'); fprintf(fid, '%s\n', [app.Banner; string(app.H.summary.Value)]); fclose(fid);
                exportapp(app.Fig, fullfile(tmp, 'comparison.png'));
                T = readtable(fullfile(tmp, 'comparison.csv'), 'TextType', 'string');
                if height(T) ~= height(app.Comparison), error('mineguard:ExportFailed', 'comparison.csv read-back mismatch.'); end
                if size(imread(fullfile(tmp, 'comparison.png')), 1) < 200, error('mineguard:ExportFailed', 'PNG unreadable.'); end
                [st, msg] = movefile(tmp, final); if ~st, error('mineguard:ExportFailed', '%s', msg); end
                app.LastExport = struct('folder', final); ok = true;
                app.StatusText = "Comparison export verified: " + final;
            catch err
                if isfolder(tmp), rmdir(tmp, 's'); end
                app.StatusText = "Export FAILED (no export claimed): " + string(err.message);
            end
            app.H.status.Text = app.StatusText;
        end
        function close(app)
            for k = 1:numel(app.Replays)
                if ~isempty(app.Replays{k}) && isvalid(app.Replays{k}), app.Replays{k}.close(); end
            end
            if ~isempty(app.Fig) && isvalid(app.Fig), delete(app.Fig); end
            app.State = "CLOSED";
        end
        function delete(app)
            if app.State ~= "CLOSED", app.close(); end
        end
    end

    methods (Access = private)
        function build(app)
            pb = app.PPOBundle; gb = app.GridBundle;
            app.Fig = uifigure('Name', 'MineGuard — Fixed grid vs PPO (SIMULATION)', 'Position', [80 80 1300 760], ...
                'CloseRequestFcn', @(~, ~) app.close());
            g = uigridlayout(app.Fig, [5 2], 'RowHeight', {28, 26, '1x', 150, 30}, 'ColumnWidth', {'1x', '1x'});
            H = struct();
            H.header = uilabel(g, 'FontWeight', 'bold', 'FontSize', 15, 'Text', "MINEGUARD SIMULATION  |  planner comparison  |  scenario " + pb.scenario_id);
            H.header.Layout.Column = [1 2];
            H.banner = uilabel(g, 'Text', app.Banner, 'FontWeight', 'bold', 'FontColor', [1 1 1], 'BackgroundColor', [0.70 0.15 0.10], 'HorizontalAlignment', 'center');
            H.banner.Layout.Column = [1 2];
            H.axG = uiaxes(g); H.axP = uiaxes(g);
            [H.gridTrace, H.gridEv] = app.drawMap(H.axG, gb, "FIXED GRID (MG-005)");
            [H.ppoTrace, H.ppoEv] = app.drawMap(H.axP, pb, "PPO (frozen MG-013 checkpoint)");
            H.table = uitable(g, 'Data', app.displayTable(), 'RowName', {}, 'FontSize', 11);
            H.summary = uitextarea(g, 'Editable', 'off', 'FontName', 'Consolas', 'Value', app.summaryLines());
            bar = uigridlayout(g, [1 4], 'Padding', [0 0 0 0]); bar.Layout.Column = [1 2];
            H.openGrid = uibutton(bar, 'Text', 'Open fixed-grid replay', 'ButtonPushedFcn', @(~, ~) app.openReplay("grid"));
            H.openPPO = uibutton(bar, 'Text', 'Open PPO replay', 'ButtonPushedFcn', @(~, ~) app.openReplay("ppo"));
            H.export = uibutton(bar, 'Text', 'Export comparison…', 'ButtonPushedFcn', @(~, ~) app.exportComparison());
            H.status = uilabel(bar, 'Text', '', 'FontColor', [0.1 0.1 0.5]);
            if isempty(gb), H.openGrid.Enable = 'off'; end
            app.H = H;
        end

        function [hTrace, hEv] = drawMap(~, ax, rb, name)
            hold(ax, 'on'); axis(ax, 'equal'); box(ax, 'on'); grid(ax, 'on');
            xlabel(ax, 'x east [m]'); ylabel(ax, 'y north [m]');
            if isempty(rb)
                title(ax, name + " — NOT RUN (route infeasible: MG-005 RouteConflict)");
                hTrace = plot(ax, NaN, NaN); hEv = plot(ax, NaN, NaN); return
            end
            b = double(rb.geometry.bounds_enu_m); s = rb.display_settings.grid_spacing_m;
            nx = ceil((b(2) - b(1)) / s - 1e-9); ny = ceil((b(4) - b(3)) / s - 1e-9); dx = (b(2) - b(1)) / nx; dy = (b(4) - b(3)) / ny;
            P = rb.poses;
            ix = min(nx, max(1, floor((P.x_east_m - b(1)) / dx) + 1)); iy = min(ny, max(1, floor((P.y_north_m - b(3)) / dy) + 1));
            V = false(ny, nx); V(sub2ind([ny nx], iy, ix)) = true;
            C = repmat(reshape([0.55 0.85 0.55], 1, 1, 3), ny, nx);
            image(ax, 'XData', [b(1) + dx / 2, b(2) - dx / 2], 'YData', [b(3) + dy / 2, b(4) - dy / 2], 'CData', C, 'AlphaData', 0.45 * double(V));
            plot(ax, b([1 2 2 1 1]), b([3 3 4 4 3]), 'k-', 'LineWidth', 1.5);
            polys = rb.geometry.exclusion_polygons_enu_m;
            for k = 1:numel(polys), patch(ax, polys{k}(:,1), polys{k}(:,2), [0.85 0.3 0.3], 'FaceAlpha', 0.35, 'EdgeColor', [0.6 0 0]); end
            hTrace = plot(ax, P.x_east_m, P.y_north_m, '-', 'Color', [0 0.35 0.8], 'LineWidth', 1.4);
            plot(ax, P.x_east_m(1), P.y_north_m(1), 's', 'MarkerFaceColor', [0 0.6 0.2], 'MarkerEdgeColor', 'k', 'MarkerSize', 9);
            E = rb.events;
            if height(E) > 0
                hEv = plot(ax, E.x_est_m, E.y_est_m, 'p', 'MarkerSize', 12, 'MarkerFaceColor', [1 0.6 0], 'MarkerEdgeColor', 'k');
            else
                hEv = plot(ax, NaN, NaN, 'p');
            end
            c = rb.coverage;
            title(ax, sprintf('%s — coverage %.2f (%d/%d), %.1f m, %.1f s, %d SUSPECTED', name, c.coverage_fraction, ...
                c.visited_valid_cells, c.total_valid_cells, c.distance_m, c.mission_time_s, height(E)), 'Interpreter', 'none');
            pad = 0.03 * (b(2) - b(1)); xlim(ax, [b(1) - pad, b(2) + pad]); ylim(ax, [b(3) - pad, b(4) + pad]);
        end

        function D = displayTable(app)
            T = app.Comparison;
            keep = intersect(["planner","reason","completed","coverage_fraction","unique_cells","distance_m","mission_time_s", ...
                "coverage_per_m","invalid_actions","revisits","decisions","events","tp","fp","fn"], string(T.Properties.VariableNames), 'stable');
            D = T(:, keep);
            for v = keep
                if isnumeric(D.(v)), D.(v) = round(D.(v), 3); end
            end
        end

        function L = summaryLines(app)
            T = app.Comparison;
            g = T(T.planner == "grid", :); p = T(T.planner == "ppo", :);
            L = "PLANNER COMPARISON (same scenario, start cell, budget D_max 60 m / T_max 30 s / 50 decisions, motion model)";
            if isempty(g) || ~g.executed(1)
                why = "no record"; if ~isempty(g), why = g.reason(1); end
                L(end+1) = "Fixed grid: NOT RUN — " + why + " (MG-005 does not reroute). PPO metrics shown alone; not a PPO 'win'.";
            else
                L(end+1) = sprintf("Δcoverage (PPO−grid) %+.3f   Δdistance %+.1f m   Δtime %+.1f s   PPO invalid actions %d, revisits %d", ...
                    p.coverage_fraction(1) - g.coverage_fraction(1), p.distance_m(1) - g.distance_m(1), p.mission_time_s(1) - g.mission_time_s(1), ...
                    p.invalid_actions(1), p.revisits(1));
            end
            L(end+1) = "PPO termination: " + p.reason(1) + "   completed (all legal cells): " + string(p.completed(1));
            L(end+1) = "Detection columns are exploratory: the routes sample different positions, so sensor readings differ.";
            L(end+1) = "Navigation is the primary comparison. Fixed grid remains the release baseline.";
            L(end+1) = "Not evidence of real mine detection, clearance or flight safety.";
        end
    end
end

