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
if any(~isfinite(opts.AnchorLLA)) || isequal(opts.AnchorLLA, [0 0 0])
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
    g = uigridlayout(fig,[2 1], 'RowHeight',{52,'1x'}, 'ColumnWidth',{'1x'}, ...
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
    % Map source attribution remains displayed by geographic axes.
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
        'boundary_line',hBoundary,'route_line',hRoute,'home_marker',hHome, ...
        'anchor_lla',opts.AnchorLLA,'route_lla',geoRoute, ...
        'boundary_lla',geoPoly,'home_lla',geoHome,'basemap_requested',opts.Basemap, ...
        'provenance',"SIMULATED_PLANNED_ROUTE_ONLY");
catch ME
    if isvalid(fig), delete(fig); end
    rethrow(ME);
end
end
