function v21_demo_check(out)
%V21_DEMO_CHECK Real V2.1 application flows on Windows: setup, lock, full blind flight, post-run evaluation. SIMULATION ONLY.
%   v21_demo_check(outFolder)   from the repository root. Writes v21_demo_check.txt, screenshots and per-case results.
%   Unpaced (RealTime 0) so it measures behaviour, not speed. Each PASS/FAIL/INFO line is read from the running app.
%   Detection numbers are whatever the frozen V2-006 detector produced: they are reported, never asserted.
if nargin < 1, out = pwd; end
if ~isfolder(out), mkdir(out); end
addpath(fullfile(pwd, 'v2', 'matlab')); addpath(fullfile(pwd, 'v2_1', 'matlab'));
fid = fopen(fullfile(out, 'v21_demo_check.txt'), 'w'); c0 = onCleanup(@() fclose(fid));
np = 0; nf = 0; root = fullfile(out, 'exports'); if isfolder(root), rmdir(root, 's'); end
    function check(ok, msg)
        if ok, fprintf(fid, 'PASS  %s\n', msg); np = np + 1; else, fprintf(fid, 'FAIL  %s\n', msg); nf = nf + 1; end
    end
    function info(msg), fprintf(fid, 'INFO  %s\n', msg); end
    function shot(fig, name), drawnow; pause(0.5); exportapp(fig, fullfile(out, name)); end
[~, sha] = system('git rev-parse HEAD'); [~, st] = system('git status --short');
info("git " + strtrim(string(sha)) + " clean=" + isempty(strtrim(st)) + " | " + string(version));

cases = struct('name', {"manual_rocky", "random_dryflats", "target_free", "no_signature"}, ...
    'preset', {"ROCKY_UPLAND", "DRY_FLATS", "TRAINING_FIELD_A", "TRAINING_FIELD_A"}, ...
    'mode', {"MANUAL", "RANDOM", "NONE", "MANUAL"});
for k = 1:numel(cases)
    cs = cases(k); fprintf(fid, '\n== %s (%s, %s)\n', cs.name, cs.preset, cs.mode);
    try
        runCase(k, cs);
    catch err
        check(false, sprintf('%s stopped: %s (%s)', cs.name, err.message, err.identifier));
        fprintf(fid, '%s\n', getReport(err, 'extended', 'hyperlinks', 'off'));
        close all force;
    end
end

    function runCase(k, cs)
    L = mgv21MissionControl('RealTime', 0, 'Visible', "on", 'ExportRoot', fullfile(root, cs.name)); S = L.Setup;
    S.selectPreset(cs.preset);
    if cs.name == "manual_rocky", S.setGrid("line_spacing_m", 8); S.setGrid("heading_deg", 0); end
    check(S.RouteVisible && strlength(S.ValidationText) >= 0, sprintf('route previewed for %s', cs.preset));
    S.setMode(cs.mode);
    P = S.Pub.mission.survey_polygon_enu_m; ctr = mean(P, 1); d = 0.22 * (max(P) - min(P));
    switch cs.name
        case "manual_rocky"
            S.setSignature("VISIBLE_DISTURBANCE");
            for xy = [ctr; ctr + [d(1) 0]; ctr - [d(1) 0]; ctr + [0 d(2)]]', S.clickMap(xy(1), xy(2)); end
            S.setSignature("NONE"); S.clickMap(ctr(1) - d(1), ctr(2) - d(2));
            S.setTool("MOVE"); S.clickMap(ctr(1) + d(1), ctr(2)); S.clickMap(ctr(1) + d(1), ctr(2) - d(2));
            S.setTool("DELETE"); S.clickMap(ctr(1), ctr(2) + d(2)); S.setTool("ADD");
            info(sprintf('manual targets after add x5, move x1, delete x1: %d (markers drawn %d)', S.NumManualTargets, S.NumSetupMarkers));
        case "random_dryflats"
            S.setRandom(8, 2101);
        case "no_signature"
            S.setSignature("NONE"); S.clickMap(ctr(1), ctr(2));
    end
    shot(S.Figure, sprintf('v21_%d_%s_setup.png', k, cs.name));
    ok = S.lockAndStart();
    check(ok && S.Phase == "LOCKED" && S.NumSetupMarkers == 0, 'locked: every target marker removed, editing disabled');
    ctl = L.Controller; app = ctl.App; s = app.Session;
    check(mgv2.run.digest(s.World) == mgv2.run.digest(mgv21.scenario.buildWorld(S.Pub)), 'flight world is the selected preset world');
    check(isequal(s.MissionConfig.survey_polygon_enu_m, S.Pub.mission.survey_polygon_enu_m) && s.MissionConfig.line_spacing_m == S.Pub.mission.line_spacing_m, ...
        sprintf('flight uses the selected boundary and grid (spacing %.1f m, heading %.0f deg)', s.MissionConfig.line_spacing_m, s.MissionConfig.survey_heading_deg));
    t0 = tic; app.command("start");
    info(sprintf('flight: phase %s at tick %d, %.0f s wall', s.Engine.Phase, s.Engine.TickId, toc(t0)));
    check(s.state() == "ENDED", 'mission reached a terminal phase');
    try, mgv21.scenario.assertPublic(s.view(), "view"); mgv21.scenario.assertPublic(s.evidenceContext(), "context"); check(true, 'no private name in the live view or evidence context');
    catch err, check(false, "truth firewall: " + err.message); end
    shot(app.Figure, sprintf('v21_%d_%s_dashboard_end.png', k, cs.name));
    R = ctl.LastEvaluation;
    check(~isempty(R) && numel(ctl.Views) == 1, 'post-run evaluation opened once, after the end');
    info(sprintf('RESULT %s: events %d, targets %d, TP %d, FP %d, FN %d (FN no-signature %d), precision %s, recall %s', ...
        cs.name, R.n_events, R.n_targets, R.TP, R.FP, R.FN, R.FN_no_signature, num2str(R.precision), num2str(R.recall)));
    check(R.TP + R.FN == R.n_targets && R.TP + R.FP == R.n_events, 'evaluation counts are consistent');
    if R.n_targets == 0, check(isnan(R.recall), 'zero targets: recall undefined (NaN), not 0 or 100 %'); end
    if R.n_events == 0, check(isnan(R.precision), 'zero events: precision undefined (NaN)'); end
    shot(ctl.Views{1}.Figure, sprintf('v21_%d_%s_evaluation.png', k, cs.name));
    f = app.exportRun(); pkg = mgv2.run.verifyPackage(f);
    check(string(pkg.manifest.schema_version) == "mg-v2-runpkg/1.1", 'export is mg-v2-runpkg/1.1 and verifies');
    try, mgv21.scenario.assertPublic(rmfield(pkg, 'samples'), "package"); check(true, 'operator package passes the V2.1 truth firewall');
    catch err, check(false, "package firewall: " + err.message); end
    pf = ctl.savePrivateEvaluation(fullfile(out, 'private', cs.name)); check(isfile(pf) && ~startsWith(pf, f), 'private evaluation file written separately, on request');
    info(sprintf('dashboard valid before replay: %d', isvalid(app)));
    app.replay(f); app.command("start"); s = app.Session;
    check(s.Mode == "REPLAY" && app.LastReplay.match && numel(ctl.Views) == 1, "replay of recorded data: " + app.LastReplay.detail + "; not re-evaluated");
    delete(L);
    end

fprintf(fid, '\n== original V2 entry point\n');
app = mgv2MissionControl('RealTime', 0, 'Visible', "on", 'MaxTicksPerRun', 200, 'ExportRoot', fullfile(root, 'v2')); app.command("start"); app.command("abort");
pkg = mgv2.run.verifyPackage(app.exportRun());
check(isequal(app.Session.SceneConfig, mgv2.scene.defaultSceneConfig()) && string(pkg.manifest.schema_version) == "mg-v2-runpkg/1.0" && isempty(app.OnRunEnded), ...
    'mgv2MissionControl: default V2 world, no evaluation hook, export still mg-v2-runpkg/1.0');
delete(app);
check(isempty(findall(groot, 'Type', 'figure')), 'all windows closed');
fprintf(fid, 'TOTAL pass=%d fail=%d\n', np, nf);
end
