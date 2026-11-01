function R = mgv2PerfProfile(opts)
%MGV2PERFPROFILE Where the detector and bridge spend time and memory as a mission grows (issue #76). SIMULATED.
%   R = mgv2PerfProfile()                 default scene, full mission, no profiler overhead, growth checkpoints
%   R = mgv2PerfProfile(Profiler=true)    same mission under the MATLAB profiler; adds the top functions by self time
%   R = mgv2PerfProfile(MaxTicks=n, CheckEvery=700)
%   At each checkpoint the read path is timed on the same state: trackTable, events, toUiEvents, snapshot, view.
%   Sections of trackTable are re-created here on the detector's private data, read through struct(), to time them
%   separately. This is measurement only and changes nothing. No study stage runs, and TEST stays sealed.
arguments
    opts.Profiler (1,1) logical = false
    opts.MaxTicks (1,1) double = inf
    opts.CheckEvery (1,1) double = 700
end
src = mgv2.bridge.V2006AnomalySource(RefreshTicks=1e9);    % nothing rebuilt during flight: read-path cost is timed separately
ses = mgv2.ui.MissionSession(AnomalySource=src); src.bindSession(ses); ses.start();
n = min(opts.MaxTicks, 6000); rows = {}; k = 0;
if opts.Profiler, profile('clear'); profile('on', '-timer', 'performance'); end
while k < n && ses.step()
    k = k + 1;
    if ~opts.Profiler && mod(k, opts.CheckEvery) == 0, rows(end+1, :) = checkpoint(src, ses, k); end %#ok<AGROW>
end
R = struct('ticks', k, 'phase', string(ses.Engine.Phase));
if opts.Profiler
    src.Detector.events(); src.Map.snapshot();                   % include one read of each in the profile
    profile('off'); P = profile('info'); F = P.FunctionTable; self = zeros(numel(F), 1);
    for q = 1:numel(F), self(q) = F(q).TotalTime - sum([F(q).Children.TotalTime]); end
    [~, o] = sort(self, 'descend'); o = o(1:min(30, numel(o)));
    R.top = table(string({F(o).FunctionName})', self(o), [F(o).TotalTime]', [F(o).NumCalls]', 'VariableNames', ["fn","self_s","total_s","calls"]);
else
    rows(end+1, :) = checkpoint(src, ses, k);
    R.growth = cell2table(rows, 'VariableNames', ["tick","n_looks","n_obs","n_tracks","live","n_evidence","trackTable_ms","looks_loop_ms","track_scan_ms","lidar_ms","landmark_ms", ...
        "events_ms","events_only_ms","convert_ms","snapshot_ms","layers_ms","uiValidate_ms","view_cached_ms","det_MB","Ob_MB","Tr_MB","Looks_MB","Ev_MB","Lg_MB","Log_MB","map_MB","Footprints_MB","sensorLog_MB"]);
    D = src.Detector.Log; g = groupsummary(D, 'sensor_id', {'median','max','sum'}, 'proc_ms');
    R.ingest = g(:, ["sensor_id","GroupCount","median_proc_ms","max_proc_ms","sum_proc_ms"]);
    S = src.Stats; R.on_sample_total_s = S.on_sample_total_ms / 1e3; R.detector_ingest_total_s = sum(D.proc_ms) / 1e3;
end
end

function row = checkpoint(src, ses, k)
d = src.Detector; s = warning('off', 'all'); c = onCleanup(@() warning(s)); D = struct(d);
Ob = D.Ob; Tr = D.Tr; Lk = D.Looks; live = find(Tr.alive);
tA = med(@() d.trackTable()); T = d.trackTable();
n = height(T); x = T.x_m; y = T.y_m;
tLoop = med(@() looksLoop(Lk, x, y, n));
tScan = med(@() trackScan(Ob, T.track_no));
tLid = lidarCost(D.Lg, d.Config.lidar.context_radius_m, x, y);
tLm = med(@() landmark(D.Landmarks, x, y, d.Config.landmark_exclusion_m));
tE = med(@() d.events()); E = d.events();
tConv = med(@() mgv2.bridge.toUiEvents(E, d.RunId, d)); ev = mgv2.bridge.toUiEvents(E, d.RunId, d);
tSnap = med(@() src.Map.snapshot()); S = src.Map.snapshot();
tLay = med(@() mgv2.bridge.toMapLayers(S, ev, 1, 1));
tVal = med(@() mgv2.ui.validateEvents(ev));
src.suspectedEvents(); tView = med(@() ses.view());          % RefreshTicks is huge, so this is the cached path when not dirty
mb = @(v) numel(getByteStreamFromArray(v)) / 1e6;
row = {k, numel(Lk.mod), numel(Ob.track), numel(Tr.no), numel(live), D.Ev.Count, tA, tLoop, tScan, tLid, tLm, tE, tE - tA, tConv, tSnap, tLay, tVal, tView, ...
    mb(d), mb(Ob), mb(Tr), mb(Lk), mb(D.Ev), mb(D.Lg), mb(D.Log), mb(src.Map), mb(src.Map.Footprints), mb(ses.Sensors.Log)};
end

function looksLoop(Lk, x, y, n)
looks = zeros(n, 2);
for k = 1:size(Lk.mod, 1)
    fp = Lk.fp{k}; in = inpolygon(x, y, fp(:,1), fp(:,2)); looks(in, Lk.mod(k)) = looks(in, Lk.mod(k)) + 1;
end
end

function trackScan(Ob, no)
for i = 1:numel(no)
    j = find(Ob.track == no(i)); a = min(Ob.tick(j)); b = max(Ob.tick(j)); %#ok<NASGU>
    for m = 1:2
        q = j(Ob.mod(j) == m); if isempty(q), continue; end
        u = numel(unique(Ob.frame(q))); v = median(Ob.strength(q)); %#ok<NASGU>
    end
end
end

function ms = lidarCost(g, R, x, y)
t0 = tic; [J, I] = meshgrid(1:size(g.n, 2), 1:size(g.n, 1)); cx = g.x0 + (J - 0.5) * g.c; cy = g.y0 + (I - 0.5) * g.c;
for q = 1:numel(x)
    sel = abs(cx - x(q)) <= R & abs(cy - y(q)) <= R; sel(sel) = hypot(cx(sel) - x(q), cy(sel) - y(q)) <= R; N = sum(g.n(sel)); %#ok<NASGU>
end
ms = 1e3 * toc(t0);
end

function landmark(L, x, y, r)
for q = 1:numel(L), near = hypot(x - L(q).xy(1), y - L(q).xy(2)) <= L(q).radius_m + r; %#ok<NASGU>
end
end

function ms = med(f)
t = zeros(3, 1);
for k = 1:3, t0 = tic; f(); t(k) = 1e3 * toc(t0); end
ms = median(t);
end
