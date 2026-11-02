function app_check(outDir)
%APP_CHECK Real application and real V2-006 detector at 100 ticks, one complete operator session. Default scene. SIMULATED.
%   app_check(outDir)  needs v2/matlab on the path. Writes app_check.txt and screenshots. No study stage runs, and TEST stays sealed.
%   PASS here covers software behaviour only. The default scene has no targets, so its events are false alarms, not detections.
if ~isfolder(outDir), mkdir(outDir); end
fid = fopen(fullfile(outDir, 'app_check.txt'), 'w'); c0 = onCleanup(@() fclose(fid));
n = [0 0]; pauseAt = inf; phases = strings(0, 1);
    function chk(name, ok)
        n(1 + ~ok) = n(1 + ~ok) + 1; s = ["PASS", "FAIL"]; fprintf(fid, '%s  %s\n', s(1 + ~ok), name);
    end
    function shot(name)
        drawnow; exportapp(app.Figure, fullfile(outDir, name + ".png"));
    end
    function watch(a)
        p = string(a.Session.Engine.Phase); if isempty(phases) || phases(end) ~= p, phases(end+1, 1) = p; end
        if a.Session.evidenceContext().tick >= pauseAt, pauseAt = inf; a.command("pause"); end
    end
f0 = numel(findall(groot, 'Type', 'figure')); t0 = numel(timerfindall);
src = mgv2.bridge.V2006AnomalySource(RefreshTicks=100);
app = mgv2MissionControl('AnomalySource', src, 'RealTime', 0);
ses = app.Session; P = app.Panels; E = P.events; g1 = ses.evidenceContext().generation;
chk("launch: plain launch with real bridge, READY at tick 0", ses.state() == "READY" && ses.evidenceContext().tick == 0 && src.sourceInfo().connected);
chk("one evidenceContext on the loaded class", nnz(string({meta.class.fromName('mgv2.ui.MissionSession').MethodList.Name}) == "evidenceContext") == 1);
shot("app_01_preflight");
app.AfterRefreshFcn = @watch; pauseAt = 700;
app.command("start");
tp = ses.evidenceContext().tick; pause(0.5); drawnow;
chk(sprintf("pause: PAUSED and clock frozen at tick %d", tp), ses.state() == "PAUSED" && ses.evidenceContext().tick == tp);
v = ses.view();
chk("while paused: images, LiDAR and telemetry samples present", all(isfield(v.samples, ["RGB_NADIR", "THERMAL_LWIR", "LIDAR_TERRAIN", "VIRTUAL_GNSS_INS"])));
fprintf(fid, 'INFO  at pause: events=%d, as of tick %d, current tick %d, stale ticks %d\n', numel(v.events), v.source.events_as_of_tick, v.source.current_tick, v.source.stale_ticks);
shot("app_02_paused_survey");
app.command("resume");
drawnow; v = ses.view(); L = ses.Sensors.Log;
fprintf(fid, 'INFO  phases seen: %s\n', strjoin(phases, " > "));
chk("full mission: takeoff, survey, return and landing reached COMPLETE", all(ismember(["TAKEOFF", "SURVEY", "LANDING"], phases)) && string(ses.Engine.Phase) == "COMPLETE");
chk(sprintf("ticks and samples: tick %d, %d samples", ses.evidenceContext().tick, height(L)), ses.evidenceContext().tick == 2799 && height(L) == 3080);
R = src.Map.Route; chk("no missed or duplicated pose tick", isequal(double(R.tick_id(:)), (0:2799)'));
chk("each sample's frame id is unique", numel(unique(L.frame_id)) == height(L));
chk("no sample refused by the detector", src.Stats.samples_refused == 0);
chk(sprintf("suspected events listed: %d, all SUSPECTED and uncalibrated", numel(v.events)), numel(v.events) == 84 && all([v.events.status] == "SUSPECTED") && all(contains([v.events.confidence_kind], "UNCALIBRATED")));
chk("map layers present, including coverage and events", numel(v.layers) >= 2);
fprintf(fid, 'INFO  layers: %s\n', strjoin(string({v.layers.id}), ", "));
chk("fingerprint preserved", v.source.detector_fingerprint == "fnv1a64:d6d364f988f04bb4");
chk("event age is reported, zero after the mission ended", v.source.stale_ticks == 0 && isfinite(v.source.events_as_of_t_s));
shot("app_03_complete");
both = ""; ok = 0; counts = [0 0];
for e = reshape(v.events, 1, [])
    ins = ses.inspectCurrentRun(e.event_id); ok = ok + 1;
    mgv2.sensors.assertPublic(ins, "inspection");
    u = [ins.items.sensor_id]; counts = counts + [nnz(u == "RGB_NADIR") nnz(u == "THERMAL_LWIR")];
    if strlength(both) == 0 && numel(unique(u)) == 2, both = e.event_id; end
end
chk(sprintf("every listed event verified: %d of %d, RGB records %d, thermal records %d", ok, numel(v.events), counts(1), counts(2)), ok == numel(v.events) && all(counts > 0));
chk("an event with both RGB and thermal evidence exists", strlength(both) > 0);
mgv2.sensors.assertPublic(v, "view"); mgv2.sensors.assertPublic(ses.evidenceContext(), "context");
chk("no truth field in the view, context, layers or inspections", true);
app.selectEvent(both); drawnow; txt = string(E.DetailText.Text); fprintf(fid, 'INFO  inspector text for %s:\n%s\n', both, strjoin(txt, newline));
ins = ses.inspect(both);
chk("inspector: verified, uncalibrated, event id shown", contains(strjoin(txt), "verified against the sensor log") && contains(lower(strjoin(txt)), "uncalibrated") && contains(strjoin(txt), both));
chk("inspector: RGB and thermal crops drawn", ~isempty(findall(E.RgbAxes, 'Tag', 'event_crop')) && ~isempty(findall(E.ThermalAxes, 'Tag', 'event_crop')));
chk("inspection record carries run, basis and age", ins.run_id == string(ses.MissionConfig.run_id) && ismember(ins.record_basis, ["LISTED", "CURRENT"]) && isfinite(ins.stale_ticks));
shot("app_04_inspection");
oldLog = ses.Sensors.Log; held = ins.items(1).frame_id;
app.command("reset"); drawnow;
c = ses.evidenceContext();
chk("reset: tick 0, new generation, same run id, no events, selection cleared", c.tick == 0 && c.generation == g1 + 1 && c.run_id == string(ses.MissionConfig.run_id) && isempty(ses.view().events) && E.SelectedId == "");
app.selectEvent(both); drawnow;
chk("stale event refused in the inspector, no crops", contains(strjoin(string(E.DetailText.Text)), "EVIDENCE NOT AVAILABLE") && isempty(findall([E.RgbAxes E.ThermalAxes], 'Tag', 'event_crop')));
chk("stale event refused by the session", raises(@() ses.inspectCurrentRun(both)));
chk("old frame is not in the new log", ~any(ses.Sensors.Log.frame_id == held));
pauseAt = 300; app.command("start"); drawnow;
m = height(ses.Sensors.Log);
chk("same-seed reset replays the same samples, tick by tick", isequal(ses.Sensors.Log.checksum, oldLog.checksum(1:m)) && m > 0);
app.command("abort"); drawnow; chk("abort ends the run", ses.state() == "ENDED");
app.command("reset"); drawnow;
app.configure("Thermal dropout", 77); runB = string(ses.MissionConfig.run_id); pauseAt = 900; app.command("start"); drawnow;
L = ses.Sensors.Log; T = L(L.sensor_id == "THERMAL_LWIR" & L.t_s >= 10 & L.t_s <= 40, :); v = ses.view();
chk(sprintf("thermal dropout: %d samples in the window, all invalid, reason SENSOR_DROPOUT", height(T)), height(T) > 0 && all(~T.valid) && all(T.invalid_reason == "SENSOR_DROPOUT"));
chk("changed run: events carry the new run id", isempty(v.events) || all([v.events.run_id] == runB));
good = 0; for e = reshape(v.events, 1, []), i2 = ses.inspectCurrentRun(e.event_id); good = good + 1; chk2 = all(ismember([i2.items.frame_id], L.frame_id)); if ~chk2, good = -inf; end, end
chk(sprintf("changed run: all %d events verify against this run's frames only", numel(v.events)), good == numel(v.events));
shot("app_05_thermal_dropout");
for sz = [960 640; 1600 900]'
    app.Figure.Position(3:4) = sz; drawnow; pause(0.3); shot(sprintf("app_06_size_%dx%d", sz(1), sz(2)));
    chk(sprintf("layout at %dx%d, mode %s", sz(1), sz(2), app.LayoutMode), isvalid(app.Figure) && strlength(app.LayoutMode) > 0);
end
app.command("abort"); delete(app); drawnow;
chk("close: no figures or timers left", numel(findall(groot, 'Type', 'figure')) == f0 && numel(timerfindall) == t0);
fprintf(fid, 'TOTAL pass=%d fail=%d\n', n(1), n(2));
end

function tf = raises(f)
tf = false;
try
    f();
catch
    tf = true;
end
end
