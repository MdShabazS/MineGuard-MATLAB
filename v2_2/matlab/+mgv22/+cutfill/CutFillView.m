classdef CutFillView < handle
    %CUTFILLVIEW Reel-style cut/fill map over the BITM satellite view (V22-T9). SIMULATED TERRAIN only.
    %   v = mgv22.cutfill.CutFillView(S)
    %   v = mgv22.cutfill.CutFillView(S, Site=mgv22.siteConfig(), MetadataReader=[], Theme="dark", Visible="on")
    %   S is a gridded SIMULATED survey surface (S.x, S.y, S.Z, S.cell_m, S.source, S.label) in ENU metres whose
    %   origin sits at Site.anchor_lla. It is NOT BITM's real ground; every panel value and map layer says so.
    %
    %   Methods: setOutline(polyENU), bestFit(), setSlope(pct), setHeading(deg), setOverlayVisible(tf),
    %   setAlpha(a), setContourInterval(m), setContoursVisible(existingTF, designTF), F = profile(p1, p2),
    %   startDraw("area"|"profile"), addVertex(xyENU), undoVertex(), cancelDraw(), finishDraw(),
    %   r = results(), close(), isOpen(), delete().
    %   The banner and credits follow mgv22.sat.SatellitePreview: credits sit in a footer OUTSIDE the map.
    %   Errors are shown in StatusText (never a blocking dialog); programmatic calls still throw afterwards.

    properties (SetAccess = private)
        Surface
        Site
        Theme = "dark"
        Label = "SIMULATED TERRAIN (not BITM ground)"
        Source = []
        % --- figure frame
        Figure
        Axes
        Banner
        Credits
        StatusLabel
        Link
        % --- left panel
        AreaLabel
        CutLabel
        FillLabel
        RatioLabel
        MaxLabel
        CutPerHaLabel
        BestFitButton
        SlopeField
        HeadingField
        ContourDropdown
        ExistingCheck
        DesignCheck
        OverlaySwitch
        AlphaSlider
        DrawAreaButton
        DrawProfileButton
        UndoButton
        CancelButton
        FinishButton
        StatusText
        ProfileAxes
        % --- map layers
        OutlineLine
        VertexLabels
        Overlay
        ExistingContours
        DesignContours
        LegendText
        ProfileLine
        SurveyAreaLine      % dashed outline of where SIMULATED survey data exists (draw inside it)
        DraftLine
        DraftLabels
        % --- state
        Outline = zeros(0, 2)
        Mask = []
        Plane = []
        BestPlane = []
        Results = []
        Profile = []
        DrawMode = ""
        DraftXY = zeros(0, 2)
        OverlayVisible = true
        Alpha = 0.7
        ContourInterval = 0.5
        ShowExisting = true
        ShowDesign = true
    end

    properties (Access = private)
        MetadataReader = []
        LatGrid = []
        LonGrid = []
        Centroid = [0 0]
        Z0 = 0
        Heading = 0
        ProfileEnds = []
        Colours
        Listeners = {}
        NanInside = 0
    end

    properties (Constant, Access = private)
        Intervals = [0.1 0.2 0.5 1]
        MaxLevels = 400
    end

    methods
        function obj = CutFillView(S, opts)
            arguments
                S struct
                opts.Site struct = mgv22.siteConfig()
                opts.MetadataReader = []
                opts.Theme (1,1) string {mustBeMember(opts.Theme, ["dark","light"])} = "dark"
                opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
            end
            mgv22.cutfill.CutFillView.checkSurface(S);
            mgv22.cutfill.CutFillView.checkSite(opts.Site);
            obj.Surface = S; obj.Site = opts.Site; obj.Theme = opts.Theme; obj.MetadataReader = opts.MetadataReader;
            lab = "SIMULATED TERRAIN (not BITM ground)";
            if isfield(S, 'label') && strlength(string(S.label)) > 0, lab = string(S.label); end
            if ~contains(upper(lab), "SIMULATED"), lab = lab + " (SIMULATED TERRAIN)"; end
            obj.Label = lab;
            obj.clearHandles();
            [X, Y] = meshgrid(double(S.x), double(S.y));
            ll = obj.toLatLon([X(:) Y(:)]);
            obj.LatGrid = reshape(ll(:, 1), size(X)); obj.LonGrid = reshape(ll(:, 2), size(X));
            obj.build(opts.Visible);
        end

        % ------------------------------------------------------------------ outline and plane
        function setOutline(obj, polyENU)
            try
                poly = mgv22.cutfill.validateOutline(polyENU);
                [mask, info] = mgv22.cutfill.clipToPolygon(obj.Surface, poly);
                P = mgv22.cutfill.fitPlane(obj.Surface, mask);
            catch err
                if err.identifier == "mgv22:TooFewCells"
                    obj.showStatus("Outline rejected: no simulated survey data inside it. Draw inside the dashed SIMULATED survey area.", true);
                else
                    obj.showStatus("Outline rejected: " + string(err.message), true);
                end
                rethrow(err);
            end
            obj.Outline = poly; obj.Mask = mask;
            [X, Y] = meshgrid(obj.Surface.x, obj.Surface.y);
            obj.Centroid = [mean(X(mask)) mean(Y(mask))];             % pivot slope/heading edits on the cells with data
            obj.NanInside = info.nan_cells_inside;
            obj.applyBestPlane(P);
            obj.zoomToOutline();
            obj.drawOutline();
            obj.recompute();
            obj.showStatus(sprintf('Field outline set: %d vertices, %d grid cells, %d cells without survey data excluded (SIMULATED TERRAIN).', ...
                size(poly, 1), nnz(mask), obj.NanInside), false);
        end

        function bestFit(obj)
            obj.requireOutline();
            try
                P = mgv22.cutfill.fitPlane(obj.Surface, obj.Mask);
            catch err
                obj.showStatus("Best fit failed: " + string(err.message), true);
                rethrow(err);
            end
            obj.applyBestPlane(P);
            obj.recompute();
            obj.showStatus(sprintf('Best-fit plane: slope %.2f %%, heading %.1f deg.', P.slope_pct, P.heading_deg), false);
        end

        function setSlope(obj, pct)
            obj.requireOutline();
            if ~(isnumeric(pct) && isscalar(pct) && isfinite(pct) && pct >= 0)
                obj.showStatus("Slope must be a finite number >= 0 %.", true);
                error('mgv22:InvalidSlope', 'Slope must be a finite number >= 0 %%.');
            end
            obj.setDesign(double(pct), obj.Heading);
        end

        function setHeading(obj, deg)
            obj.requireOutline();
            if ~(isnumeric(deg) && isscalar(deg) && isfinite(deg))
                obj.showStatus("Heading must be a finite number of degrees.", true);
                error('mgv22:InvalidHeading', 'Heading must be a finite number of degrees.');
            end
            obj.setDesign(obj.Plane.slope_pct, mod(double(deg), 360));
        end

        % ------------------------------------------------------------------ display options
        function setOverlayVisible(obj, tf)
            tf = logical(tf); obj.OverlayVisible = tf;
            if obj.isOpen()
                obj.OverlaySwitch.Value = tf;
                if any(isgraphics(obj.Overlay)), obj.Overlay.Visible = matlab.lang.OnOffSwitchState(tf); end
            end
        end

        function setAlpha(obj, a)
            if ~(isnumeric(a) && isscalar(a) && isfinite(a) && a >= 0 && a <= 1)
                obj.showStatus("Transparency must be between 0 and 1.", true);
                error('mgv22:InvalidAlpha', 'Alpha must be between 0 and 1.');
            end
            obj.Alpha = double(a);
            if obj.isOpen()
                obj.AlphaSlider.Value = obj.Alpha;
                if any(isgraphics(obj.Overlay)), obj.Overlay.MarkerFaceAlpha = obj.Alpha; end
            end
        end

        function setContourInterval(obj, m)
            if ~(isnumeric(m) && isscalar(m) && isfinite(m) && m > 0)
                obj.showStatus("Contour interval must be a positive number of metres.", true);
                error('mgv22:InvalidContourInterval', 'Contour interval must be positive.');
            end
            obj.ContourInterval = double(m);
            if obj.isOpen()
                hit = abs(obj.Intervals - obj.ContourInterval) < 1e-9;
                if any(hit), obj.ContourDropdown.Value = obj.ContourDropdown.Items{hit}; end
                obj.drawContours(); obj.restack();
            end
        end

        function setContoursVisible(obj, existingTF, designTF)
            obj.ShowExisting = logical(existingTF); obj.ShowDesign = logical(designTF);
            if ~obj.isOpen(), return; end
            obj.ExistingCheck.Value = obj.ShowExisting; obj.DesignCheck.Value = obj.ShowDesign;
            h = obj.ExistingContours(isgraphics(obj.ExistingContours));
            if ~isempty(h), set(h, 'Visible', matlab.lang.OnOffSwitchState(obj.ShowExisting)); end
            h = obj.DesignContours(isgraphics(obj.DesignContours));
            if ~isempty(h), set(h, 'Visible', matlab.lang.OnOffSwitchState(obj.ShowDesign)); end
        end

        % ------------------------------------------------------------------ profile
        function F = profile(obj, p1, p2)
            obj.requireOutline();
            p1 = double(p1(:)'); p2 = double(p2(:)');
            if numel(p1) ~= 2 || numel(p2) ~= 2 || any(~isfinite([p1 p2])) || isequal(p1, p2)
                obj.showStatus("Profile needs two different finite ENU points.", true);
                error('mgv22:InvalidProfile', 'Profile needs two different finite [east north] points.');
            end
            try
                F = mgv22.cutfill.profileLine(obj.Surface, obj.Plane, p1, p2, 200);
            catch err
                obj.showStatus("Profile failed: " + string(err.message), true);
                rethrow(err);
            end
            obj.Profile = F; obj.ProfileEnds = [p1; p2];
            if ~obj.isOpen(), return; end
            ax = obj.ProfileAxes; cla(ax);
            plot(ax, F.dist_m, F.existing_m, '-', 'Color', [0.80 0.55 0.25], 'LineWidth', 1.4, 'DisplayName', 'Existing (SIMULATED)');
            hold(ax, 'on');
            plot(ax, F.dist_m, F.design_m, '--', 'Color', [0.30 0.75 1.00], 'LineWidth', 1.4, 'DisplayName', 'Design (VIRTUAL plan)');
            hold(ax, 'off');
            xlabel(ax, 'Distance (m)'); ylabel(ax, 'Elevation (m)');
            title(ax, 'Profile (SIMULATED TERRAIN)', 'FontSize', 9);
            legend(ax, 'Location', 'best', 'FontSize', 7);
            if any(isgraphics(obj.ProfileLine)), delete(obj.ProfileLine); end
            ll = obj.toLatLon([p1; p2]);
            obj.ProfileLine = geoplot(obj.Axes, ll(:, 1), ll(:, 2), '-o', 'Color', [1 1 1], 'LineWidth', 2, ...
                'MarkerSize', 5, 'MarkerFaceColor', [1 1 1], 'DisplayName', 'Elevation profile line (VIRTUAL)', ...
                'Tag', 'VIRTUAL profile', 'PickableParts', 'none');
            obj.restack();
            obj.showStatus(sprintf('Profile drawn: %.1f m long (SIMULATED TERRAIN).', hypot(p2(1) - p1(1), p2(2) - p1(2))), false);
        end

        % ------------------------------------------------------------------ draw tool
        function startDraw(obj, mode)
            mode = string(mode);
            if ~isscalar(mode) || ~ismember(mode, ["area","profile"])
                obj.showStatus("Draw mode must be ""area"" or ""profile"".", true);
                error('mgv22:InvalidDrawMode', 'Draw mode must be "area" or "profile".');
            end
            if mode == "profile" && isempty(obj.Outline)
                obj.showStatus("Draw a field area first.", true);
                error('mgv22:NoOutline', 'Draw a field area first.');
            end
            obj.clearDraft();
            obj.DrawMode = mode; obj.DraftXY = zeros(0, 2);
            if obj.isOpen()
                set([obj.UndoButton obj.CancelButton obj.FinishButton], 'Enable', 'on');
                obj.Axes.ButtonDownFcn = @(~, ~) obj.onAxesClick();   % clicks add points only while drawing
                try disableDefaultInteractivity(obj.Axes); catch, end
            end
            if mode == "area"
                obj.showStatus("Click on the map to add outline points. Double-click or Finish to complete.", false);
            else
                obj.showStatus("Click two points for the profile line. Double-click or Finish to complete.", false);
            end
        end

        function addVertex(obj, xy)
            if obj.DrawMode == ""
                error('mgv22:NotDrawing', 'Press Draw field area or Draw elevation profile first.');
            end
            xy = double(xy(:)');
            if numel(xy) ~= 2 || any(~isfinite(xy))
                error('mgv22:InvalidVertex', 'A vertex is a finite [east north] point in metres.');
            end
            obj.DraftXY(end + 1, :) = xy;
            obj.drawDraft();
        end

        function undoVertex(obj)
            if obj.DrawMode == "" || isempty(obj.DraftXY), return; end
            obj.DraftXY(end, :) = [];
            obj.drawDraft();
        end

        function cancelDraw(obj)
            if obj.DrawMode == "", return; end
            obj.endDraw();
            obj.showStatus("Drawing cancelled.", false);
        end

        function finishDraw(obj)
            mode = obj.DrawMode; xy = obj.DraftXY;
            if mode == "", return; end
            if mode == "area"
                obj.setOutline(xy);          % keeps the draft (and draw mode) if the outline is rejected
                obj.endDraw();
            else
                if size(xy, 1) < 2
                    obj.showStatus("A profile needs at least two points.", true);
                    error('mgv22:InvalidProfile', 'A profile needs at least two points.');
                end
                obj.endDraw();
                obj.profile(xy(1, :), xy(end, :));
            end
        end

        % ------------------------------------------------------------------ results and life cycle
        function r = results(obj)
            r = struct('R', obj.Results, 'P', obj.Plane, 'best_fit', obj.BestPlane, 'outline', obj.Outline, ...
                'mask_cells', nnz(obj.Mask), 'nan_cells_inside', obj.NanInside, 'overlay_visible', obj.OverlayVisible, 'alpha', obj.Alpha, ...
                'contour_interval', obj.ContourInterval, 'existing_contours', obj.ShowExisting, ...
                'design_contours', obj.ShowDesign, 'profile', obj.Profile, 'label', obj.Label, ...
                'source', string(mgv22.cutfill.CutFillView.fieldOr(obj.Surface, 'source', "")));
        end

        function close(obj)
            for k = 1:numel(obj.Listeners)
                if isvalid(obj.Listeners{k}), delete(obj.Listeners{k}); end
            end
            obj.Listeners = {};
            if ~isempty(obj.Figure) && isvalid(obj.Figure), delete(obj.Figure); end
            obj.clearHandles();
            obj.DrawMode = ""; obj.DraftXY = zeros(0, 2);
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
            c = mgv22.cutfill.CutFillView.colours(obj.Theme); obj.Colours = c;
            fig = uifigure('Name', 'BITM cut/fill map (SIMULATED TERRAIN, not BITM ground)', ...
                'Position', [60 60 1320 860], 'Visible', 'off', 'Color', c.bg, 'AutoResizeChildren', 'off');
            try
                theme(fig, obj.Theme);
                g = uigridlayout(fig, [3 1], 'RowHeight', {48, '1x', 76}, 'ColumnWidth', {'1x'}, ...
                    'Padding', [8 8 8 8], 'RowSpacing', 6, 'BackgroundColor', c.bg);
                if obj.Source.metadata_status == "UNAVAILABLE"
                    bannerText = "SATELLITE UNAVAILABLE — no connection to the imagery service; the map may be blank  |  " + obj.Label;
                    bannerColour = c.offline;
                else
                    bannerText = obj.Site.banner + " | " + obj.Label;
                    bannerColour = c.banner;
                end
                obj.Banner = uilabel(g, 'Text', bannerText, 'FontWeight', 'bold', 'FontSize', 13, 'FontColor', c.text, ...
                    'BackgroundColor', bannerColour, 'HorizontalAlignment', 'center', 'WordWrap', 'on');
                obj.Banner.Layout.Row = 1;

                mid = uigridlayout(g, [1 2], 'ColumnWidth', {290, '1x'}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
                    'ColumnSpacing', 8, 'BackgroundColor', c.bg);
                mid.Layout.Row = 2;
                obj.buildPanel(mid, c);

                gx = geoaxes(mid, 'Basemap', 'satellite');
                gx.Layout.Row = 1; gx.Layout.Column = 2; gx.AxisColor = c.text;
                hold(gx, 'on');
                obj.drawSurveyArea(gx);          % shows where the simulated terrain exists and frames the map on it
                obj.Axes = gx;
                try
                    gx.Colormap = mgv22.cutfill.CutFillView.diverging(256);
                catch
                end

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
                obj.updateLegend();
                fig.Visible = char(visible);
                drawnow limitrate;
                obj.updateMarkerSize();
            catch err
                if isvalid(fig), delete(fig); end
                obj.clearHandles();
                rethrow(err);
            end
        end

        function buildPanel(obj, parent, c)
            p = uigridlayout(parent, [17 2], 'ColumnWidth', {96, '1x'}, 'Padding', [6 6 6 6], 'RowSpacing', 5, ...
                'ColumnSpacing', 6, 'Scrollable', 'on', 'BackgroundColor', c.panel);
            p.Layout.Row = 1; p.Layout.Column = 1;
            p.RowHeight = {22, 20, 20, 20, 20, 20, 20, 28, 24, 24, 24, 22, 34, 28, 28, 54, 180};
            t = uilabel(p, 'Text', 'Cut / fill — SIMULATED TERRAIN', 'FontWeight', 'bold', 'FontColor', c.text);
            t.Layout.Row = 1; t.Layout.Column = [1 2];
            names = ["Field area", "Cut", "Fill", "Ratio", "Max depth", "Cut per ha"];
            vals = gobjects(1, 6);
            colours = {c.text, c.cut, c.fill, c.text, c.text, c.text};
            for k = 1:6
                l = uilabel(p, 'Text', names(k), 'FontColor', c.text); l.Layout.Row = k + 1; l.Layout.Column = 1;
                vals(k) = uilabel(p, 'Text', '—', 'FontColor', colours{k}, 'FontWeight', 'bold');
                vals(k).Layout.Row = k + 1; vals(k).Layout.Column = 2;
            end
            [obj.AreaLabel, obj.CutLabel, obj.FillLabel, obj.RatioLabel, obj.MaxLabel, obj.CutPerHaLabel] = ...
                deal(vals(1), vals(2), vals(3), vals(4), vals(5), vals(6));

            obj.BestFitButton = uibutton(p, 'Text', 'Best fit', 'ButtonPushedFcn', @(~, ~) obj.safeCall(@() obj.bestFit()));
            obj.BestFitButton.Layout.Row = 8; obj.BestFitButton.Layout.Column = [1 2];

            l = uilabel(p, 'Text', 'Slope %', 'FontColor', c.text); l.Layout.Row = 9; l.Layout.Column = 1;
            obj.SlopeField = uieditfield(p, 'numeric', 'Value', 0, 'Limits', [0 Inf], 'ValueDisplayFormat', '%.2f', ...
                'ValueChangedFcn', @(s, ~) obj.safeCall(@() obj.setSlope(s.Value)));
            obj.SlopeField.Layout.Row = 9; obj.SlopeField.Layout.Column = 2;
            l = uilabel(p, 'Text', 'Heading °', 'FontColor', c.text); l.Layout.Row = 10; l.Layout.Column = 1;
            obj.HeadingField = uieditfield(p, 'numeric', 'Value', 0, 'Limits', [0 360], 'ValueDisplayFormat', '%.1f', ...
                'ValueChangedFcn', @(s, ~) obj.safeCall(@() obj.setHeading(s.Value)));
            obj.HeadingField.Layout.Row = 10; obj.HeadingField.Layout.Column = 2;

            l = uilabel(p, 'Text', 'Contours (m)', 'FontColor', c.text); l.Layout.Row = 11; l.Layout.Column = 1;
            obj.ContourDropdown = uidropdown(p, 'Items', {'0.1', '0.2', '0.5', '1'}, 'Value', '0.5', ...
                'ValueChangedFcn', @(s, ~) obj.safeCall(@() obj.setContourInterval(str2double(s.Value))));
            obj.ContourDropdown.Layout.Row = 11; obj.ContourDropdown.Layout.Column = 2;
            obj.ExistingCheck = uicheckbox(p, 'Text', 'Existing', 'Value', obj.ShowExisting, 'FontColor', c.text, ...
                'ValueChangedFcn', @(~, ~) obj.safeCall(@() obj.setContoursVisible(obj.ExistingCheck.Value, obj.DesignCheck.Value)));
            obj.ExistingCheck.Layout.Row = 12; obj.ExistingCheck.Layout.Column = 1;
            obj.DesignCheck = uicheckbox(p, 'Text', 'Design', 'Value', obj.ShowDesign, 'FontColor', c.text, ...
                'ValueChangedFcn', @(~, ~) obj.safeCall(@() obj.setContoursVisible(obj.ExistingCheck.Value, obj.DesignCheck.Value)));
            obj.DesignCheck.Layout.Row = 12; obj.DesignCheck.Layout.Column = 2;

            obj.OverlaySwitch = uicheckbox(p, 'Text', 'Cut/Fill', 'Value', obj.OverlayVisible, 'FontColor', c.text, ...
                'ValueChangedFcn', @(s, ~) obj.safeCall(@() obj.setOverlayVisible(s.Value)));
            obj.OverlaySwitch.Layout.Row = 13; obj.OverlaySwitch.Layout.Column = 1;
            obj.AlphaSlider = uislider(p, 'Limits', [0 1], 'Value', obj.Alpha, 'MajorTicks', [0 0.5 1], 'MinorTicks', [], ...
                'FontColor', c.text, 'ValueChangedFcn', @(s, ~) obj.safeCall(@() obj.setAlpha(s.Value)));
            obj.AlphaSlider.Layout.Row = 13; obj.AlphaSlider.Layout.Column = 2;

            obj.DrawAreaButton = uibutton(p, 'Text', 'Draw field area', 'ButtonPushedFcn', @(~, ~) obj.safeCall(@() obj.startDraw("area")));
            obj.DrawAreaButton.Layout.Row = 14; obj.DrawAreaButton.Layout.Column = 1;
            obj.DrawProfileButton = uibutton(p, 'Text', 'Draw elevation profile', 'ButtonPushedFcn', @(~, ~) obj.safeCall(@() obj.startDraw("profile")));
            obj.DrawProfileButton.Layout.Row = 14; obj.DrawProfileButton.Layout.Column = 2;

            b = uigridlayout(p, [1 3], 'ColumnWidth', {'1x', '1x', '1x'}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4, 'BackgroundColor', c.panel);
            b.Layout.Row = 15; b.Layout.Column = [1 2];
            obj.UndoButton = uibutton(b, 'Text', 'Undo', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.safeCall(@() obj.undoVertex()));
            obj.CancelButton = uibutton(b, 'Text', 'Cancel', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.safeCall(@() obj.cancelDraw()));
            obj.FinishButton = uibutton(b, 'Text', 'Finish', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) obj.safeCall(@() obj.finishDraw()));

            obj.StatusText = uilabel(p, 'Text', 'Draw a field area over the SIMULATED TERRAIN.', 'WordWrap', 'on', ...
                'FontSize', 11, 'FontColor', c.warn, 'VerticalAlignment', 'top');
            obj.StatusText.Layout.Row = 16; obj.StatusText.Layout.Column = [1 2];

            obj.ProfileAxes = uiaxes(p);
            obj.ProfileAxes.Layout.Row = 17; obj.ProfileAxes.Layout.Column = [1 2];
            obj.ProfileAxes.FontSize = 8;
            title(obj.ProfileAxes, 'Profile (SIMULATED TERRAIN)', 'FontSize', 9);
            xlabel(obj.ProfileAxes, 'Distance (m)'); ylabel(obj.ProfileAxes, 'Elevation (m)');
        end

        % ------------------------------------------------------------------ computation
        function applyBestPlane(obj, P)
            obj.BestPlane = P; obj.Plane = P; obj.Heading = mod(P.heading_deg, 360);
            cx = obj.Centroid(1); cy = obj.Centroid(2);
            obj.Z0 = P.a + P.b * cx + P.c * cy;
            obj.syncFields();
        end

        function setDesign(obj, slopePct, headingDeg)
            try
                P = mgv22.cutfill.planeFromSlope(obj.Z0, obj.Centroid(1), obj.Centroid(2), slopePct, headingDeg);
            catch err
                obj.showStatus("Design plane rejected: " + string(err.message), true);
                rethrow(err);
            end
            obj.Plane = P; obj.Heading = mod(headingDeg, 360);
            obj.syncFields();
            obj.recompute();
            obj.showStatus(sprintf('Design plane: slope %.2f %%, heading %.1f deg (VIRTUAL plan).', slopePct, obj.Heading), false);
        end

        function recompute(obj)
            obj.Results = mgv22.cutfill.volumes(obj.Surface, obj.Mask, obj.Plane);
            if ~obj.isOpen(), return; end
            obj.updatePanel();
            obj.drawOverlay();
            obj.drawContours();
            obj.updateLegend();
            if ~isempty(obj.ProfileEnds)
                try
                    obj.Profile = mgv22.cutfill.profileLine(obj.Surface, obj.Plane, obj.ProfileEnds(1, :), obj.ProfileEnds(2, :), 200);
                    obj.replotProfile();
                catch
                end
            end
            obj.restack();
        end

        function requireOutline(obj)
            if isempty(obj.Outline) || isempty(obj.Plane)
                obj.showStatus("Draw a field area first.", true);
                error('mgv22:NoOutline', 'Draw a field area first.');
            end
        end

        % ------------------------------------------------------------------ drawing
        function syncFields(obj)
            if ~obj.isOpen() || isempty(obj.Plane), return; end
            obj.SlopeField.Value = max(0, obj.Plane.slope_pct);
            obj.HeadingField.Value = min(max(obj.Heading, 0), 360);
        end

        function updatePanel(obj)
            if ~obj.isOpen(), return; end
            R = obj.Results;
            if isempty(R)
                obj.AreaLabel.Text = 'Draw a field area';
                set([obj.CutLabel obj.FillLabel obj.RatioLabel obj.MaxLabel obj.CutPerHaLabel], 'Text', '—');
                return
            end
            obj.AreaLabel.Text = sprintf('%.0f m² (%.3f ha)', R.area_m2, R.area_ha);
            obj.CutLabel.Text = sprintf('%.1f m³', R.cut_m3);
            obj.FillLabel.Text = sprintf('%.1f m³', R.fill_m3);
            if isinf(R.ratio)
                obj.RatioLabel.Text = 'no fill';
            elseif isnan(R.ratio)
                obj.RatioLabel.Text = '—';
            else
                obj.RatioLabel.Text = sprintf('cut:fill %.2f', R.ratio);
            end
            obj.MaxLabel.Text = sprintf('cut %.2f / fill %.2f m', R.max_cut_m, R.max_fill_m);
            obj.CutPerHaLabel.Text = sprintf('%.1f m³/ha', R.cut_per_ha);
        end

        function updateLegend(obj)
            if ~obj.isOpen(), return; end
            if isempty(obj.Results)
                str = "Draw a field area · SIMULATED TERRAIN";
            else
                str = sprintf('Cut %.1f · Fill %.1f m³ · SIMULATED TERRAIN', obj.Results.cut_m3, obj.Results.fill_m3);
            end
            % the axes title stays in view whatever the user pans or zooms to
            obj.LegendText = title(obj.Axes, str, 'FontSize', 12, 'FontWeight', 'bold', 'Color', obj.Colours.text);
        end

        function drawOutline(obj)
            if ~obj.isOpen(), return; end
            if any(isgraphics(obj.OutlineLine)), delete(obj.OutlineLine); end
            v = obj.VertexLabels(isgraphics(obj.VertexLabels)); if ~isempty(v), delete(v); end
            poly = obj.Outline;
            ll = obj.toLatLon([poly; poly(1, :)]);
            obj.OutlineLine = geoplot(obj.Axes, ll(:, 1), ll(:, 2), '-', 'Color', [1 0.85 0.10], 'LineWidth', 2, ...
                'DisplayName', 'Field outline (VIRTUAL survey area)', 'Tag', 'VIRTUAL outline', 'PickableParts', 'none');
            obj.VertexLabels = obj.numberLabels(ll(1:end - 1, :), [1 0.85 0.10], 'VIRTUAL outline vertex');
        end

        function h = numberLabels(obj, ll, colour, tag)
            h = gobjects(size(ll, 1), 1);
            for k = 1:size(ll, 1)
                h(k) = text(obj.Axes, ll(k, 1), ll(k, 2), sprintf(' %d', k), 'Color', colour, 'FontWeight', 'bold', ...
                    'FontSize', 11, 'BackgroundColor', [0 0 0], 'Margin', 1, 'Tag', tag, 'PickableParts', 'none');
            end
        end

        function drawOverlay(obj)
            if any(isgraphics(obj.Overlay)), delete(obj.Overlay); end
            obj.Overlay = gobjects(0);
            R = obj.Results;
            if isempty(R), return; end
            D = R.D;
            idx = find(obj.Mask & isfinite(D));
            if isempty(idx), return; end
            d = D(idx);
            m = max(abs(d)); if ~(m > 0), m = 0.01; end
            gx = obj.Axes;
            obj.Overlay = geoscatter(gx, obj.LatGrid(idx), obj.LonGrid(idx), obj.markerSize(), d, 's', 'filled', ...
                'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', obj.Alpha, ...
                'DisplayName', 'Cut/fill depth (SIMULATED TERRAIN)', 'Tag', 'SIMULATED cut/fill', 'PickableParts', 'none');
            try
                gx.Colormap = mgv22.cutfill.CutFillView.diverging(256);
                gx.CLim = [-m m];
            catch
                % no colour mapping on this axes: fall back to explicit RGB with the same diverging scale
                obj.Overlay.CData = mgv22.cutfill.CutFillView.rgbFor(d, m);
            end
            obj.Overlay.Visible = matlab.lang.OnOffSwitchState(obj.OverlayVisible);
        end

        function drawContours(obj)
            if ~obj.isOpen(), return; end
            h = [obj.ExistingContours(:); obj.DesignContours(:)]; h = h(isgraphics(h));
            if ~isempty(h), delete(h); end
            obj.ExistingContours = gobjects(0); obj.DesignContours = gobjects(0);
            if isempty(obj.Mask) || isempty(obj.Plane), return; end
            S = obj.Surface; [X, Y] = meshgrid(double(S.x), double(S.y));
            Ze = S.Z; Ze(~obj.Mask) = NaN;
            Zd = obj.Plane.a + obj.Plane.b * X + obj.Plane.c * Y; Zd(~obj.Mask) = NaN;
            obj.ExistingContours = obj.contourLines(Ze, [0.95 0.75 0.35], '-', 'Existing contours (SIMULATED)', obj.ShowExisting);
            obj.DesignContours = obj.contourLines(Zd, [0.35 0.85 1.00], '--', 'Design contours (VIRTUAL plan)', obj.ShowDesign);
        end

        function h = contourLines(obj, Z, colour, style, name, show)
            h = gobjects(0);
            S = obj.Surface;
            v = Z(isfinite(Z));
            if numel(v) < 4 || numel(S.x) < 2 || numel(S.y) < 2, return; end
            iv = obj.ContourInterval;
            levels = (ceil(min(v) / iv):floor(max(v) / iv)) * iv;
            if isempty(levels), return; end
            if numel(levels) > obj.MaxLevels
                levels = levels(1:ceil(numel(levels) / obj.MaxLevels):end);
            end
            if isscalar(levels), lv = [levels levels]; else, lv = levels; end
            C = contourc(double(S.x), double(S.y), Z, lv);
            segLevel = []; segXY = {};
            k = 1;
            while k <= size(C, 2)
                n = C(2, k);
                segLevel(end + 1) = C(1, k); %#ok<AGROW>
                segXY{end + 1} = C(:, k + 1:k + n)'; %#ok<AGROW>
                k = k + n + 1;
            end
            if isempty(segLevel), return; end
            u = unique(segLevel);
            h = gobjects(numel(u), 1);
            for j = 1:numel(u)
                parts = segXY(segLevel == u(j));
                xy = zeros(0, 2);
                for q = 1:numel(parts), xy = [xy; parts{q}; NaN NaN]; end %#ok<AGROW>
                ll = obj.toLatLon(xy);
                h(j) = geoplot(obj.Axes, ll(:, 1), ll(:, 2), style, 'Color', colour, 'LineWidth', 0.8, ...
                    'DisplayName', name, 'Tag', sprintf('%s %.2f m', name, u(j)), 'PickableParts', 'none', ...
                    'Visible', matlab.lang.OnOffSwitchState(show));
            end
        end

        function replotProfile(obj)
            F = obj.Profile; ax = obj.ProfileAxes;
            if isempty(F) || ~isgraphics(ax), return; end
            cla(ax);
            plot(ax, F.dist_m, F.existing_m, '-', 'Color', [0.80 0.55 0.25], 'LineWidth', 1.4, 'DisplayName', 'Existing (SIMULATED)');
            hold(ax, 'on');
            plot(ax, F.dist_m, F.design_m, '--', 'Color', [0.30 0.75 1.00], 'LineWidth', 1.4, 'DisplayName', 'Design (VIRTUAL plan)');
            hold(ax, 'off');
            legend(ax, 'Location', 'best', 'FontSize', 7);
        end

        function drawDraft(obj)
            if ~obj.isOpen(), return; end
            obj.clearDraftGraphics();
            if isempty(obj.DraftXY), return; end
            ll = obj.toLatLon(obj.DraftXY);
            if obj.DrawMode == "area", name = 'Draft outline (VIRTUAL)'; else, name = 'Draft profile (VIRTUAL)'; end
            obj.DraftLine = geoplot(obj.Axes, ll(:, 1), ll(:, 2), '--o', 'Color', [1 1 1], 'LineWidth', 1.5, ...
                'MarkerSize', 4, 'MarkerFaceColor', [1 1 1], 'DisplayName', name, 'Tag', 'VIRTUAL draft', 'PickableParts', 'none');
            obj.DraftLabels = obj.numberLabels(ll, [1 1 1], 'VIRTUAL draft vertex');
            obj.restack();
        end

        function clearDraftGraphics(obj)
            h = [obj.DraftLine(:); obj.DraftLabels(:)]; h = h(isgraphics(h));
            if ~isempty(h), delete(h); end
            obj.DraftLine = gobjects(0); obj.DraftLabels = gobjects(0);
        end

        function clearDraft(obj)
            obj.clearDraftGraphics();
            obj.DraftXY = zeros(0, 2);
        end

        function endDraw(obj)
            obj.clearDraft();
            obj.DrawMode = "";
            if obj.isOpen()
                set([obj.UndoButton obj.CancelButton obj.FinishButton], 'Enable', 'off');
                obj.Axes.ButtonDownFcn = '';                          % a click handler would block drag-to-pan and scroll zoom
                try enableDefaultInteractivity(obj.Axes); catch, end
            end
        end

        function onAxesClick(obj)
            if obj.DrawMode == "" || ~obj.isOpen(), return; end
            if strcmp(obj.Figure.SelectionType, 'open')
                % the first click of a double-click already added the point
                obj.safeCall(@() obj.finishDraw());
                return
            end
            cp = obj.Axes.CurrentPoint;
            lat = cp(1, 1); lon = cp(1, 2);
            if ~isfinite(lat) || ~isfinite(lon), return; end
            obj.safeCall(@() obj.addVertex(obj.toEnu(lat, lon)));
        end

        function restack(obj)
            if ~obj.isOpen(), return; end
            try
                gx = obj.Axes; kids = gx.Children;
                if isempty(kids), return; end
                order = {obj.LegendText, obj.DraftLabels, obj.DraftLine, obj.ProfileLine, obj.VertexLabels, ...
                    obj.OutlineLine, obj.DesignContours, obj.ExistingContours, obj.Overlay};
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
            % Square marker side ~ one grid cell on screen: metres per pixel from the shown limits and the axes size,
            % uifigure pixels are 1/96 in and marker sizes are points (1/72 in) squared. 10% overlap avoids gaps.
            s = 4;
            if ~obj.isOpen(), return; end
            try
                gx = obj.Axes; la = gx.LatitudeLimits; lo = gx.LongitudeLimits;
                pos = getpixelposition(gx);
                w = max(pos(3), 1); h = max(pos(4), 1);
                latM = diff(la) * 111320; lonM = diff(lo) * 111320 * cosd(mean(la));
                mpp = max(latM / h, lonM / w);
                sidePt = 1.25 * double(obj.Surface.cell_m) / mpp * 72 / 96;
                s = min(max(sidePt ^ 2, 1), 2500);
            catch
            end
        end

        function drawSurveyArea(obj, gx)
            % Rectangle around the cells that have simulated LiDAR data; the map opens framed on it.
            S = obj.Surface; ok = ~isnan(S.Z);
            cols = find(any(ok, 1)); rows = find(any(ok, 2));
            h = S.cell_m / 2;
            x = [S.x(cols(1)) - h, S.x(cols(end)) + h]; y = [S.y(rows(1)) - h, S.y(rows(end)) + h];
            ll = obj.toLatLon([x(1) y(1); x(2) y(1); x(2) y(2); x(1) y(2); x(1) y(1)]);
            obj.SurveyAreaLine = geoplot(gx, ll(:, 1), ll(:, 2), '--', 'Color', [1 1 1], 'LineWidth', 1.5, ...
                'DisplayName', 'SIMULATED survey area (draw inside)', 'PickableParts', 'none');
            pad = 0.35 * max(diff(x), diff(y));
            c = obj.toLatLon([x(1) - pad y(1) - pad; x(2) + pad y(2) + pad]);
            geolimits(gx, sort(c(:, 1))', sort(c(:, 2))');
        end

        function zoomToOutline(obj)
            % Like the reference reel: frame the field so its cut/fill cells are readable (25 % padding, at least 15 m).
            pad = max(0.25 * max(max(obj.Outline) - min(obj.Outline)), 15);
            lo = min(obj.Outline) - pad; hi = max(obj.Outline) + pad;
            ll = obj.toLatLon([lo; hi]);
            geolimits(obj.Axes, sort(ll(:, 1))', sort(ll(:, 2))');
            drawnow;                         % finish the layout so the cells are sized from the real map size
        end

        function updateMarkerSize(obj)
            if obj.isOpen() && any(isgraphics(obj.Overlay))
                obj.Overlay.SizeData = obj.markerSize();
            end
        end

        function showStatus(obj, msg, isError)
            if ~obj.isOpen() || ~isgraphics(obj.StatusText), return; end
            obj.StatusText.Text = char(msg);
            if isError, obj.StatusText.FontColor = obj.Colours.error; else, obj.StatusText.FontColor = obj.Colours.warn; end
        end

        function safeCall(obj, fn)
            % UI callbacks: errors go to StatusText (most methods already wrote a clear message there)
            try
                fn();
            catch err
                if obj.isOpen() && ~startsWith(string(obj.StatusText.Text), ["Outline rejected", "Best fit failed", ...
                        "Design plane rejected", "Profile failed"])
                    obj.showStatus(string(err.message), true);
                end
            end
        end

        % ------------------------------------------------------------------ coordinates
        function ll = toLatLon(obj, xy)
            ll = nan(size(xy, 1), 2);
            ok = all(isfinite(xy), 2);
            if any(ok)
                lla = mgv22.geo.enuToWgs84([xy(ok, :) zeros(nnz(ok), 1)], obj.Site.anchor_lla);
                ll(ok, :) = lla(:, 1:2);
            end
        end

        function xy = toEnu(obj, lat, lon)
            enu = mgv22.geo.wgs84ToEnu([lat lon 0], obj.Site.anchor_lla);
            xy = enu(1, 1:2);
        end

        function clearHandles(obj)
            e = gobjects(0);
            [obj.Figure, obj.Axes, obj.Banner, obj.Credits, obj.StatusLabel, obj.Link] = deal(e);
            [obj.AreaLabel, obj.CutLabel, obj.FillLabel, obj.RatioLabel, obj.MaxLabel, obj.CutPerHaLabel] = deal(e);
            [obj.BestFitButton, obj.SlopeField, obj.HeadingField, obj.ContourDropdown, obj.ExistingCheck, obj.DesignCheck] = deal(e);
            [obj.OverlaySwitch, obj.AlphaSlider, obj.DrawAreaButton, obj.DrawProfileButton] = deal(e);
            [obj.UndoButton, obj.CancelButton, obj.FinishButton, obj.StatusText, obj.ProfileAxes] = deal(e);
            [obj.OutlineLine, obj.VertexLabels, obj.Overlay, obj.ExistingContours, obj.DesignContours] = deal(e);
            [obj.LegendText, obj.ProfileLine, obj.DraftLine, obj.DraftLabels, obj.SurveyAreaLine] = deal(e);
        end
    end

    methods (Static, Access = private)
        function checkSurface(S)
            id = 'mgv22:InvalidSurface';
            if ~all(isfield(S, {'x', 'y', 'Z', 'cell_m'}))
                error(id, 'Surface must have x, y, Z and cell_m.');
            end
            if ~isequal(size(S.Z), [numel(S.y) numel(S.x)]) || isempty(S.Z)
                error(id, 'Surface Z must be ny-by-nx matching y and x.');
            end
            if ~(isscalar(S.cell_m) && isfinite(S.cell_m) && S.cell_m > 0)
                error(id, 'cell_m must be a positive scalar.');
            end
        end

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

        function c = polyCentroid(poly)
            x = poly(:, 1); y = poly(:, 2);
            xn = circshift(x, -1); yn = circshift(y, -1);
            cr = x .* yn - xn .* y; A = sum(cr) / 2;
            if abs(A) < eps
                c = mean(poly, 1);
            else
                c = [sum((x + xn) .* cr), sum((y + yn) .* cr)] / (6 * A);
            end
        end

        function cmap = diverging(n)
            % low (negative depth = fill) blue -> white at 0 -> red high (positive depth = cut)
            h = floor(n / 2);
            blue = [0.13 0.40 0.80]; red = [0.80 0.13 0.13];
            t1 = linspace(0, 1, h)'; t2 = linspace(0, 1, n - h)';
            cmap = [blue + t1 .* (1 - blue); 1 - t2 .* (1 - red)];
        end

        function rgb = rgbFor(d, m)
            cmap = mgv22.cutfill.CutFillView.diverging(256);
            k = round((d(:) / m + 1) / 2 * 255) + 1;
            rgb = cmap(min(max(k, 1), 256), :);
        end

        function v = fieldOr(s, name, default)
            if isfield(s, name), v = s.(name); else, v = default; end
        end

        function c = colours(name)
            if name == "dark"
                c = struct('bg', [0.08 0.10 0.13], 'panel', [0.11 0.13 0.17], 'text', [0.93 0.96 0.98], ...
                    'banner', [0.45 0.08 0.08], 'warn', [1 0.82 0.45], 'link', [0.46 0.86 1.00], 'offline', [0.42 0.30 0.02], ...
                    'cut', [1.00 0.45 0.45], 'fill', [0.45 0.70 1.00], 'error', [1.00 0.55 0.55]);
            else
                c = struct('bg', [0.97 0.97 0.98], 'panel', [0.93 0.94 0.96], 'text', [0.10 0.13 0.17], ...
                    'banner', [0.98 0.86 0.86], 'warn', [0.62 0.36 0.00], 'link', [0.05 0.35 0.75], 'offline', [1.00 0.90 0.62], ...
                    'cut', [0.75 0.10 0.10], 'fill', [0.10 0.30 0.75], 'error', [0.75 0.05 0.05]);
            end
        end
    end
end
