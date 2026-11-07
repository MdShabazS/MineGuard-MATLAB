function app_check_v2008(out)
%APP_CHECK_V2008 Real dashboard: export, replay, mission fault and invalid rays, with screenshots. SIMULATION ONLY.
%   app_check_v2008(outFolder)   from the repository root after addpath('v2/matlab'). Writes app_check_v2008.txt and PNGs.
%   Runs unpaced (RealTime 0) so it measures behaviour, not speed. Every line is PASS, FAIL or INFO from what the app shows.
if nargin < 1, out = pwd; end
if ~isfolder(out), mkdir(out); end
fid = fopen(fullfile(out, 'app_check_v2008.txt'), 'w'); c = onCleanup(@() fclose(fid));
np = 0; nf = 0;
    function check(ok, msg)
        if ok, fprintf(fid, 'PASS  %s\n', msg); np = np + 1; else, fprintf(fid, 'FAIL  %s\n', msg); nf = nf + 1; end
    end
    function info(msg), fprintf(fid, 'INFO  %s\n', msg); end
    function shot(app, name), drawnow; pause(0.5); exportapp(app.Figure, fullfile(out, name)); end
    function press(b), b.ButtonPushedFcn(b, []); drawnow; end

root = fullfile(out, 'packages'); if isfolder(root), rmdir(root, 's'); end
[~, sha] = system('git rev-parse HEAD'); info("git " + strtrim(string(sha)) + " | " + string(version));

% 1. nominal run with the real detector, export, replay
app = mgv2MissionControl('RealTime', 0, 'ExportRoot', root); B = app.Controls.Buttons;
check(string(B.export.Enable) == "off", 'EXPORT disabled before a run');
press(B.start);
check(app.Session.Engine.Phase == "COMPLETE", "nominal run COMPLETE at tick " + app.Session.Engine.TickId);
nEv = numel(app.Session.view().events); info(sprintf('%d SUSPECTED events listed (live scene has no synthetic target)', nEv));
check(string(B.export.Enable) == "on", 'EXPORT enabled after the run ended');
t0 = tic; press(B.export); te = toc(t0);
check(isfolder(app.LastExport), sprintf('export written in %.1f s: %s', te, app.LastExport));
check(contains(string(app.Controls.Notice.Text), "Exported"), 'control bar reports the export');
check(string(B.export.Enable) == "off", 'EXPORT disabled after one export');
d = dir(fullfile(app.LastExport, '**', '*')); d = d(~[d.isdir]); info(sprintf('package: %d files, %.1f MB', numel(d), sum([d.bytes]) / 1e6));
shot(app, 'v8_01_exported.png');
t0 = tic; pkg = mgv2.run.verifyPackage(app.LastExport); info(sprintf('verifyPackage passed in %.1f s', toc(t0)));
check(pkg.manifest.synthetic_targets_in_scene == 0 && pkg.manifest.simulation_only, 'manifest: simulation only, no synthetic target');
press(B.replay);
check(app.Session.Mode == "REPLAY" && contains(string(app.Controls.Readout.Text), "REPLAY (recorded, not simulated)"), 'REPLAY loaded and labelled');
shot(app, 'v8_02_replay_ready.png');
press(B.start);
check(app.Session.Engine.Phase == "COMPLETE" && app.Session.Engine.TickId == pkg.poses.tick_id(end), 'replay reached the recorded last tick');
check(app.LastReplay.match, "replay check: " + app.LastReplay.detail);
check(isa(app.Session.Sensors, 'mgv2.replay.PlaybackSensors'), 'replay used recorded samples, no sensor simulation');
shot(app, 'v8_03_replay_done.png');
t0 = tic; r = mgv2.run.reproduce(pkg);
check(r.match, sprintf('reproduction: poses %d, samples %d/%d, end %d (%.0f s)', r.poses_equal, r.samples_equal, r.samples_compared, r.end_equal, toc(t0)));

% 2. mission fault
press(B.reset); check(app.Session.Mode == "REPLAY" && app.Session.state() == "READY", 'RESET after a replay restarts the replay at tick 0');
app.configure("Mission fault (timeout)", 2002);
check(app.Session.Mode == "LIVE", 'scenario choice returns to a live run');
press(B.start); p = app.Session.pose();
check(app.Session.Engine.Phase == "FAILED" && p.fault_code == "TIMEOUT", "mission fault: FAILED with TIMEOUT at tick " + p.tick_id);
check(contains(string(app.Session.view().fault_message), "not complete"), "fault message shown: " + app.Session.view().fault_message);
shot(app, 'v8_04_mission_fault.png');

% 3. invalid rays
delete(app); app =mgv2MissionControl('RealTime', 0, 'MaxTicksPerRun', 900, 'ExportRoot', root); app.configure("Invalid rays", 2002);
press(app.Controls.Buttons.start);
L = app.Session.Recorder.samples("LIDAR_TERRAIN"); q = cellfun(@(s) s.quality, L);
check(sum([q.out_of_range_rays]) > 0 && sum([q.dropout_rays]) > 0, sprintf('invalid rays: %d out of range, %d dropped, ranges NaN', sum([q.out_of_range_rays]), sum([q.dropout_rays])));
f = cellfun(@(s) s.quality.valid_pixel_fraction, app.Session.Recorder.samples("RGB_NADIR"));
check(any(f > 0 & f < 1), sprintf('RGB pixels beyond 16 m invalid: valid fraction %.2f to %.2f in flight', min(f(f > 0)), max(f)));
shot(app, 'v8_05_invalid_rays.png');

% 4. tampered package refused on screen
bad = fullfile(out, 'tampered'); if isfolder(bad), rmdir(bad, 's'); end
copyfile(pkg.folder, bad); delete(fullfile(bad, 'telemetry', 'phases.csv'));
app.command("abort"); app.replay(bad);
check(app.Session.Mode == "LIVE" && contains(string(app.Controls.Notice.Text), "REPLAY REFUSED"), "tampered package refused: " + string(app.Controls.Notice.Text));
shot(app, 'v8_06_tampered_refused.png');
delete(app); rmdir(bad, 's');
check(isempty(findall(groot, 'Type', 'figure')) && isempty(timerfindall), 'close: no figures or timers left');
fprintf(fid, 'TOTAL pass=%d fail=%d\n', np, nf);
end
