function R = mgv2PerfRun(cond, opts)
%MGV2PERFRUN One measured mission for issue #76, on the host it runs on. Default scene. SIMULATED.
%   R = mgv2PerfRun(cond)     cond: H_NULL | H_R20 | H_R100 | UI_NULL | UI_R20 | UI_R100
%   R = mgv2PerfRun(cond, MaxTicks=n, RealTime=0, Visible="on", KeepApp=false)
%   H_  headless session: step, plus MissionSession.view() every 4 ticks, nothing drawn.
%   UI_ real window with the app's default RenderEvery and SceneEvery.
%   _NULL no detector; _R20 and _R100 bridge rebuild interval in ticks.
%   Every run reports the fixed-workload CPU calibration before and after, so a slower host can be told apart
%   from a slower program. No physics or sensor tick is skipped. No study stage runs, and TEST stays sealed.
%   These are wall-clock measurements. Scene refreshes are not measured screen frames.
arguments
    cond (1,1) string {mustBeMember(cond, ["H_NULL","H_R20","H_R100","UI_NULL","UI_R20","UI_R100"])}
    opts.MaxTicks (1,1) double = inf
    opts.RealTime (1,1) double = 0
    opts.Visible (1,1) string = "on"
end
parts = split(cond, "_"); isUi = parts(1) == "UI"; bridge = parts(2) ~= "NULL";
cal0 = calibration(); host0 = hostState();
if bridge, src = mgv2.bridge.V2006AnomalySource(RefreshTicks=str2double(extractAfter(parts(2), "R")));
else, src = mgv2.ui.NullAnomalySource();
end
stale = zeros(0, 1); t0 = tic;
if isUi
    app = mgv2.ui.MissionControlApp(Visible=opts.Visible, RealTime=opts.RealTime, MaxTicksPerRun=opts.MaxTicks, AnomalySource=src);
    c = onCleanup(@() delete(app));
    if bridge, src.bindSession(app.Session); app.AfterRefreshFcn = @(a) noteAge(src); end
    ses = app.Session; startup = toc(t0);
    noteAge("clear");
    tr = tic; app.command("start"); wall = toc(tr);
    P = app.perfSummary(); G = app.Perf.gap_ms;
    R = struct('step_ms', P.step_ms, 'present_ms', P.present_ms, 'drawnow_ms', P.drawnow_ms, 'gap_ms', stats(G), 'gaps_over_250ms', nnz(G > 250), 'gaps_over_1s', nnz(G > 1000), ...
        'late_ticks', P.late_ticks, 'events_panel_ms', P.events_ms, 'map_panel_ms', P.map_ms, 'scene_panel_ms', P.scene_ms);
    worst = max([G; 0]); stale = noteAge("get");
else
    ses = mgv2.ui.MissionSession(AnomalySource=src);
    if bridge, src.bindSession(ses); end
    startup = toc(t0); ses.start(); n = min(opts.MaxTicks, 6000);
    st = zeros(n, 1); vw = zeros(ceil(n / 4) + 1, 1); nV = 0; tr = tic; worst = 0;
    for k = 1:n
        t = tic; ok = ses.step(); st(k) = 1e3 * toc(t);
        if ~ok, k = k - 1; break; end %#ok<FXSET>
        b = st(k);
        if mod(k, 4) == 0
            t = tic; v = ses.view(); nV = nV + 1; vw(nV) = 1e3 * toc(t); b = b + vw(nV);
            if bridge, stale(end+1, 1) = v.source.stale_ticks; end %#ok<AGROW>
        end
        worst = max(worst, b);
    end
    wall = toc(tr);
    R = struct('step_ms', stats(st(1:k)), 'view_ms', stats(vw(1:nV)));
end
L = ses.Sensors.Log; P0 = ses.Engine.poseLog();
R.cond = cond; R.startup_s = startup; R.ticks = double(ses.Engine.TickId); R.phase = string(ses.Engine.Phase); R.sim_s = ses.Engine.time(); R.wall_s = wall; R.sim_to_wall = R.sim_s / wall;
R.worst_block_ms = worst; R.samples = height(L); R.invalid_samples = nnz(~L.valid); R.sample_digest = digest(L.checksum); R.pose_digest = digest(string(P0.position_enu_m));
R.calibration_before_ms = cal0; R.host_before = host0;
if bridge
    S = src.Stats; d = src.Detector; R.rebuilds = S.rebuilds; R.rebuild_ms = stats(S.rebuild_ms); R.on_sample_total_s = S.on_sample_total_ms / 1e3;
    E = src.suspectedEvents(); R.events = numel(E); R.event_digest = digest(string(arrayfun(@(e) sprintf('%s %.17g %.17g %.17g %.17g', e.event_id, e.x_est_m, e.y_est_m, e.model_score, e.uncertainty_m), E, 'UniformOutput', false)));
    R.stale_s = stats(stale * ses.MissionConfig.dt_s); R.fingerprint = d.Fingerprint;
end
if isUi, clear c; end
R.calibration_after_ms = calibration(); R.host_after = hostState();
end

function a = noteAge(x)
persistent v
if isstring(x) && x == "clear", v = zeros(0, 1); a = []; return; end
if isstring(x) && x == "get", a = v; return; end
i = x.sourceInfo(); if isfinite(i.stale_ticks), v(end+1, 1) = i.stale_ticks; end
a = [];
end

function ms = calibration()
%CALIBRATION Median time of a fixed numeric workload. It uses no project code.
r = RandStream('mrg32k3a', 'Seed', 1); A = rand(r, 700); B = rand(r, 300); t = zeros(5, 1);
for k = 1:5, t0 = tic; x = A' * A; s = svd(B); y = sum(cumsum(A(:))) + sum(s) + x(1); t(k) = 1e3 * toc(t0); end %#ok<NASGU>
ms = median(t);
end

function h = hostState()
h = struct('figures', numel(findall(groot, 'Type', 'figure')), 'timers', numel(timerfindall), 'graphics_under_root', numel(findall(groot)), 'matlab_mem_MB', NaN);
if ispc, m = memory; h.matlab_mem_MB = m.MemUsedMATLAB / 1e6; end
end

function s = stats(v)
if isempty(v), s = struct('n', 0, 'median', NaN, 'p95', NaN, 'max', NaN); return; end
v = sort(v(:)); s = struct('n', numel(v), 'median', median(v), 'p95', v(ceil(0.95 * numel(v))), 'max', v(end));
end

function d = digest(x)
d = mgv2.eval.sha256(char(strjoin(string(x(:)), newline)));
end
