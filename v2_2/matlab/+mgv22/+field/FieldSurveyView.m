classdef FieldSurveyView < handle
    %FIELDSURVEYVIEW Draw a field on the BITM satellite view and fly a SIMULATED drone survey of it (V22-T11).
    %   v = mgv22.field.FieldSurveyView()
    %   v = mgv22.field.FieldSurveyView(Site=mgv22.siteConfig(), MetadataReader=[], Visible="on", Theme="dark")
    %
    %   Real imagery, SIMULATED flight. Marks are hollow "SUSPECTED anomaly (SIMULATION)" symbols, the map carries a
    %   persistent "SIMULATION — NOT A HAZARD MAP" watermark and a low-coverage layer. SYNTHETIC targets are drawn
    %   only while the evaluation toggle is on. Nothing is exported or written to disk.
    %
    %   Methods: startDraw(), addVertex([lat lon]), undoVertex(), cancelDraw(), finishDraw(), plan(fieldLL),
    %   run(), setEvaluation(tf), r = results(), close(), isOpen(), delete().
    %   Errors are shown in StatusText (never a blocking dialog); programmatic calls still throw afterwards.

    properties (SetAccess = private)
        Site
        Theme = "dark"
        Source = []
        % --- figure frame
        Figure
        Axes
        Banner
        Credits
        StatusLabel
        Link
        Watermark
        MapLegend
        % --- left panel
        DrawButton
        UndoButton
        CancelButton
        FinishButton
        StatusText
        AreaLabel
        AltitudeLabel
        GsdLabel
        PixelsLabel
        SpacingLabel
        SpeedLabel
        LinesLabel
        TimeLabel
        TargetsField
        SeedField
        AllowHullCheck
        RunButton
        ProgressLabel
        SuspectedLabel
        CoverageLabel
        DetectionLabel
        FalseAlarmLabel
        EvaluationCheck
        WordingLabel
        % --- map layers (read-only)
        FieldLine
        RouteLine
        HomeMarker
        CoverageLayer
        SuspectedMarks
        SyntheticTargets
        DraftLine
        DraftLabels
        % --- state
        Plan = []
        Survey = []
        FieldLL = zeros(0, 2)
        DraftLL = zeros(0, 2)
        Drawing = false
        EvaluationVisible = false
        Running = false
    end

    properties (Access = private)
        MetadataReader = []
        Evaluation = []
        Colours
        CellM = 1
    end

    methods
        function obj = FieldSurveyView(opts)
            arguments
                opts.Site struct = mgv22.siteConfig()
                opts.MetadataReader = []
                opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
                opts.Theme (1,1) string {mustBeMember(opts.Theme, ["dark","light"])} = "dark"
            end
            mgv22.field.FieldSurveyView.checkSite(opts.Site);
            obj.Site = opts.Site; obj.Theme = opts.Theme; obj.MetadataReader = opts.MetadataReader;
            obj.resetHandles();
            obj.build(opts.Visible);
        end

        % ------------------------------------------------------------------ draw tool
        function startDraw(obj)
            obj.removeDraft();
            obj.Drawing = true; obj.DraftLL = zeros(0, 2);
            if obj.isOpen()
                set([obj.UndoButton obj.CancelButton obj.FinishButton], 'Enable', 'on');
                obj.Axes.ButtonDownFcn = @(~, ~) obj.onAxesClick();   % clicks add points only while drawing
                try disableDefaultInteractivity(obj.Axes); catch, end
            end
            obj.showStatus("Click the field corners on the map. Double-click or Finish to complete (VIRTUAL survey area).", false);
        end

        function addVertex(obj, latlon)
            if ~obj.Drawing
                error('mgv22:NotDrawing', 'Press "1. Draw field" first.');
            end
            latlon = double(latlon(:)');
            if numel(latlon) ~= 2 || any(~isfinite(latlon))
                error('mgv22:InvalidVertex', 'A vertex is a finite [lat lon] point in degrees.');
            end
            obj.DraftLL(end + 1, :) = latlon;
            obj.drawDraft();
        end

        function undoVertex(obj)
            if ~obj.Drawing || isempty(obj.DraftLL), return; end
            obj.DraftLL(end, :) = [];
            obj.drawDraft();
        end

        function cancelDraw(obj)
            if ~obj.Drawing, return; end
            obj.endDraw();
            obj.showStatus("Drawing cancelled.", false);
        end

        function finishDraw(obj)
            if ~obj.Drawing, return; end
            ll = obj.DraftLL;
            obj.plan(ll);            % keeps the draft (and draw mode) if the field is rejected
            obj.endDraw();
        end

        % ------------------------------------------------------------------ plan and run
        function P = plan(obj, fieldLL)
            fieldLL = double(fieldLL);
            if size(fieldLL, 2) ~= 2 || size(fieldLL, 1) < 3 || any(~isfinite(fieldLL(:)))
                obj.showStatus("Field rejected: draw at least three finite corner points.", true);
                error('mgv22:InvalidOutline', 'A field needs at least three finite [lat lon] corners.');
            end
            obj.FieldLL = fieldLL;
            allowHull = obj.isOpen() && logical(obj.AllowHullCheck.Value);
            try
                P = mgv22.field.surveyPlan(fieldLL, Site=obj.Site, AllowHull=allowHull);
            catch err
                if err.identifier == "mgv22:NonConvexField"
                    obj.showStatus("Field rejected: " + string(err.message) + ...
                        " Tick ""Allow convex hull"" to plan its convex hull instead.", true);
                else
                    obj.showStatus("Field rejected: " + string(err.message), true);
                end
                rethrow(err);
            end
            obj.Plan = P; obj.Survey = []; obj.Evaluation = [];
            if obj.isOpen()
                obj.drawPlan();
                obj.drawResults();
                obj.updatePanel();
                obj.zoomToField();
                obj.RunButton.Enable = 'on';
            end
            obj.showStatus(sprintf('Planned: %.2f ha, %d lines at %.1f m (VIRTUAL route). Press "2. Run simulated survey".', ...
                P.area_ha, P.n_lines, P.alt_m), false);
        end

        function S = run(obj)
            if isempty(obj.Plan)
                obj.showStatus("Draw a field first.", true);
                error('mgv22:NoPlan', 'Draw and plan a field first.');
            end
            n = 6; seed = 1;
            if obj.isOpen()
                n = obj.TargetsField.Value; seed = obj.SeedField.Value;
                obj.RunButton.Enable = 'off'; obj.DrawButton.Enable = 'off';
                obj.ProgressLabel.Text = 'Simulated flight starting...';
                drawnow limitrate;
            end
            obj.Running = true;
            try
                S = mgv22.field.runSurvey(obj.Plan, TargetCount=n, Seed=seed, Progress=@(t, T) obj.onProgress(t, T));
            catch err
                obj.Running = false;
                if obj.isOpen()
                    obj.RunButton.Enable = 'on'; obj.DrawButton.Enable = 'on';
                    obj.ProgressLabel.Text = 'Simulated flight stopped.';
                end
                obj.showStatus("Simulated survey failed: " + string(err.message), true);
                rethrow(err);
            end
            obj.Running = false;
            if isfield(S, 'evaluation'), obj.Evaluation = S.evaluation; S = rmfield(S, 'evaluation'); else, obj.Evaluation = []; end
            obj.Survey = S;
            if obj.isOpen()
                obj.RunButton.Enable = 'on'; obj.DrawButton.Enable = 'on';
                obj.ProgressLabel.Text = sprintf('Simulated flight done: %d ticks, %.0f s sim, %.1f s wall.', ...
                    S.ticks, S.sim_s, S.wall_s);
                obj.drawResults();
                obj.updatePanel();
            end
            obj.showStatus(sprintf('%d SUSPECTED anomalies (SIMULATION).', numel(S.events)), false);
        end

        function setEvaluation(obj, tf)
            obj.EvaluationVisible = logical(tf);
            if ~obj.isOpen(), return; end
            obj.EvaluationCheck.Value = obj.EvaluationVisible;
            obj.drawSynthetic();
            obj.updatePanel();
            obj.updateLegend();
        end

        % ------------------------------------------------------------------ results and life cycle
        function r = results(obj)
            r = struct('plan', obj.Plan, 'survey', obj.Survey, 'evaluation_visible', obj.EvaluationVisible, ...
                'field_ll', obj.FieldLL, 'label', "SIMULATION — NOT A HAZARD MAP");
        end

        function close(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure), delete(obj.Figure); end
            obj.resetHandles();
            obj.Drawing = false; obj.DraftLL = zeros(0, 2);
        end

        function tf = isOpen(obj)
            tf = ~isempty(obj.Figure) && isvalid(obj.Figure);
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Access = private)
        % ------------------------------------------------------------------ construction
        function build(obj, visible)
            obj.Source = mgv22.sat.basemapSource("satellite", obj.Site, obj.MetadataReader);
            c = mgv22.field.FieldSurveyView.colours(obj.Theme); obj.Colours = c;
            fig = uifigure('Name', 'BITM field survey (SIMULATION — not a hazard map)', ...
                'Position', [60 60 1320 860], 'Visible', 'off', 'Color', c.bg, 'AutoResizeChildren', 'off');
            try
                theme(fig, obj.Theme);
                g = uigridlayout(fig, [3 1], 'RowHeight', {48, '1x', 76}, 'ColumnWidth', {'1x'}, ...
                    'Padding', [8 8 8 8], 'RowSpacing', 6, 'BackgroundColor', c.bg);
                label = "REAL IMAGERY — SIMULATED FLIGHT / NOT A HAZARD MAP | FIELD SURVEY (SIMULATION)";
                if obj.Source.metadata_status == "UNAVAILABLE"
                    bannerText = "SATELLITE UNAVAILABLE — no connection to the imagery service; the map may be blank  |  " + label;
                    bannerColour = c.offline;
                else
                    bannerText = label;
                    bannerColour = c.banner;
                end
                obj.Banner = uilabel(g, 'Text', bannerText, 'FontWeight', 'bold', 'FontSize', 13, 'FontColor', c.text, ...
                    'BackgroundColor', bannerColour, 'HorizontalAlignment', 'center', 'WordWrap', 'on');
                obj.Banner.Layout.Row = 1;

                mid = uigridlayout(g, [1 2], 'ColumnWidth', {310, '1x'}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
                    'ColumnSpacing', 8, 'BackgroundColor', c.bg);
                mid.Layout.Row = 2;
                obj.buildPanel(mid, c);

                gx = geoaxes(mid, 'Basemap', 'satellite');
                gx.Layout.Row = 1; gx.Layout.Column = 2; gx.AxisColor = c.text;
                hold(gx, 'on');
                geolimits(gx, obj.Site.view_window.lat, obj.Site.view_window.lon);
                obj.Axes = gx;
                % persistent watermark: the axes title stays in view whatever the user pans or zooms to
                obj.Watermark = title(gx, 'SIMULATION — NOT A HAZARD MAP', 'FontSize', 16, 'FontWeight', 'bold', 'Color', c.warn);

                foot = uigridlayout(g, [3 1], 'RowHeight', {'1x', 18, 18}, 'Padding', [2 0 2 0], 'RowSpacing', 0, 'BackgroundColor', c.bg);
                foot.Layout.Row = 3;
                obj.Credits = uilabel(foot, 'Text', obj.Source.credit, 'WordWrap', 'on', 'FontSize', 11, 'FontColor', c.text);
                obj.Credits.Layout.Row = 1;
                obj.StatusLabel = uilabel(foot, 'Text', obj.Source.status, 'FontSize', 10, 'FontColor', c.warn);
                obj.StatusLabel.Layout.Row = 2;
                obj.Link = uihyperlink(foot, 'Text', obj.Source.link_text, 'URL', obj.Source.url, 'FontSize', 10, 'FontColor', c.link);
                obj.Link.Layout.Row = 3;

                fig.CloseRequestFcn = @(~, ~) obj.close();
                fig.SizeChangedFcn = @(~, ~) obj.updateMarkerSize();
                obj.Figure = fig;
                gx.LatitudeAxis.LimitsChangedFcn = @(~, ~) obj.updateMarkerSize();   % zoom and pan keep cells the right size
                obj.updatePanel();
                fig.Visible = char(visible);
                drawnow limitrate;
            catch err
                if isvalid(fig), delete(fig); end
                obj.resetHandles();
                rethrow(err);
            end
        end

        function buildPanel(obj, parent, c)
            p = uigridlayout(parent, [24 2], 'ColumnWidth', {112, '1x'}, 'Padding', [6 6 6 6], 'RowSpacing', 4, ...
                'ColumnSpacing', 6, 'Scrollable', 'on', 'BackgroundColor', c.panel);
            p.Layout.Row = 1; p.Layout.Column = 1;
            p.RowHeight = {22, 28, 28, 54, 20, 20, 20, 34, 20, 20, 20, 20, 24, 24, 24, 30, 34, 20, 20, 34, 34, 24, 70, 1};
            t = uilabel(p, 'Text', 'Field survey — SIMULATION', 'FontWeight', 'bold', 'FontColor', c.text);
            t.Layout.Row = 1; t.Layout.Column = [1 2];

            obj.DrawButton = uibutton(p, 'Text', '1. Draw field', 'ButtonPushedFcn', @(~, ~) obj.guarded(@() obj.startDraw()));
            obj.DrawButton.Layout.Row = 2; obj.DrawButton.Layout.Column = [1 2];
            b = uigridlayout(p, [1 3], 'ColumnWidth', {'1x', '1x', '1x'}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4, 'BackgroundColor', c.panel);
            b.Layout.Row = 3; b.Layout.Column = [1 2];
            obj.UndoButton = uibutton(b, 'Text', 'Undo', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.guarded(@() obj.undoVertex()));
            obj.CancelButton = uibutton(b, 'Text', 'Cancel', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.guarded(@() obj.cancelDraw()));
            obj.FinishButton = uibutton(b, 'Text', 'Finish', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.guarded(@() obj.finishDraw()));

            obj.StatusText = uilabel(p, 'Text', 'Press "1. Draw field", then click the field corners on the map.', ...
                'WordWrap', 'on', 'FontSize', 11, 'FontColor', c.warn, 'VerticalAlignment', 'top');
            obj.StatusText.Layout.Row = 4; obj.StatusText.Layout.Column = [1 2];

            names = ["Field area", "Altitude", "GSD (RGB)", "Pixels on target", "Line spacing", "Speed", "Lines", "Est. sim time"];
            rows = 5:12;
            vals = gobjects(1, numel(names));
            for k = 1:numel(names)
                l = uilabel(p, 'Text', names(k), 'FontColor', c.text); l.Layout.Row = rows(k); l.Layout.Column = 1;
                vals(k) = uilabel(p, 'Text', '—', 'FontColor', c.text, 'FontWeight', 'bold', 'WordWrap', 'on');
                vals(k).Layout.Row = rows(k); vals(k).Layout.Column = 2;
            end
            [obj.AreaLabel, obj.AltitudeLabel, obj.GsdLabel, obj.PixelsLabel, obj.SpacingLabel, obj.SpeedLabel, ...
                obj.LinesLabel, obj.TimeLabel] = deal(vals(1), vals(2), vals(3), vals(4), vals(5), vals(6), vals(7), vals(8));

            l = uilabel(p, 'Text', 'SYNTHETIC targets', 'FontColor', c.text); l.Layout.Row = 13; l.Layout.Column = 1;
            obj.TargetsField = uieditfield(p, 'numeric', 'Value', 6, 'Limits', [0 30], 'RoundFractionalValues', 'on', ...
                'ValueDisplayFormat', '%.0f');
            obj.TargetsField.Layout.Row = 13; obj.TargetsField.Layout.Column = 2;
            l = uilabel(p, 'Text', 'Seed', 'FontColor', c.text); l.Layout.Row = 14; l.Layout.Column = 1;
            obj.SeedField = uieditfield(p, 'numeric', 'Value', 1, 'Limits', [0 Inf], 'RoundFractionalValues', 'on', ...
                'ValueDisplayFormat', '%.0f');
            obj.SeedField.Layout.Row = 14; obj.SeedField.Layout.Column = 2;
            obj.AllowHullCheck = uicheckbox(p, 'Text', 'Allow convex hull', 'Value', false, 'FontColor', c.text, ...
                'ValueChangedFcn', @(~, ~) obj.guarded(@() obj.onHullChanged()));
            obj.AllowHullCheck.Layout.Row = 15; obj.AllowHullCheck.Layout.Column = [1 2];

            obj.RunButton = uibutton(p, 'Text', '2. Run simulated survey', 'Enable', 'off', ...
                'ButtonPushedFcn', @(~, ~) obj.guarded(@() obj.run()));
            obj.RunButton.Layout.Row = 16; obj.RunButton.Layout.Column = [1 2];
            obj.ProgressLabel = uilabel(p, 'Text', 'No simulated flight yet.', 'FontSize', 10, 'FontColor', c.text, 'WordWrap', 'on');
            obj.ProgressLabel.Layout.Row = 17; obj.ProgressLabel.Layout.Column = [1 2];

            rnames = ["SUSPECTED", "Coverage", "Detection", "False alarms"];
            rrows = 18:21;
            rv = gobjects(1, 4);
            for k = 1:4
                l = uilabel(p, 'Text', rnames(k), 'FontColor', c.text); l.Layout.Row = rrows(k); l.Layout.Column = 1;
                rv(k) = uilabel(p, 'Text', '—', 'FontColor', c.text, 'FontWeight', 'bold', 'WordWrap', 'on');
                rv(k).Layout.Row = rrows(k); rv(k).Layout.Column = 2;
            end
            [obj.SuspectedLabel, obj.CoverageLabel, obj.DetectionLabel, obj.FalseAlarmLabel] = deal(rv(1), rv(2), rv(3), rv(4));

            obj.EvaluationCheck = uicheckbox(p, 'Text', 'Evaluation: reveal SYNTHETIC targets', 'Value', false, ...
                'FontColor', c.text, 'ValueChangedFcn', @(s, ~) obj.guarded(@() obj.setEvaluation(s.Value)));
            obj.EvaluationCheck.Layout.Row = 22; obj.EvaluationCheck.Layout.Column = [1 2];

            obj.WordingLabel = uilabel(p, 'Text', char(mgv22.wording().suspected), 'WordWrap', 'on', 'FontSize', 10, ...
                'FontColor', c.warn, 'VerticalAlignment', 'top');
            obj.WordingLabel.Layout.Row = 23; obj.WordingLabel.Layout.Column = [1 2];
        end

        % ------------------------------------------------------------------ panel
        function updatePanel(obj)
            if ~obj.isOpen(), return; end
            P = obj.Plan;
            planLabels = [obj.AreaLabel obj.AltitudeLabel obj.GsdLabel obj.PixelsLabel obj.SpacingLabel obj.SpeedLabel ...
                obj.LinesLabel obj.TimeLabel];
            if isempty(P)
                set(planLabels, 'Text', '—');
                obj.AreaLabel.Text = 'Draw a field';
            else
                obj.AreaLabel.Text = sprintf('%.0f m² (%.3f ha)', P.area_m2, P.area_ha);
                obj.AltitudeLabel.Text = sprintf('%.1f m', P.alt_m);
                obj.GsdLabel.Text = sprintf('%.2f cm/px', P.gsd_rgb_cm);
                if P.pixels_rule_met
                    obj.PixelsLabel.Text = sprintf('%.1f px on smallest target', P.pixels_on_target);
                    obj.PixelsLabel.FontColor = obj.Colours.text;
                else
                    obj.PixelsLabel.Text = sprintf('%.1f px (below the research rule)', P.pixels_on_target);
                    obj.PixelsLabel.FontColor = obj.Colours.error;
                end
                obj.SpacingLabel.Text = sprintf('%.1f m', P.spacing_m);
                obj.SpeedLabel.Text = sprintf('%.1f m/s', P.speed_mps);
                obj.LinesLabel.Text = sprintf('%d', P.n_lines);
                obj.TimeLabel.Text = sprintf('%.0f s sim (%d ticks)', P.est_flight_s, P.est_ticks);
            end
            S = obj.Survey;
            w = mgv22.wording();
            if isempty(S)
                set([obj.SuspectedLabel obj.CoverageLabel obj.DetectionLabel obj.FalseAlarmLabel], 'Text', '—');
                obj.WordingLabel.Text = char(w.suspected);
                return
            end
            nEv = numel(S.events);
            obj.SuspectedLabel.Text = sprintf('%d (SIMULATION)', nEv);
            obj.CoverageLabel.Text = sprintf('%.0f %% of field seen at least once', 100 * S.coverage.frac_covered);
            E = obj.Evaluation;
            if obj.EvaluationVisible && ~isempty(E)
                ci = 100 * double(E.detection_ci);
                obj.DetectionLabel.Text = sprintf('%d of %d visible SYNTHETIC (95 %% interval %.0f–%.0f %%)', ...
                    E.tp_visible, E.n_visible, ci(1), ci(2));
                obj.FalseAlarmLabel.Text = sprintf('%.1f per ha (95 %% interval %.1f–%.1f)', ...
                    E.fa.per_ha, E.fa.lo_per_ha, E.fa.hi_per_ha);
            else
                obj.DetectionLabel.Text = 'shown with Evaluation on';
                obj.FalseAlarmLabel.Text = 'shown with Evaluation on';
            end
            txt = string(w.suspected);
            if nEv == 0
                nd = string(w.no_detection);
                if isfield(S, 'no_detection_text') && strlength(string(S.no_detection_text)) > 0, nd = string(S.no_detection_text); end
                txt = txt + newline + nd;
            end
            obj.WordingLabel.Text = char(txt);
        end

        % ------------------------------------------------------------------ map layers
        function drawPlan(obj)
            obj.deleteLayers({'FieldLine', 'RouteLine', 'HomeMarker'});
            P = obj.Plan; gx = obj.Axes;
            poly = P.poly_ll; poly = [poly; poly(1, :)];
            obj.FieldLine = geoplot(gx, poly(:, 1), poly(:, 2), '-', 'Color', [1 0.85 0.10], 'LineWidth', 2, ...
                'DisplayName', 'Field (VIRTUAL survey area)', 'Tag', 'VIRTUAL field', 'PickableParts', 'none');
            obj.RouteLine = geoplot(gx, P.route_ll(:, 1), P.route_ll(:, 2), '--', 'Color', [0.30 0.90 1.00], 'LineWidth', 1.2, ...
                'DisplayName', 'Planned route (VIRTUAL)', 'Tag', 'VIRTUAL route', 'PickableParts', 'none');
            h = double(P.home_enu_m(:)'); if numel(h) < 3, h(3) = 0; end
            hl = mgv22.geo.enuToWgs84([h(1:2) 0], P.field_anchor_lla);
            obj.HomeMarker = geoplot(gx, hl(1), hl(2), 'p', 'MarkerSize', 14, 'Color', [1 1 1], 'MarkerFaceColor', [0.2 0.6 1], ...
                'DisplayName', 'Home pad (VIRTUAL)', 'Tag', 'VIRTUAL home', 'PickableParts', 'none');
            obj.restack(); obj.updateLegend();
        end

        function drawResults(obj)
            obj.deleteLayers({'CoverageLayer', 'SuspectedMarks', 'SyntheticTargets'});
            S = obj.Survey;
            if isempty(S) || ~obj.isOpen(), obj.updateLegend(); return; end
            gx = obj.Axes; P = obj.Plan;
            % coverage-quality layer: grey squares on field cells looked at fewer than two times
            C = S.coverage;
            [X, Y] = meshgrid(double(C.x), double(C.y));
            if isfield(C, 'low_mask') && isequal(size(C.low_mask), size(X))
                low = logical(C.low_mask);
            else
                low = C.count < 2;
            end
            if numel(C.x) > 1, obj.CellM = abs(median(diff(double(C.x)))); end
            if any(low(:))
                ll = mgv22.geo.enuToWgs84([X(low) Y(low) zeros(nnz(low), 1)], P.field_anchor_lla);
                lat = ll(:, 1); lon = ll(:, 2);
            else
                lat = zeros(0, 1); lon = zeros(0, 1);
            end
            obj.CoverageLayer = geoscatter(gx, lat, lon, obj.markerSize(), [0.55 0.55 0.55], 's', 'filled', ...
                'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.45, 'DisplayName', 'Low coverage (SIMULATION)', ...
                'Tag', 'SIMULATION coverage', 'PickableParts', 'none');
            % hollow SUSPECTED marks sized by model score
            ev = S.events;
            if isempty(ev)
                lat = zeros(0, 1); lon = zeros(0, 1); sz = 80;
            else
                lat = double([ev.lat])'; lon = double([ev.lon])';
                sc = double([ev.model_score])'; sc(~isfinite(sc)) = 0;
                sz = 40 + 200 * min(max(sc, 0), 1);
            end
            obj.SuspectedMarks = geoscatter(gx, lat, lon, sz, [1.00 0.55 0.10], 'o', 'MarkerFaceColor', 'none', ...
                'MarkerEdgeColor', [1.00 0.55 0.10], 'LineWidth', 1.5, 'DisplayName', 'SUSPECTED anomaly (SIMULATION)', ...
                'Tag', 'SIMULATION suspected', 'PickableParts', 'none');
            obj.drawSynthetic();
            obj.restack(); obj.updateLegend();
        end

        function drawSynthetic(obj)
            obj.deleteLayers({'SyntheticTargets'});
            E = obj.Evaluation;
            if ~obj.isOpen() || ~obj.EvaluationVisible || isempty(E) || ~isfield(E, 'truth_ll'), return; end
            [lat, lon, matched] = mgv22.field.FieldSurveyView.truthVectors(E.truth_ll);
            rgb = repmat([1.00 0.20 0.85], numel(lat), 1);
            rgb(matched, :) = repmat([0.20 0.95 0.30], nnz(matched), 1);
            if isempty(lat), rgb = [0.20 0.95 0.30]; end
            obj.SyntheticTargets = geoscatter(obj.Axes, lat, lon, 110, rgb, 's', 'MarkerFaceColor', 'none', ...
                'MarkerEdgeColor', 'flat', 'LineWidth', 1.5, 'DisplayName', 'SYNTHETIC target (evaluation only)', ...
                'Tag', 'evaluation only synthetic', 'PickableParts', 'none');
            obj.restack();
        end

        function updateLegend(obj)
            if ~obj.isOpen(), return; end
            hs = {obj.FieldLine, obj.RouteLine, obj.HomeMarker, obj.CoverageLayer, obj.SuspectedMarks, obj.SyntheticTargets};
            h = gobjects(0);
            for k = 1:numel(hs)
                if ~isempty(hs{k}) && isgraphics(hs{k}), h(end + 1) = hs{k}; end %#ok<AGROW>
            end
            if any(isgraphics(obj.MapLegend)), delete(obj.MapLegend); end
            obj.MapLegend = gobjects(0);
            if isempty(h), return; end
            try
                obj.MapLegend = legend(obj.Axes, h, 'Location', 'southwest', 'TextColor', obj.Colours.text, ...
                    'Color', obj.Colours.panel, 'FontSize', 9);
            catch
                % legend is cosmetic
            end
        end

        function drawDraft(obj)
            if ~obj.isOpen(), return; end
            obj.removeDraftGraphics();
            if isempty(obj.DraftLL), return; end
            ll = obj.DraftLL;
            obj.DraftLine = geoplot(obj.Axes, ll(:, 1), ll(:, 2), '--o', 'Color', [1 1 1], 'LineWidth', 1.5, ...
                'MarkerSize', 4, 'MarkerFaceColor', [1 1 1], 'DisplayName', 'Draft field (VIRTUAL)', ...
                'Tag', 'VIRTUAL draft', 'PickableParts', 'none');
            h = gobjects(size(ll, 1), 1);
            for k = 1:size(ll, 1)
                h(k) = text(obj.Axes, ll(k, 1), ll(k, 2), sprintf(' %d', k), 'Color', [1 1 1], 'FontWeight', 'bold', ...
                    'FontSize', 11, 'BackgroundColor', [0 0 0], 'Margin', 1, 'Tag', 'VIRTUAL draft vertex', 'PickableParts', 'none');
            end
            obj.DraftLabels = h;
            obj.restack();
        end

        function removeDraftGraphics(obj)
            h = [obj.DraftLine(:); obj.DraftLabels(:)]; h = h(isgraphics(h));
            if ~isempty(h), delete(h); end
            obj.DraftLine = gobjects(0); obj.DraftLabels = gobjects(0);
        end

        function removeDraft(obj)
            obj.removeDraftGraphics();
            obj.DraftLL = zeros(0, 2);
        end

        function endDraw(obj)
            obj.removeDraft();
            obj.Drawing = false;
            if obj.isOpen()
                set([obj.UndoButton obj.CancelButton obj.FinishButton], 'Enable', 'off');
                obj.Axes.ButtonDownFcn = '';                          % a click handler would block drag-to-pan and scroll zoom
                try enableDefaultInteractivity(obj.Axes); catch, end
            end
        end

        function onAxesClick(obj)
            if ~obj.Drawing || ~obj.isOpen(), return; end
            if strcmp(obj.Figure.SelectionType, 'open')
                % the first click of a double-click already added the point
                obj.guarded(@() obj.finishDraw());
                return
            end
            cp = obj.Axes.CurrentPoint;
            lat = cp(1, 1); lon = cp(1, 2);
            if ~isfinite(lat) || ~isfinite(lon), return; end
            obj.guarded(@() obj.addVertex([lat lon]));
        end

        function onHullChanged(obj)
            % re-plan the last drawn field when the operator confirms (or withdraws) the convex hull
            if size(obj.FieldLL, 1) >= 3 && ~obj.Running
                obj.plan(obj.FieldLL);
            end
        end

        function onProgress(obj, t, T)
            if ~obj.isOpen(), return; end
            if T > 0, pct = 100 * t / T; else, pct = 0; end
            obj.ProgressLabel.Text = sprintf('Simulated flight: tick %d of %d (%.0f %%)', round(t), round(T), pct);
            drawnow limitrate;
        end

        function restack(obj)
            if ~obj.isOpen(), return; end
            try
                gx = obj.Axes; kids = gx.Children;
                if isempty(kids), return; end
                order = {obj.DraftLabels, obj.DraftLine, obj.SyntheticTargets, obj.SuspectedMarks, obj.HomeMarker, ...
                    obj.RouteLine, obj.FieldLine, obj.CoverageLayer};
                front = gobjects(0, 1);
                for k = 1:numel(order)
                    h = order{k}(:); h = h(isgraphics(h));
                    front = [front; h]; %#ok<AGROW>
                end
                inFront = false(numel(kids), 1);
                for k = 1:numel(kids), inFront(k) = any(kids(k) == front); end
                keep = false(numel(front), 1);
                for k = 1:numel(front), keep(k) = any(front(k) == kids); end
                gx.Children = [front(keep); kids(~inFront)];
            catch
                % stacking is cosmetic; never fail a redraw over it
            end
        end

        function s = markerSize(obj)
            % Square marker side ~ one coverage cell on screen (see mgv22.cutfill.CutFillView.markerSize).
            s = 16;
            if ~obj.isOpen(), return; end
            try
                gx = obj.Axes; la = gx.LatitudeLimits; lo = gx.LongitudeLimits;
                pos = getpixelposition(gx);
                w = max(pos(3), 1); h = max(pos(4), 1);
                latM = diff(la) * 111320; lonM = diff(lo) * 111320 * cosd(mean(la));
                mpp = max(latM / h, lonM / w);
                sidePt = 1.1 * double(obj.CellM) / mpp * 72 / 96;
                s = min(max(sidePt ^ 2, 1), 2500);
            catch
            end
        end

        function updateMarkerSize(obj)
            if obj.isOpen() && any(isgraphics(obj.CoverageLayer))
                obj.CoverageLayer.SizeData = obj.markerSize();
            end
        end

        function zoomToField(obj)
            poly = obj.Plan.poly_ll;
            span = max(max(poly) - min(poly));
            pad = max(0.25 * span, 15 / 111320);
            lo = min(poly) - pad; hi = max(poly) + pad;
            geolimits(obj.Axes, [lo(1) hi(1)], [lo(2) hi(2)]);
            drawnow limitrate;
            obj.updateMarkerSize();
        end

        function deleteLayers(obj, names)
            for k = 1:numel(names)
                h = obj.(names{k});
                h = h(isgraphics(h));
                if ~isempty(h), delete(h); end
                obj.(names{k}) = gobjects(0);
            end
        end

        function showStatus(obj, msg, isError)
            if ~obj.isOpen() || ~isgraphics(obj.StatusText), return; end
            obj.StatusText.Text = char(msg);
            if isError, obj.StatusText.FontColor = obj.Colours.error; else, obj.StatusText.FontColor = obj.Colours.warn; end
        end

        function guarded(obj, fn)
            % UI callbacks: errors go to StatusText (most methods already wrote a message there)
            try
                fn();
            catch err
                if obj.isOpen() && ~startsWith(string(obj.StatusText.Text), ["Field rejected", "Simulated survey failed"])
                    obj.showStatus(string(err.message), true);
                end
            end
        end

        function resetHandles(obj)
            e = gobjects(0);
            [obj.Figure, obj.Axes, obj.Banner, obj.Credits, obj.StatusLabel, obj.Link, obj.Watermark, obj.MapLegend] = deal(e);
            [obj.DrawButton, obj.UndoButton, obj.CancelButton, obj.FinishButton, obj.StatusText] = deal(e);
            [obj.AreaLabel, obj.AltitudeLabel, obj.GsdLabel, obj.PixelsLabel, obj.SpacingLabel, obj.SpeedLabel] = deal(e);
            [obj.LinesLabel, obj.TimeLabel, obj.TargetsField, obj.SeedField, obj.AllowHullCheck, obj.RunButton] = deal(e);
            [obj.ProgressLabel, obj.SuspectedLabel, obj.CoverageLabel, obj.DetectionLabel, obj.FalseAlarmLabel] = deal(e);
            [obj.EvaluationCheck, obj.WordingLabel] = deal(e);
            [obj.FieldLine, obj.RouteLine, obj.HomeMarker, obj.CoverageLayer, obj.SuspectedMarks, obj.SyntheticTargets] = deal(e);
            [obj.DraftLine, obj.DraftLabels] = deal(e);
        end
    end

    methods (Static, Access = private)
        function checkSite(s)
            id = 'mgv22:InvalidSiteConfig';
            if ~all(isfield(s, {'anchor_lla', 'view_window', 'banner', 'credit_text', 'service_url'}))
                error(id, 'Site must come from mgv22.siteConfig.');
            end
            a = s.anchor_lla; w = s.view_window;
            mgv22.geo.enuToWgs84([0 0 0], a);
            if ~(a(1) > w.lat(1) && a(1) < w.lat(2) && a(2) > w.lon(1) && a(2) < w.lon(2))
                error(id, 'The anchor must lie inside the view window.');
            end
        end

        function [lat, lon, matched] = truthVectors(T)
            % accepts a table, a struct array or a struct of column vectors
            if istable(T)
                lat = double(T.lat); lon = double(T.lon);
                if ismember('matched', T.Properties.VariableNames), matched = logical(T.matched); else, matched = false(size(lat)); end
            elseif isstruct(T) && isscalar(T)
                lat = double(T.lat(:)); lon = double(T.lon(:));
                if isfield(T, 'matched'), matched = logical(T.matched(:)); else, matched = false(size(lat)); end
            elseif isstruct(T) && ~isempty(T)
                lat = double([T.lat])'; lon = double([T.lon])';
                if isfield(T, 'matched'), matched = logical([T.matched])'; else, matched = false(size(lat)); end
            else
                lat = zeros(0, 1); lon = zeros(0, 1); matched = false(0, 1);
            end
            lat = lat(:); lon = lon(:); matched = matched(:);
            if numel(matched) ~= numel(lat), matched = false(size(lat)); end
        end

        function c = colours(name)
            if name == "dark"
                c = struct('bg', [0.08 0.10 0.13], 'panel', [0.11 0.13 0.17], 'text', [0.93 0.96 0.98], ...
                    'banner', [0.45 0.08 0.08], 'warn', [1 0.82 0.45], 'link', [0.46 0.86 1.00], 'offline', [0.42 0.30 0.02], ...
                    'error', [1.00 0.55 0.55]);
            else
                c = struct('bg', [0.97 0.97 0.98], 'panel', [0.93 0.94 0.96], 'text', [0.10 0.13 0.17], ...
                    'banner', [0.98 0.86 0.86], 'warn', [0.62 0.36 0.00], 'link', [0.05 0.35 0.75], 'offline', [1.00 0.90 0.62], ...
                    'error', [0.75 0.05 0.05]);
            end
        end
    end
end
