function rec = demo_record(outDir)
%DEMO_RECORD Start a recorded Windows demonstration for a human witness. SIMULATION ONLY.
%   rec = demo_record()            from the repository root; writes to v2/evidence/V2-010/demo_<UTC time>/
%   rec.shot("03_rgb_expanded")    saves a screenshot of the dashboard at any moment
%   rec.finish()                   saves the log and a closing screenshot, and stops the diary
%   Exports go to <tempdir>/MineGuard-demo-export (too large for git); the folder name is printed in the log.
%   It records the environment (git commit, clean tree, MATLAB version, toolboxes, OS, seed) and keeps a diary of the
%   Command Window. It only opens the normal dashboard (paced 1x, real detector): it presses nothing and decides
%   nothing. The person watching fills in windows_demo_witness.md; this helper never writes a witness statement.
if nargin < 1
    outDir = fullfile('v2', 'evidence', 'V2-010', "demo_" + string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyyMMdd''T''HHmmss''Z''')));
end
[~, sha] = system('git rev-parse HEAD'); [~, st] = system('git status --short');   % before this helper writes anything
if ~isfolder(outDir), mkdir(outDir); end
diary(fullfile(outDir, 'command_window.log')); diary on
addpath(fullfile(pwd, 'v2', 'matlab'));
v = ver; tb = strjoin(string({v.Name}) + " " + string({v.Version}), "; ");
env = struct('git_commit', strtrim(string(sha)), 'git_status_short', strtrim(string(st)), 'matlab', string(version), ...
    'computer', string(computer), 'os', string(getenv('OS')), 'started_utc', string(datetime('now', 'TimeZone', 'UTC')), 'toolboxes', tb);
fid = fopen(fullfile(outDir, 'environment.json'), 'w'); fwrite(fid, jsonencode(env, 'PrettyPrint', true)); fclose(fid);
fprintf('Recording to %s\ncommit %s, tree clean: %d\n', outDir, env.git_commit, strlength(env.git_status_short) == 0);
exportRoot = fullfile(tempdir, 'MineGuard-demo-export');      % a full package is about 276 MB: kept out of the repository
app = mgv2MissionControl('ExportRoot', exportRoot);
fprintf('Seed %d, run %s. Follow v2/docs/V2_FINAL_DEMO_SCRIPT.md. Use rec.shot("name") for screenshots, rec.finish() at the end.\n', ...
    app.Session.MissionConfig.seed, app.Session.MissionConfig.run_id);
rec = struct('app', app, 'dir', outDir, 'shot', @(name) snap(app, outDir, name), 'finish', @() done(app, outDir));
end

function snap(app, outDir, name)
if isvalid(app), exportapp(app.Figure, fullfile(outDir, string(name) + ".png")); fprintf('saved %s.png\n', name); end
end

function done(app, outDir)
if isvalid(app)
    snap(app, outDir, "99_final");
    v = app.Session.view(false);
    fprintf('final: phase %s, tick %d, scenario %s, mode %s, last export %s\n', v.pose.phase, v.pose.tick_id, v.scenario, v.mode, app.LastExport);
end
diary off; fprintf('Log saved in %s. Fill in windows_demo_witness.md yourself.\n', outDir);
end
