function out = mgv2DetectionDemo(opts)
%MGV2DETECTIONDEMO V2-006 offline mission map + SUSPECTED events + evidence inspector (DEMO FIXTURE). SIMULATED.
%   out = mgv2DetectionDemo()                    run the DEMO FIXTURE scenario end to end and show the map
%   out = mgv2DetectionDemo(ShotDir="v2/evidence/V2-006")   also export the figures as PNG (never overwrites)
%   out = mgv2DetectionDemo(EventId="SUS-00296")            inspect that event instead of the strongest fused one
%   The DEMO FIXTURE contains one deliberately strong synthetic surface feature; it demonstrates the
%   pipeline and is EXCLUDED from every accuracy report (see v2/data/V2-006/val_results.csv for the
%   pre-registered VAL result). Scores are uncalibrated; events are SUSPECTED only.
%   EventId is looked up only in the public detector output. This function never reads scenario truth, so
%   it cannot tell whether the selected event matches the fixture: that is an evaluator statement, recorded
%   in the evidence. Without EventId, the strongest fused event is shown, which may be a false alarm.
arguments
    opts.ShotDir (1,1) string = ""
    opts.Run = []          % reuse a previous out.run (redraw only)
    opts.EventId (1,1) string = ""
end
label = "SYNTHETIC DEMO FIXTURE, not VALIDATION evidence";
if isempty(opts.Run), o = mgv2.eval.runScenario(mgv2.eval.demoFixtureGroup(), KeepFrames=4000); else, o = opts.Run; end
f1 = figure('Name', 'V2-006 mission map (SIMULATED)', 'Position', [60 60 900 820], 'Color', 'w');
ax = axes(f1); mgv2.map.MapView(ax, o.world, o.map);
cv = o.map.snapshot().coverage;
annotation(f1, 'textbox', [0.01 0.005 0.98 0.04], 'String', sprintf(['%s | %s | %d SUSPECTED events (uncalibrated, frozen detector %s) | ' ...
    'valid RGB %.0f%%, thermal %.0f%%, LiDAR %.0f%% of planned cells (evidence acquisition, not accuracy)'], ...
    label, o.mission.run_id, numel(o.events), o.detector.Fingerprint, cv.valid_rgb_pct, cv.valid_thermal_pct, cv.valid_lidar_pct), ...
    'EdgeColor', 'none', 'FontSize', 8, 'Interpreter', 'none');
E = o.events;
if opts.EventId == ""
    sc = [E.model_score]; sc([E.detection_basis] ~= "FUSED_RGB_THERMAL") = -inf; [~, k] = max(sc);   % strongest fused event
    how = "strongest fused score (may be a false alarm)";
else
    k = find([E.event_id] == opts.EventId);
    if ~isscalar(k), error('mgv2:EventNotFound', 'Event %s is not in the public detector output.', opts.EventId); end
    how = "explicit public event id";
end
e = E(k);
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
annotation(f2, 'textbox', [0.01 0.005 0.98 0.04], 'String', sprintf('EVIDENCE INSPECTOR (SIMULATED) - %s - selected by %s - crops are from exactly the referenced samples (checksum-verified against the sensor log)', label, how), 'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none');
if strlength(opts.ShotDir) > 0
    if opts.EventId == ""
        names = ["map-demo-fixture.png", "inspector-demo-fixture.png"]; figs = [f1 f2];
    else
        names = "inspector-demo-event-" + opts.EventId + ".png"; figs = f2;
    end
    for q = 1:numel(names)
        p = fullfile(opts.ShotDir, names(q));
        if isfile(p), error('mgv2:EvidenceExists', 'Refusing to overwrite %s.', p); end
        exportgraphics(figs(q), p, 'Resolution', 110);
    end
end
out = struct('run', o, 'inspector', ins, 'selected_event_id', e.event_id, 'selected_by', how, 'label', label, ...
    'map_figure', f1, 'inspector_figure', f2);
end

function v = ternary(c, a, b), if c, v = a; else, v = b; end, end
