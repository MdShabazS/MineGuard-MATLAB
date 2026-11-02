function sat_offline(repo, outDir, stateFile, port)
%SAT_OFFLINE Second MATLAB, throwaway preferences, Esri hosts denied by a local proxy, then allowed again.
addpath(fullfile(repo, 'v2', 'matlab')); anchor = [48.85837 2.29448 100];
fprintf('prefdir is temporary: %d\n', startsWith(prefdir, tempdir));
com.mathworks.mlwidgets.html.HTMLPrefs.setUseProxy(true);
com.mathworks.mlwidgets.html.HTMLPrefs.setProxyHost('127.0.0.1');
com.mathworks.mlwidgets.html.HTMLPrefs.setProxyPort(num2str(port));
setState(stateFile, "off"); pause(1);
try
    webread("https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer?f=json", weboptions('Timeout', 5));
    disp('network check: ANSWERED, so the denial is not active');
catch ME
    fprintf('network check: %s\n', ME.identifier);
end
p = mgv2SatelliteMapPreview(AnchorLLA=anchor); pause(10); drawnow;
report(p, '1 denied', outDir, 'offline-1-denied.png');
q = mgv2SatelliteMapPreview(AnchorLLA=anchor, Basemap="darkwater"); pause(2); drawnow;
report(q, '1 denied darkwater', outDir, 'offline-1-denied-darkwater.png'); delete(q.figure);

src = mgv2.ui.NullAnomalySource(); t = tic;
app = mgv2.ui.MissionControlApp(Visible="on", RealTime=0, MaxTicksPerRun=400, AnomalySource=src); app.command("start");
fprintf('offline ENU app: tick %d phase %s, %.1f s, geoaxes %d\n', app.Session.Engine.TickId, app.Session.Engine.Phase, toc(t), numel(findall(app.Figure, 'Type', 'geoaxes')));
exportapp(app.Figure, fullfile(outDir, 'offline-enu-mission-control.png')); delete(app);

setState(stateFile, "on"); pause(15); drawnow;
report(p, '2 allowed, same window untouched 15 s', outDir, 'offline-2-allowed-untouched.png');
[la, lo] = geolimits(p.axes); geolimits(p.axes, la + diff(la) * 0.1, lo + diff(lo) * 0.1); pause(10); drawnow;
report(p, '3 allowed, after pan', outDir, 'offline-3-allowed-after-pan.png'); delete(p.figure);
n = mgv2SatelliteMapPreview(AnchorLLA=anchor); pause(10); drawnow;
report(n, '4 allowed, new window', outDir, 'offline-4-new-window.png'); delete(n.figure);
fprintf('figures %d timers %d\nDONE\n', numel(findall(groot, 'Type', 'figure')), numel(timerfindall));
end

function report(p, label, outDir, name)
f = fullfile(outDir, name); exportapp(p.figure, f); I = double(rgb2gray(imread(f))); [h, w] = size(I);
v = std(reshape(I(round(h * 0.15):round(h * 0.8), round(w * 0.1):round(w * 0.9)), [], 1));
fprintf('%s: credit_source %s; variation %.1f; warning visible %d\n  credit: %s\n  status: %s\n', label, p.credit_source, v, strcmp(p.warning_label.Visible, 'on'), p.attribution_label.Text, p.status_label.Text);
end

function setState(file, s)
fid = fopen(file, 'w'); fprintf(fid, '%s', s); fclose(fid);
end
