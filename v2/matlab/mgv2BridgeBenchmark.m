function R = mgv2BridgeBenchmark(mode, opts)
%MGV2BRIDGEBENCHMARK Measured cost of the V2-006 bridge on the host it runs on. SIMULATED.
%   R = mgv2BridgeBenchmark("NULL")      session with no detector (baseline)
%   R = mgv2BridgeBenchmark("CACHED")    bridge, rebuild at most every RefreshTicks
%   R = mgv2BridgeBenchmark("UNCACHED")  bridge, rebuild on every view that follows new data
%   R = mgv2BridgeBenchmark("APP_NULL") or ("APP_CACHED")  the real window at RealTime 0, using its perfSummary
%   R = mgv2BridgeBenchmark(mode, MaxTicks=1400, RefreshTicks=20, RenderEvery=4)
%   Headless modes step the session and call view() every RenderEvery ticks, as the app does, with no drawing.
%   They do not measure display performance or frame rate. Default scene only: no study stage, no TEST.
arguments
    mode (1,1) string {mustBeMember(mode, ["NULL","CACHED","UNCACHED","APP_NULL","APP_CACHED"])}
    opts.MaxTicks (1,1) double = inf
    opts.RefreshTicks (1,1) double = 20
    opts.RenderEvery (1,1) double = 4
end
src = mgv2.ui.NullAnomalySource(); bridge = false;
if mode == "CACHED" || mode == "APP_CACHED", src = mgv2.bridge.V2006AnomalySource(RefreshTicks=opts.RefreshTicks); bridge = true; end
if mode == "UNCACHED", src = mgv2.bridge.V2006AnomalySource(RefreshTicks=1); bridge = true; end
R = struct('mode', mode, 'max_ticks', opts.MaxTicks, 'render_every', opts.RenderEvery, 'refresh_ticks', opts.RefreshTicks);
if startsWith(mode, "APP")
    app = mgv2.ui.MissionControlApp(Visible="on", RealTime=0, RenderEvery=opts.RenderEvery, MaxTicksPerRun=opts.MaxTicks, AnomalySource=src);
    c = onCleanup(@() delete(app));
    if bridge, src.bindSession(app.Session); end
    app.command("start"); ses = app.Session;
    R.perf = app.perfSummary(); R.ticks = double(ses.Engine.TickId); R.phase = string(ses.Engine.Phase);
else
    ses = mgv2.ui.MissionSession(AnomalySource=src);
    if bridge, src.bindSession(ses); end
    ses.start(); n = min(opts.MaxTicks, 6000);
    stepMs = zeros(n, 1); viewMs = zeros(ceil(n / opts.RenderEvery) + 1, 1); nV = 0; mem = zeros(0, 3); t0 = tic;
    for k = 1:n
        t = tic; ok = ses.step(); stepMs(k) = 1e3 * toc(t);
        if ~ok, k = k - 1; break; end %#ok<FXSET>
        if mod(k, opts.RenderEvery) == 0
            t = tic; ses.view(); nV = nV + 1; viewMs(nV) = 1e3 * toc(t);
        end
        if bridge && mod(k, 700) == 0
            mem(end+1, :) = [k, numel(getByteStreamFromArray(src.Detector)), numel(getByteStreamFromArray(src.Map))]; %#ok<AGROW>
        end
    end
    wall = toc(t0); stepMs = stepMs(1:k); viewMs = viewMs(1:nV);
    t = tic; v = ses.view(); finalView = 1e3 * toc(t);
    R.ticks = k; R.phase = string(ses.Engine.Phase); R.sim_s = ses.Engine.time(); R.wall_s = wall; R.sim_to_wall = R.sim_s / wall;
    R.step_ms = stats(stepMs); R.view_ms = stats(viewMs); R.views = nV; R.final_view_ms = finalView; R.final_events = numel(v.events);
    if bridge, R.memory_bytes = mem; end
end
if bridge
    S = src.Stats; R.rebuilds = S.rebuilds; R.requests = S.requests; R.samples = S.samples; R.refused = S.samples_refused;
    R.on_sample_mean_ms = S.on_sample_total_ms / max(S.samples, 1); R.on_sample_max_ms = S.on_sample_max_ms;
    R.rebuild_ms = stats(S.rebuild_ms); R.convert_ms = stats(S.convert_ms); R.layers_ms = stats(S.layers_ms);
    q = find(S.rebuild_tick >= 0); idx = q(unique(round(linspace(1, numel(q), min(8, numel(q))))));
    R.rebuild_growth = table(S.rebuild_tick(idx), S.rebuild_events(idx), S.rebuild_ms(idx), S.convert_ms(idx), S.layers_ms(idx), ...
        'VariableNames', ["tick","events","rebuild_ms","convert_ms","layers_ms"]);
    L = src.Detector.Log; g = groupsummary(L, 'sensor_id', 'median', 'proc_ms'); R.detector_proc_ms = g(:, ["sensor_id","GroupCount","median_proc_ms"]);
    R.objects = struct('detector_log_rows', height(L), 'route_points', numel(src.Map.Route.t_s), 'footprints', numel(src.Map.Footprints), 'pose_subscriptions', S.pose_subscriptions);
end
end

function s = stats(v)
if isempty(v), s = struct('n', 0, 'median', NaN, 'p95', NaN, 'max', NaN); return; end
v = sort(v); s = struct('n', numel(v), 'median', median(v), 'p95', v(ceil(0.95 * numel(v))), 'max', v(end));
end
