function S = d4_poseAssumption()
%D4_POSEASSUMPTION Reference pose in T_world_sensor against the noisy navigation solution, DEMO FIXTURE, 700 ticks. No detector run.
g = mgv2.eval.demoFixtureGroup(); pub = mgv2.eval.buildScenario(g);
cfg = pub.sensor_config; sys = mgv2.sensors.SensorSystem(pub.world, pub.mission, SensorConfig=cfg, KeepFrames=2000);
eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world)); sys.attach(eng); eng.start();
while eng.TickId < 700 && ~eng.isTerminal(), eng.step(); end
L = eng.poseLog(); e = nan(0, 3);
for t = 1:eng.TickId
    for s = sys.samplesAt(t)
        n = s{1}; if n.sensor_id ~= "VIRTUAL_GNSS_INS" || ~n.valid, continue; end
        i = find(L.tick_id == n.tick_id, 1); e(end+1, :) = n.reported_position_enu_m - L.position_enu_m(i, :); %#ok<AGROW>
    end
end
h = hypot(e(:,1), e(:,2)); S = struct('n', size(e, 1), 'mean_xy', mean(e(:,1:2), 1), 'h_median', median(h), 'h_p95', prctile(h, 95), 'h_max', max(h), 'z_rms', rms(e(:,3)));
sig = hypot(cfg.VIRTUAL_GNSS_INS.params.position_noise_sigma_m(1), cfg.VIRTUAL_GNSS_INS.params.position_bias_sigma_m(1));
fprintf('navigation minus reference position, %d samples: horizontal median %.3f m, p95 %.3f m, max %.3f m; mean offset (%.3f, %.3f) m; vertical rms %.3f m; declared horizontal sigma %.3f m\n', S.n, S.h_median, S.h_p95, S.h_max, S.mean_xy, S.z_rms, sig);
p = 0.10; a = 16; for n = [1 2 5 20 100]
    fprintf('double count, assumed gsd 0.075 m, n=%3d, no scatter: current %.4f m, pose once %.4f m, excess %.1f %%\n', n, sqrt((0.075^2 * (1/12 + 1/(4*pi)) + p^2) / n + p^2), sqrt(0.075^2 * (1/12 + 1/(4*pi)) / n + p^2), 100 * (sqrt((0.075^2 * (1/12 + 1/(4*pi)) + p^2) / n + p^2) / sqrt(0.075^2 * (1/12 + 1/(4*pi)) / n + p^2) - 1));
end
fprintf('Mean offset %.3f m against assumed pose_sigma %.2f m and gate %.1f m\n', norm(S.mean_xy), p, 1.0); S.alt = a;
end
