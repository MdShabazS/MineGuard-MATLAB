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
%   Satellite tiles are served online by Esri; attribution must stay visible.
%   This standalone PREVIEW changes no mission engine, sensor or detector state.
arguments
    opts.AnchorLLA (1,3) double = [NaN NaN NaN]
    opts.MissionConfig struct = mgv2.mission.defaultConfig()
    opts.Basemap (1,1) string {mustBeMember(opts.Basemap, ["satellite","streets-light","topographic","darkwater"])} = "satellite"
    opts.Visible (1,1) string {mustBeMember(opts.Visible, ["on","off"])} = "on"
end
if any(~isfinite(opts.AnchorLLA)) || (abs(opts.AnchorLLA(1)) < 1e-6 && abs(opts.AnchorLLA(2)) < 1e-6)
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

fig = uifigure('Name','MineGuard V2 - SIMULATED Satellite Route Preview', ...
    'Position',[100 100 1040 760], 'Visible','off','Color',[0.08 0.10 0.13]);
try
    % Fix the graphics theme before children are created. R2026b can otherwise
    % render near-white geographic tick labels on this dark figure in light desktop mode.
    theme(fig, "dark");
    g = uigridlayout(fig,[3 1], 'RowHeight',{52,'1x',70}, 'ColumnWidth',{'1x'}, ...
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
    % Built-in geographic tile-credit UI has been observed empty on Mac R2026b.
    % Display a persistent, visible credit below the map. Never introspect or
    % manipulate undocumented BasemapDisplay internals.
    if opts.Basemap == "satellite"
        providerText = ['Powered by Esri | World Imagery sources: Esri, DigitalGlobe, GeoEye, i-cubed, USDA FSA, USGS, AEX, ' ...
            'Getmapping, Aerogrid, IGN, IGP, swisstopo and the GIS User Community.'];
        providerUrl = "https://support.esri.com/en-us/knowledge-base/what-is-the-correct-way-to-cite-an-arcgis-online-basema-000012040";
        providerLink = "Esri full imagery-source credits";
    elseif opts.Basemap == "darkwater"
        providerText = 'Basemap: MATLAB darkwater. This is a geographic display backdrop, not satellite evidence.';
        providerUrl = "https://www.mathworks.com/help/matlab/ref/geobasemap.html";
        providerLink = "MathWorks basemap source information";
    else
        providerText = 'Powered by Esri | geographic basemap. Specific providers and data-source attributions depend on map selection.';
        providerUrl = "https://www.mathworks.com/help/matlab/ref/geobasemap.html";
        providerLink = "Map provider and attribution details";
    end
    cg = uigridlayout(g,[2 1], 'RowHeight',{'1x',20}, 'ColumnWidth',{'1x'}, ...
        'Padding',[2 0 2 0], 'RowSpacing',0,'BackgroundColor',[0.08 0.10 0.13]);
    cg.Layout.Row=3; cg.Layout.Column=1;
    credits = uilabel(cg,'Text',providerText,'WordWrap','on', ...
        'FontSize',10,'FontColor',[0.94 0.96 0.98], 'VerticalAlignment','center');
    credits.Layout.Row=1; credits.Layout.Column=1;
    creditLink = uihyperlink(cg,'Text',providerLink,'URL',char(providerUrl), ...
        'FontSize',11,'FontColor',[0.46 0.86 1.00]);
    creditLink.Layout.Row=2; creditLink.Layout.Column=1;
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
        'attribution_label',credits,'attribution_link',creditLink, ...
        'boundary_line',hBoundary,'route_line',hRoute,'home_marker',hHome, ...
        'anchor_lla',opts.AnchorLLA,'route_lla',geoRoute, ...
        'boundary_lla',geoPoly,'home_lla',geoHome,'basemap_requested',opts.Basemap, ...
        'provenance',"SIMULATED_PLANNED_ROUTE_ONLY");
catch ME
    if isvalid(fig), delete(fig); end
    rethrow(ME);
end
end
