function out = mgv2DetectionDemo(opts)
%MGV2DETECTIONDEMO V2-006 offline mission map + SUSPECTED events + evidence inspector (DEMO FIXTURE). SIMULATED.
%   out = mgv2DetectionDemo()                    run the DEMO FIXTURE scenario end to end and show the map
%   out = mgv2DetectionDemo(ShotDir="v2/evidence/V2-006")   also export the figures as PNG
%   The DEMO FIXTURE contains one deliberately strong synthetic surface feature; it demonstrates the
%   pipeline and is EXCLUDED from every accuracy report (see v2/data/V2-006/val_results.csv for the
%   pre-registered VAL result). Scores are uncalibrated; events are SUSPECTED only.
arguments
    opts.ShotDir (1,1) string = ""
    opts.Run = []          % reuse a previous out.run (redraw only)
end
if isempty(opts.Run), o = mgv2.eval.runScenario(mgv2.eval.demoFixtureGroup(), KeepFrames=4000); else, o = opts.Run; end
f1 = figure('Name', 'V2-006 mission map (SIMULATED)', 'Position', [60 60 900 820], 'Color', 'w');
ax = axes(f1); mgv2.map.MapView(ax, o.world, o.map);
cv = o.map.snapshot().coverage;
annotation(f1, 'textbox', [0.01 0.005 0.98 0.04], 'String', sprintf(['%s | %d SUSPECTED events (uncalibrated, frozen detector %s) | ' ...
    'valid RGB %.0f%%, thermal %.0f%%, LiDAR %.0f%% of planned cells (evidence acquisition, not accuracy)'], ...
    o.mission.run_id, numel(o.events), o.detector.Fingerprint, cv.valid_rgb_pct, cv.valid_thermal_pct, cv.valid_lidar_pct), ...
    'EdgeColor', 'none', 'FontSize', 8, 'Interpreter', 'none');
E = o.events; sc = [E.model_score]; sc([E.detection_basis] ~= "FUSED_RGB_THERMAL") = -inf; [~, k] = max(sc); e = E(k);   % strongest fused event
ins = mgv2.detect.inspectEvent(e, o.detector, o.sensors.Log);
f2 = figure('Name', 'V2-006 evidence inspector (SIMULATED)', 'Position', [80 80 1400 720], 'Color', 'w');
tl = tiledlayout(f2, 2, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
n = 0;
for it = ins.items
    if n == 7, break; end
    n = n + 1; a = nexttile(tl);
    if it.sensor_id == "RGB_NADIR", image(a, it.crop); else, imagesc(a, it.crop); colormap(a, hot); cb = colorbar(a); cb.Label.String = 'apparent T (K)'; end
    axis(a, 'image', 'off');
    title(a, {char(it.sensor_id), sprintf('%s', it.frame_id), sprintf('t = %.2f s, %s %.2f', it.t_s, ...
        ternary(it.sensor_id == "RGB_NADIR", "z", "dT K"), it.strength)}, 'FontSize', 7, 'Interpreter', 'none');
end
a = nexttile(tl, 8, [1 3]); axis(a, 'off');
text(a, 0, 1, cellstr(ins.summary_text), 'VerticalAlignment', 'top', 'FontSize', 8, 'Interpreter', 'none');
annotation(f2, 'textbox', [0.01 0.005 0.98 0.04], 'String', 'EVIDENCE INSPECTOR (SIMULATED) - crops are from exactly the referenced samples (checksum-verified against the sensor log)', 'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold');
if strlength(opts.ShotDir) > 0
    exportgraphics(f1, fullfile(opts.ShotDir, 'map-demo-fixture.png'), 'Resolution', 110);
    exportgraphics(f2, fullfile(opts.ShotDir, 'inspector-demo-fixture.png'), 'Resolution', 110);
end
out = struct('run', o, 'inspector', ins, 'map_figure', f1, 'inspector_figure', f2);
end

function v = ternary(c, a, b), if c, v = a; else, v = b; end, end
