function T = d5_landmarkSizeOnFrames(ticks)
%D5_LANDMARKSIZEONFRAMES Simulated DEMO FIXTURE frames: public 1.2 m landmarks and candidate counts per form. Exploratory.
%   A landmark is a public, high-contrast painted disc, not a target. Counts per frame describe behaviour; they are not
%   false-alarm rates, because nothing here says which components are wrong.
g = mgv2.eval.demoFixtureGroup(); [pub, fwd] = mgv2.eval.buildScenario(g); cfg = mgv2.detect.defaultDetectorConfig();
sys = mgv2.sensors.SensorSystem(pub.world, pub.mission, SensorConfig=pub.sensor_config, Environment=pub.environment, SurfaceFeatures=fwd, KeepFrames=5000);
eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world)); sys.attach(eng); eng.start();
while eng.TickId < ticks && ~eng.isTerminal(), eng.step(); end
forms = ["FROZEN_FORM","POLARITY_SPLIT","CLIPPED"]; rows = {}; kept = zeros(0, 3); total = zeros(0, 3); tms = zeros(0, 3); fr = 0;
L = pub.world.landmarks; 
for t = 0:20:ticks
    S = sys.samplesAt(t); 
    for q = 1:numel(S)
        s = S{q}; if s.sensor_id ~= "RGB_NADIR" || ~s.valid, continue; end
        fr = fr + 1; cam = struct('fx', s.focal_lengths_px(1), 'fy', s.focal_lengths_px(2), 'cx', s.principal_point_px(1), 'cy', s.principal_point_px(2));
        I = double(s.image_rgb_uint8) / 255; k = zeros(1, 3); n = zeros(1, 3); tm = zeros(1, 3);
        for f = 1:3
            tt = tic; C = mgv2x.detect.rgbResidualCandidates(I, s.valid_pixel_mask, forms(f)); tm(f) = 1e3 * toc(tt); n(f) = numel(C.u_px);
            if isempty(C.u_px), continue; end
            [O, D] = mgv2.scene.pixelRays(cam, s.T_world_sensor, [C.u_px C.v_px]); [P, hit, rng] = mgv2.detect.georegisterRays(pub.world, O, D);
            dia = 2 * sqrt(C.area_px / pi) .* rng / cam.fx; ok = hit & dia >= cfg.size.min_diameter_m & dia <= cfg.size.max_diameter_m; k(f) = nnz(ok);
            for m = reshape(L, 1, [])
                j = find(hit & hypot(P(:,1) - m.xy(1), P(:,2) - m.xy(2)) <= 1.5);
                if isempty(j), continue; end
                [~, b] = max(C.area_px(j)); rows(end+1, :) = {t, m.id, forms(f), dia(j(b)), 2 * m.radius_m, dia(j(b)) <= cfg.size.max_diameter_m}; %#ok<AGROW>
            end
        end
        kept(end+1, :) = k; total(end+1, :) = n; tms(end+1, :) = tm; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', ["tick","landmark","form","measured_d_m","true_d_m","within_size_limit"]);
fprintf('%d RGB frames from DEMO FIXTURE, every 20 ticks to tick %d\n', fr, ticks);
for f = 1:3
    x = T(T.form == forms(f), :);
    fprintf('%-15s all components per frame: median %.0f max %d | within size band: median %.0f max %d | landmark sightings %d, measured d median %.2f m (true 1.20), within limit %.2f | residual time %.1f ms\n', forms(f), median(total(:,f)), max(total(:,f)), median(kept(:,f)), max(kept(:,f)), height(x), median(x.measured_d_m), mean(x.within_size_limit), median(tms(:,f)));
end
end
