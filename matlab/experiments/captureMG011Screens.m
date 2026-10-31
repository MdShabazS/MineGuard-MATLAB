function shots = captureMG011Screens(outDir)
%CAPTUREMG011SCREENS Launch the real dashboard and save PNG screenshots via exportapp (MG-011 evidence).
%   shots = captureMG011Screens(outDir)
%   1 READY first frame, 2 mid replay (paused after a seek), 3 COMPLETE (full run),
%   4 dropout/invalid readings, 5 no-events run. Every screenshot shows the persistent
%   SIMULATION banner. The data come from real makeMG011DemoBundle runs.
if ~exist(outDir, 'dir'), mkdir(outDir); end
shots = strings(0, 1);
rb = makeMG011DemoBundle();
app = mineguard.app.openMissionApp(rb); c = onCleanup(@() app.close()); drawnow; pause(0.5);
shots(end+1) = snap(app, outDir, "MG-011-01-ready.png");
app.seek(rb.poses.t_s(round(end * 0.45))); drawnow; pause(0.3);
shots(end+1) = snap(app, outDir, "MG-011-02-mid-replay-paused.png");
app.setSpeed(20); app.seek(rb.poses.t_s(end - 1)); app.play(); t0 = tic;
while app.State ~= "COMPLETE" && toc(t0) < 30, pause(0.05); end
app.uiHandles().fullrun.Value = true; app.step(); drawnow; pause(0.3);
shots(end+1) = snap(app, outDir, "MG-011-03-complete-full-run.png");
app.close();
rbd = makeMG011DemoBundle(struct('seed', 3002, 'x_max_m', 4, 'y_max_m', 4, 'dropout_probability', 0.3));
a2 = mineguard.app.openMissionApp(rbd); c2 = onCleanup(@() a2.close()); a2.seek(rbd.poses.t_s(end)); drawnow; pause(0.3);
shots(end+1) = snap(a2, outDir, "MG-011-04-dropout-invalid-readings.png");
a2.close();
rbe = rb; rbe.events = rbe.events([], :);
a3 = mineguard.app.openMissionApp(rbe); c3 = onCleanup(@() a3.close()); a3.seek(rbe.poses.t_s(end)); drawnow; pause(0.3);
shots(end+1) = snap(a3, outDir, "MG-011-05-no-suspected-events.png");
a3.close();
end

function f = snap(app, d, name)
f = string(fullfile(d, name));
exportapp(app.figureHandle(), f);
end
