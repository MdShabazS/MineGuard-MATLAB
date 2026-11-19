classdef SatellitePreview < handle
    %SATELLITEPREVIEW Standalone satellite view of the BITM site (V22-T4). Geographic CONTEXT only.
    %   p = mgv22.sat.SatellitePreview()                    BITM site file, satellite basemap, dark theme
    %   p = mgv22.sat.SatellitePreview(Theme="light", Basemap="darkwater", Site=s, MetadataReader=@fn)
    %   p.open() / p.open(Visible="off")   p.close()   s = p.status()   tf = p.isOpen()
    %   The banner and credits always come from the site file (v2_2/config/bitm_site.json); credits sit in a footer
    %   OUTSIDE the map so overlays can never cover them. Live tiles need internet and give no load signal, so the
    %   tile status stays UNVERIFIED; an unreachable service is reported as "Satellite unavailable".
    %   No mission, truth, target or event data is used here; the VIRTUAL route overlay is V22-T5.

    properties (SetAccess = private)
        Site
        Basemap = "satellite"
        Theme = "dark"
        Source = []          % struct from mgv22.sat.basemapSource at the last open
        Figure = []
        Axes = []
        Banner = []
        Credits = []
        StatusLabel = []
        Link = []
    end
    properties (Access = private)
        MetadataReader = []
    end

    methods
        function obj = SatellitePreview(opts)
            arguments
                opts.Site struct = mgv22.siteConfig()
                opts.Basemap (1,1) string {mustBeMember(opts.Basemap, ["satellite","topographic","streets-light","darkwater"])} = "satellite"
                opts.Theme (1,1) string {mustBeMember(opts.Theme, ["dark","light"])} = "dark"
                opts.MetadataReader = []
            end
            obj.Site = opts.Site; obj.Basemap = opts.Basemap; obj.Theme = opts.Theme; obj.MetadataReader = opts.MetadataReader;
        end

        function open(obj, opts)
            arguments
                obj
                opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
            end
            if obj.isOpen(), figure(obj.Figure); return; end
            obj.Source = mgv22.sat.basemapSource(obj.Basemap, obj.Site, obj.MetadataReader);
            c = mgv22.sat.SatellitePreview.colours(obj.Theme);
            fig = uifigure('Name', 'MineGuard V2.2 - BITM satellite view (SIMULATED FLIGHT CONTEXT)', ...
                'Position', [100 100 1040 760], 'Visible', 'off', 'Color', c.bg);
            try
                theme(fig, obj.Theme);
                g = uigridlayout(fig, [3 1], 'RowHeight', {48, '1x', 76}, 'ColumnWidth', {'1x'}, ...
                    'Padding', [8 8 8 8], 'RowSpacing', 6, 'BackgroundColor', c.bg);
                obj.Banner = uilabel(g, 'Text', obj.Site.banner + "  |  Geographic context only. Live satellite tiles need internet.", ...
                    'FontWeight', 'bold', 'FontSize', 13, 'FontColor', c.text, 'BackgroundColor', c.banner, ...
                    'HorizontalAlignment', 'center', 'WordWrap', 'on');
                obj.Banner.Layout.Row = 1;
                obj.Axes = geoaxes(g, 'Basemap', char(obj.Basemap));
                obj.Axes.Layout.Row = 2; obj.Axes.AxisColor = c.text;
                geolimits(obj.Axes, obj.Site.view_window.lat, obj.Site.view_window.lon);
                foot = uigridlayout(g, [3 1], 'RowHeight', {'1x', 18, 18}, 'Padding', [2 0 2 0], 'RowSpacing', 0, 'BackgroundColor', c.bg);
                foot.Layout.Row = 3;
                obj.Credits = uilabel(foot, 'Text', obj.Source.credit, 'WordWrap', 'on', 'FontSize', 11, 'FontColor', c.text);
                obj.Credits.Layout.Row = 1;
                obj.StatusLabel = uilabel(foot, 'Text', obj.Source.status, 'FontSize', 10, 'FontColor', c.warn);
                obj.StatusLabel.Layout.Row = 2;
                obj.Link = uihyperlink(foot, 'Text', obj.Source.link_text, 'URL', obj.Source.url, 'FontSize', 10, 'FontColor', c.link);
                obj.Link.Layout.Row = 3;
                fig.CloseRequestFcn = @(~, ~) obj.close();
                obj.Figure = fig;
                fig.Visible = char(opts.Visible);
            catch err
                if isvalid(fig), delete(fig); end
                obj.clearHandles();
                rethrow(err);
            end
        end

        function close(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure), delete(obj.Figure); end
            obj.clearHandles();
        end

        function tf = isOpen(obj)
            tf = ~isempty(obj.Figure) && isvalid(obj.Figure);
        end

        function s = status(obj)
            state = "CLOSED"; if obj.isOpen(), state = "OPEN"; end
            src = obj.Source; if isempty(src), src = struct('metadata_status', "NOT_OPENED", 'tile_status', "NOT_OPENED", 'credit_source', "", 'credit', ""); end
            s = struct('state', state, 'basemap', obj.Basemap, 'theme', obj.Theme, 'metadata_status', src.metadata_status, ...
                'tile_status', src.tile_status, 'credit_source', src.credit_source, 'credit', src.credit, 'anchor_lla', obj.Site.anchor_lla);
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Access = private)
        function clearHandles(obj)
            [obj.Figure, obj.Axes, obj.Banner, obj.Credits, obj.StatusLabel, obj.Link] = deal([]);
        end
    end

    methods (Static, Access = private)
        function c = colours(name)
            if name == "dark"
                c = struct('bg', [0.08 0.10 0.13], 'text', [0.93 0.96 0.98], 'banner', [0.45 0.08 0.08], 'warn', [1 0.82 0.45], 'link', [0.46 0.86 1.00]);
            else
                c = struct('bg', [0.97 0.97 0.98], 'text', [0.10 0.13 0.17], 'banner', [0.98 0.86 0.86], 'warn', [0.62 0.36 0.00], 'link', [0.05 0.35 0.75]);
            end
        end
    end
end
