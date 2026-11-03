classdef EvaluationView < handle
    %EVALUATIONVIEW Post-run EVALUATION view: reveals the private synthetic targets after the run (V21-006). SIMULATION ONLY.
    %   v = mgv21.ui.EvaluationView(world, pub, poses, events, truth, R)    R from mgv21.evaluation.evaluateRun
    %   Opened only after a run ended. It is the one place where virtual target positions are drawn, in its own window,
    %   labelled as an INTERACTIVE SYNTHETIC DEMO evaluation (contract eval_label). It is not shown in the live dashboard.
    %   Events: matched (green) and false alarms (red), from R.matched_event_index.
    %   Targets: matched / missed only when R carries matched_target_index (optional field). Without it, targets are
    %   drawn in one colour and labelled "match assignment unavailable": matching is never recomputed here.
    %   Counts and precision/recall come from R; NaN is shown as "undefined", never 0.

    properties (SetAccess = private)
        Figure; Axes; ReportArea
        Counts            % struct: n_events, n_targets, TP, FP, FN, matched_targets_known
    end

    methods
        function obj = EvaluationView(world, pub, poses, events, truth, R, opts)
            arguments
                world struct
                pub struct
                poses table
                events
                truth struct
                R struct
                opts.Visible (1,1) string = "on"
                opts.RunId (1,1) string = ""
            end
            c = mgv21.contract(); t = mgv2.ui.theme();
            obj.Figure = uifigure('Name', 'EVALUATION VIEW - ' + c.eval_label, 'Color', t.bg, 'Visible', opts.Visible, ...
                'Position', [80 80 1180 720], 'Tag', 'mgv21_evaluation');
            g = uigridlayout(obj.Figure, [2 2], 'RowHeight', {44, '1x'}, 'ColumnWidth', {'1.4x', '1x'}, 'BackgroundColor', t.bg);
            b = uilabel(g, 'Text', "EVALUATION VIEW (after the run) - " + c.eval_label + ". Virtual synthetic targets are revealed here only. " + ...
                "SUSPECTED anomalies are not mines; no ground is cleared.", 'FontWeight', 'bold', 'FontColor', [1 1 1], ...
                'BackgroundColor', [0.45 0.08 0.08], 'WordWrap', 'on', 'HorizontalAlignment', 'center');
            b.Layout.Row = 1; b.Layout.Column = [1 2];
            obj.Axes = uiaxes(g, 'Color', [0.1 0.11 0.13]); obj.Axes.Layout.Row = 2; obj.Axes.Layout.Column = 1;
            obj.ReportArea = uitextarea(g, 'Editable', 'off', 'FontName', t.mono, 'FontSize', 11, 'BackgroundColor', [0.12 0.13 0.15], 'FontColor', t.text);
            obj.ReportArea.Layout.Row = 2; obj.ReportArea.Layout.Column = 2;
            obj.draw(world, pub, poses, events, truth, R);
            lines = string(mgv21.evaluation.formatReport(R));
            obj.ReportArea.Value = [ "Run: " + opts.RunId; "Preset: " + string(pub.preset_id); "Run state: " + string(R.run_state); ""; lines(:); ""; obj.legendNote()];
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure), delete(obj.Figure); end
        end
    end

    methods (Access = private)
        function draw(obj, world, pub, poses, events, truth, R)
            ax = obj.Axes; hold(ax, 'on');
            image(ax, world.x, world.y, reshape(world.vertex_rgb, numel(world.y), numel(world.x), 3), 'AlphaData', 0.62);
            ax.YDir = 'normal'; axis(ax, 'equal'); e = world.config.extent_enu_m; xlim(ax, e(1, :)); ylim(ax, e(2, :));
            P = pub.mission.survey_polygon_enu_m; P = [P; P(1, :)];
            h = gobjects(0); names = strings(0);
            h(end+1) = plot(ax, P(:,1), P(:,2), '-', 'Color', [1 0.82 0.1], 'LineWidth', 2); names(end+1) = "survey boundary";
            h(end+1) = plot(ax, poses.position_enu_m(:,1), poses.position_enu_m(:,2), '-', 'Color', [0.15 0.45 1], 'LineWidth', 1.4); names(end+1) = "flown route";
            xy = zeros(0, 2);
            if ~isempty(events), xy = [[events.x_est_m]' [events.y_est_m]']; end
            nE = size(xy, 1); mE = false(nE, 1); mE(R.matched_event_index) = true;
            if any(mE), h(end+1) = plot(ax, xy(mE,1), xy(mE,2), 'o', 'MarkerSize', 9, 'MarkerFaceColor', [0.2 0.85 0.3], 'MarkerEdgeColor', 'k'); names(end+1) = "event matched to a target"; end
            if any(~mE), h(end+1) = plot(ax, xy(~mE,1), xy(~mE,2), 'd', 'MarkerSize', 7, 'MarkerFaceColor', [0.9 0.2 0.2], 'MarkerEdgeColor', 'k'); names(end+1) = "false alarm (SUSPECTED, no target)"; end
            T = truth.targets; tx = [T.x_east_m T.y_north_m]; nT = height(T);
            known = isfield(R, 'matched_target_index'); mT = false(nT, 1);
            if known, mT(R.matched_target_index) = true; end
            none = T.surface_signature == "NONE";
            if known
                sets = {mT, "virtual target: detected (matched)", [0.2 0.85 0.3]; ~mT & ~none, "virtual target: missed", [1 0.55 0.1]; ...
                    ~mT & none, "virtual target: missed, no surface signature (unobservable)", [0.7 0.7 0.7]};
            else
                sets = {true(nT, 1), "virtual target (match assignment unavailable)", [1 1 1]};
            end
            for k = 1:size(sets, 1)
                sel = sets{k, 1};
                if any(sel)
                    h(end+1) = plot(ax, tx(sel,1), tx(sel,2), 'x', 'MarkerSize', 12, 'LineWidth', 2.5, 'Color', sets{k, 3}); %#ok<AGROW>
                    names(end+1) = sets{k, 2}; %#ok<AGROW>
                end
            end
            legend(ax, h, cellstr(names), 'Location', 'southoutside', 'TextColor', 'w', 'Color', [0.1 0.11 0.13], 'NumColumns', 2);
            set(ax, 'XColor', 'w', 'YColor', 'w'); xlabel(ax, 'E [m]'); ylabel(ax, 'N [m]');
            title(ax, sprintf('%d events, %d virtual targets', nE, nT), 'Color', 'w');
            obj.Counts = struct('n_events', nE, 'n_targets', nT, 'TP', R.TP, 'FP', R.FP, 'FN', R.FN, 'matched_targets_known', known);
        end

        function s = legendNote(~)
            s = "Match radius and counts come from the independent evaluator. Precision and recall are undefined (NaN) " + ...
                "when their denominator is zero. Scores are uncalibrated.";
        end
    end
end
