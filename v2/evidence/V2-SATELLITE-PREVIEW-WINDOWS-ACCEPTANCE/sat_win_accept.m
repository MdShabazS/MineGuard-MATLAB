function R = sat_win_accept(repo, outDir)
%SAT_WIN_ACCEPT Windows acceptance checks for mgv2SatelliteMapPreview. SIMULATED route on a context basemap.
%   Anchor: the public landmark already used by the Mac record, height assumed, not surveyed. Not a user location.
addpath(fullfile(repo, 'v2', 'matlab')); if ~exist(outDir, 'dir'), mkdir(outDir); end
anchor = [29.97917 31.13417 80]; R = struct('anchor', anchor, 'version', string(version));
base = struct('figs', numel(findall(groot, 'Type', 'figure')), 'timers', numel(timerfindall));
fprintf('version %s\nanchor %s\n', version, mat2str(anchor));

% 1. Route alignment, by an independent inverse of the returned coordinates.
p = mgv2SatelliteMapPreview(AnchorLLA=anchor, Basemap="darkwater", Visible="off");
cfg = mgv2.mission.validateConfig(mgv2.mission.defaultConfig());
route = mgv2.mission.buildRoute(cfg, mgv2.mission.planSurvey(cfg));
back = llaToEnu(p.route_lla, anchor); polyBack = llaToEnu(p.boundary_lla, anchor);
R.route_roundtrip_max_m = max(vecnorm(back(:, 1:2) - double(route.xy), 2, 2));
R.boundary_roundtrip_max_m = max(vecnorm(polyBack(1:end-1, 1:2) - double(cfg.survey_polygon_enu_m), 2, 2));
R.line_equals_route = isequal(p.route_line.LatitudeData(:), p.route_lla(:, 1)) && isequal(p.route_line.LongitudeData(:), p.route_lla(:, 2));
R.provenance = p.provenance;
delete(p.figure);
fprintf('route roundtrip max %.3e m; boundary %.3e m; plotted line equals route %d\n', R.route_roundtrip_max_m, R.boundary_roundtrip_max_m, R.line_equals_route);

% 2. Both desktop themes, online, satellite and the other basemaps.
s = settings; themeSetting = s.matlab.appearance.MATLABTheme;
fprintf('desktop theme setting before test: %s\n', string(themeSetting.ActiveValue));
restore = onCleanup(@() clearTemporary(themeSetting));
for themeName = ["Dark", "Light"]
    themeSetting.TemporaryValue = themeName; pause(1);
    for bm = ["satellite", "topographic", "streets-light", "darkwater"]
        t = tic; p = mgv2SatelliteMapPreview(AnchorLLA=anchor, Basemap=bm); drawnow; open = toc(t);
        pause(6); drawnow;
        file = fullfile(outDir, sprintf('windows-%s-%s.png', lower(themeName), bm));
        exportapp(p.figure, file); std0 = axesVariation(file);
        bg = p.figure.Color; c = struct('axis', contrast(p.axes.AxisColor, bg), 'warning', contrast(p.warning_label.FontColor, bg), ...
            'credit', contrast(p.attribution_label.FontColor, bg), 'status', contrast(p.status_label.FontColor, bg), 'link', contrast(p.attribution_link.FontColor, bg));
        fprintf('%s %s: open %.2f s; image variation %.1f; contrast axis %.2f warning %.2f credit %.2f status %.2f link %.2f; credit_source %s\n  credit: %s\n  status: %s\n  warning visible %d: %s\n', ...
            themeName, bm, open, std0, c.axis, c.warning, c.credit, c.status, c.link, p.credit_source, p.attribution_label.Text, p.status_label.Text, ...
            strcmp(p.warning_label.Visible, 'on'), replace(string(p.warning_label.Text), newline, " / "));
        if bm == "satellite" && themeName == "Dark", zoomPan(p, outDir); end
        delete(p.figure);
    end
end
clear restore; fprintf('theme after test: %s\n', string(themeSetting.ActiveValue));

% 3. Repeated open and close, with memory.
close all force; drawnow; java.lang.System.gc; m0 = memory; N = 30; tt = zeros(N, 1); errs = 0;
for k = 1:N
    t = tic;
    try
        p = mgv2SatelliteMapPreview(AnchorLLA=anchor, Basemap="satellite"); drawnow; delete(p.figure); drawnow;
    catch ME
        errs = errs + 1; fprintf('cycle %d error %s\n', k, ME.identifier);
    end
    tt(k) = toc(t);
end
pause(2); m1 = memory;
fprintf('%d open/close: errors %d; median %.2f s, max %.2f s; figures %d (base %d), timers %d (base %d); MATLAB memory %.0f -> %.0f MB\n', N, errs, median(tt), max(tt), ...
    numel(findall(groot, 'Type', 'figure')), base.figs, numel(timerfindall), base.timers, m0.MemUsedMATLAB / 1e6, m1.MemUsedMATLAB / 1e6);

% 4. Invalid anchors never open a figure.
bad = {[0 0 0], [0.001 0 0], [NaN 0 0], [85 10 0], [10 179.5 0], [10 10 20000]};
for k = 1:numel(bad)
    n0 = numel(findall(groot, 'Type', 'figure')); id = "NO ERROR";
    try, q = mgv2SatelliteMapPreview(AnchorLLA=bad{k}, Visible="off"); delete(q.figure); catch ME, id = string(ME.identifier); end
    fprintf('anchor %s -> %s; new figures %d\n', mat2str(bad{k}), id, numel(findall(groot, 'Type', 'figure')) - n0);
end

% 5. The mission map source uses no geographic or network calls.
files = dir(fullfile(repo, 'v2', 'matlab', '+mgv2', '+ui', '*.m'));
hits = strings(0, 1);
for k = 1:numel(files)
    txt = fileread(fullfile(files(k).folder, files(k).name));
    if ~isempty(regexp(txt, 'geoaxes|geoplot|geobasemap|webread|websave|webwrite|mgv2\.geo', 'once')), hits(end+1, 1) = files(k).name; end %#ok<AGROW>
end
fprintf('UI files with geographic or network calls: %d of %d\nDONE\n', numel(hits), numel(files));
end

function zoomPan(p, outDir)
gx = p.axes; [la, lo] = geolimits(gx); c = [mean(la) mean(lo)]; h = [diff(la) diff(lo)] / 2;
for z = [3 12]
    t = tic; geolimits(gx, c(1) + [-1 1] * h(1) / z, c(2) + [-1 1] * h(2) / z); drawnow; ms = 1e3 * toc(t); pause(4); drawnow;
    f = fullfile(outDir, sprintf('windows-dark-satellite-zoom-x%d.png', z)); exportapp(p.figure, f);
    fprintf('zoom x%d: geolimits+drawnow %.0f ms; image variation %.1f; credit visible %d\n', z, ms, axesVariation(f), strcmp(p.attribution_label.Visible, 'on'));
end
t = tic; geolimits(gx, c(1) + h(1) / 3 + [-1 1] * h(1) / 3, c(2) + h(2) / 3 + [-1 1] * h(2) / 3); drawnow; ms = 1e3 * toc(t); pause(4); drawnow;
f = fullfile(outDir, 'windows-dark-satellite-pan.png'); exportapp(p.figure, f);
fprintf('pan: %.0f ms; image variation %.1f\n', ms, axesVariation(f));
geolimits(gx, la, lo); drawnow;
end

function v = axesVariation(file)
I = double(rgb2gray(imread(file))); [h, w] = size(I);
v = std(reshape(I(round(h * 0.15):round(h * 0.8), round(w * 0.1):round(w * 0.9)), [], 1));
end

function c = contrast(a, b)
L = @(x) sum([0.2126 0.7152 0.0722] .* lin(x)); l = sort([L(a) L(b)], 'descend'); c = (l(1) + 0.05) / (l(2) + 0.05);
end
function y = lin(x)
y = x / 12.92; k = x > 0.03928; y(k) = ((x(k) + 0.055) / 1.055) .^ 2.4;
end

function clearTemporary(st)
if hasTemporaryValue(st), clearTemporaryValue(st); end
end

function enu = llaToEnu(lla, a0)
%Independent inverse: WGS84 geodetic to ECEF, then rotated into the anchor's tangent frame.
a = 6378137; f = 1 / 298.257223563; e2 = f * (2 - f);
ecef = @(q) [(a ./ sqrt(1 - e2 * sind(q(:, 1)).^2) + q(:, 3)) .* cosd(q(:, 1)) .* cosd(q(:, 2)), ...
    (a ./ sqrt(1 - e2 * sind(q(:, 1)).^2) + q(:, 3)) .* cosd(q(:, 1)) .* sind(q(:, 2)), ...
    (a ./ sqrt(1 - e2 * sind(q(:, 1)).^2) * (1 - e2) + q(:, 3)) .* sind(q(:, 1))];
d = ecef(lla) - ecef(a0); sp = sind(a0(1)); cp = cosd(a0(1)); sl = sind(a0(2)); cl = cosd(a0(2));
enu = d * [-sl -sp*cl cp*cl; cl -sp*sl cp*sl; 0 cp sp];
end
