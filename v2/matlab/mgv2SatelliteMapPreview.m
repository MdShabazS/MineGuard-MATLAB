function out = mgv2SatelliteMapPreview(opts)
%MGV2SATELLITEMAPPREVIEW Optional synthetic route on an internet satellite basemap.
%   From repository root:
%     addpath('v2/matlab')
%     mgv2SatelliteMapPreview(AnchorLLA=[YOUR_LAT YOUR_LON YOUR_ELLIPSOID_HEIGHT])
%
%   Optional:
%     mgv2SatelliteMapPreview(AnchorLLA=[...], Basemap="darkwater")
%     mgv2SatelliteMapPreview(AnchorLLA=[...], Visible="off")
%
%   WARNING: Basemap is only GEOGRAPHIC CONTEXT, not drone-captured imagery.
%   All route points are SIMULATED; this does not geolocate real mines, targets
%   or the aircraft. Existing local ENU MapPanel is the offline primary map.
%   Satellite tiles are served online by Esri; attribution stays visible in a footer outside the map.
%   Online tiles have no failure signal: uncached areas are simply blank when offline. The footer reports
%   whether the provider's service answered when the window opened, which does not prove tiles loaded.
%   After a reconnect, tiles return on the next pan or zoom; the footer keeps describing the moment of opening.
%   This standalone PREVIEW changes no mission engine, sensor or detector state.
arguments
    opts.AnchorLLA (1,3) double = [NaN NaN NaN]
    opts.MissionConfig struct = mgv2.mission.defaultConfig()
    opts.Basemap (1,1) string {mustBeMember(opts.Basemap, ["satellite","streets-light","topographic","darkwater"])} = "satellite"
    opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
end
if any(~isfinite(opts.AnchorLLA)) || hypot(opts.AnchorLLA(1), opts.AnchorLLA(2)) < 0.01
    error('mgv2:MissingGeographicAnchor', ...
        ['An explicit WGS84 demo anchor [lat lon ellipsoidal_height] is required. ' ...
        'The mission config''s [0 0 0] origin is only a virtual placeholder.']);
end

% Generate exactly the planned survey from public mission configuration.
% NEVER use a truth-bearing scenario, evaluated target, or detector event.
cfg = mgv2.mission.validateConfig(opts.MissionConfig);
route = mgv2.mission.buildRoute(cfg, mgv2.mission.planSurvey(cfg));
polygon = [cfg.survey_polygon_enu_m; cfg.survey_polygon_enu_m(1,:)];
home = cfg.home_enu_m;
to3 = @(xy) [double(xy), zeros(size(xy,1),1)];
geoRoute = mgv2.geo.enuToWgs84(to3(route.xy), opts.AnchorLLA);
geoPoly = mgv2.geo.enuToWgs84(to3(polygon), opts.AnchorLLA);
geoHome = mgv2.geo.enuToWgs84(to3(home), opts.AnchorLLA);
% Validate inputs and perform all conversion BEFORE opening a figure.
src = basemapSource(opts.Basemap);

fig = uifigure('Name','MineGuard V2 - SIMULATED Satellite Route Preview', ...
    'Position',[100 100 1040 760], 'Visible','off','Color',[0.08 0.10 0.13]);
try
    % Fix the graphics theme before children are created. R2026b can otherwise
    % render near-white geographic tick labels on this dark figure in light desktop mode.
    theme(fig, "dark");
    g = uigridlayout(fig,[3 1], 'RowHeight',{52,'1x',84}, 'ColumnWidth',{'1x'}, ...
        'Padding',[8 8 8 8], 'RowSpacing',6, 'BackgroundColor',[0.08 0.10 0.13]);
    warningText = ['SIMULATION ONLY | GEOGRAPHIC CONTEXT | NOT A REAL FLIGHT / NOT A HAZARD MAP' newline ...
        'Live satellite tiles require internet. Offline flight uses the existing synthetic ENU mission map.'];
    lbl = uilabel(g,'Text',warningText, 'FontWeight','bold', 'FontSize',12, ...
        'FontColor',[0.93 0.96 0.98], 'BackgroundColor',[0.08 0.10 0.13], ...
        'WordWrap','on');
    lbl.Layout.Row=1; lbl.Layout.Column=1;
    gx = geoaxes(g,'Basemap',char(opts.Basemap));
    gx.Layout.Row=2; gx.Layout.Column=1;
    hold(gx,'on');
    % An explicit axes colour is required because the desktop's light theme
    % can otherwise leave near-white frame labels on a light/white surface.
    gx.AxisColor = [0.92 0.95 0.98];
    % MathWorks: if the map's own attribution is not readable, show it elsewhere on the figure. It was not
    % visible on Mac R2026b, so the credit always sits in this footer, outside the map and any zoom level.
    cg = uigridlayout(g,[3 1], 'RowHeight',{'1x',18,18}, 'ColumnWidth',{'1x'}, ...
        'Padding',[2 0 2 0], 'RowSpacing',0,'BackgroundColor',[0.08 0.10 0.13]);
    cg.Layout.Row=3; cg.Layout.Column=1;
    credits = uilabel(cg,'Text',src.credit,'WordWrap','on', ...
        'FontSize',10,'FontColor',[0.94 0.96 0.98], 'VerticalAlignment','center');
    credits.Layout.Row=1; credits.Layout.Column=1;
    statusLabel = uilabel(cg,'Text',src.status,'FontSize',10,'FontColor',[1 0.82 0.45]);
    statusLabel.Layout.Row=2; statusLabel.Layout.Column=1;
    creditLink = uihyperlink(cg,'Text',src.link_text,'URL',src.url, ...
        'FontSize',11,'FontColor',[0.46 0.86 1.00]);
    creditLink.Layout.Row=3; creditLink.Layout.Column=1;
    hBoundary = geoplot(gx,geoPoly(:,1),geoPoly(:,2),'-', ...
        'Color',[1 0.77 0.12], 'LineWidth',2);
    hRoute = geoplot(gx,geoRoute(:,1),geoRoute(:,2),'--', ...
        'Color',[0.10 0.85 0.93], 'LineWidth',1.5);
    hHome = geoplot(gx,geoHome(:,1),geoHome(:,2),'p', ...
        'MarkerSize',11,'MarkerFaceColor',[0.98 0.81 0.25], ...
        'MarkerEdgeColor',[0 0 0]);
    coords = [geoPoly(:,1:2); geoRoute(:,1:2); geoHome(:,1:2)];
    latmin=min(coords(:,1)); latmax=max(coords(:,1));
    lonmin=min(coords(:,2)); lonmax=max(coords(:,2));
    dLat=max((latmax-latmin)*0.12,0.0002);
    dLon=max((lonmax-lonmin)*0.12,0.0002);
    geolimits(gx,[latmin-dLat latmax+dLat],[lonmin-dLon lonmax+dLon]);
    fig.Visible=char(opts.Visible);
    out = struct('figure',fig,'axes',gx,'warning_label',lbl, ...
        'attribution_label',credits,'attribution_link',creditLink,'status_label',statusLabel, ...
        'basemap_status',src.status,'credit_source',src.credit_source, ...
        'boundary_line',hBoundary,'route_line',hRoute,'home_marker',hHome, ...
        'anchor_lla',opts.AnchorLLA,'route_lla',geoRoute, ...
        'boundary_lla',geoPoly,'home_lla',geoHome,'basemap_requested',opts.Basemap, ...
        'provenance',"SIMULATED_PLANNED_ROUTE_ONLY");
catch ME
    if isvalid(fig), delete(fig); end
    rethrow(ME);
end
end

function src = basemapSource(basemap)
%BASEMAPSOURCE Provider credit for a basemap. Esri services publish their current credit as copyrightText, so read
%   it when the service answers; otherwise show the text pinned below, as read from those services on 2026-11-02.
root = "https://services.arcgisonline.com/ArcGIS/rest/services/";
switch basemap
    case "satellite"
        service = "World_Imagery"; pinned = "Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community";
    case "topographic"
        service = "World_Topo_Map"; pinned = "Sources: Esri, HERE, Garmin, Intermap, increment P Corp., GEBCO, USGS, FAO, NPS, NRCAN, GeoBase, IGN, Kadaster NL, Ordnance Survey, Esri Japan, METI, Esri China (Hong Kong), (c) OpenStreetMap contributors, and the GIS User Community";
    case "streets-light"
        service = "Canvas/World_Light_Gray_Base"; pinned = "Sources: Esri, HERE, Garmin, (c) OpenStreetMap contributors, and the GIS user community";
    otherwise   % darkwater is installed with MATLAB and needs no network
        src = struct('credit', "Basemap: darkwater, created using Natural Earth and installed with MATLAB. A display backdrop, not imagery.", ...
            'status', "Local basemap: no internet needed. Live satellite tiles are not available in this mode.", 'credit_source', "MATHWORKS_DOCUMENTATION", ...
            'link_text', "MathWorks basemap source information", 'url', "https://www.mathworks.com/help/matlab/ref/geobasemap.html");
        return
end
url = root + service + "/MapServer";
try
    info = webread(url + "?f=json", weboptions('Timeout', 3, 'ContentType', 'json'));
    live = string(info.copyrightText);
    if strlength(live) == 0, error('mgv2:EmptyCredit', 'The service returned no credit.'); end
    credit = live; creditSource = "LIVE_SERVICE";
    status = "Provider service answered when this window opened. Tiles load separately; blank areas mean tiles were not available.";
catch
    credit = pinned; creditSource = "PINNED_2026_11_02";
    status = "Provider service did not answer when this window opened. Map may be blank or cached. After reconnecting, pan, zoom or reopen; offline, use the ENU mission map.";
end
if ~startsWith(credit, "Source"), credit = "Sources: " + credit; end
src = struct('credit', "Powered by Esri | " + credit, 'status', status, 'credit_source', creditSource, ...
    'link_text', "Esri service page and source credits", 'url', url);
end
