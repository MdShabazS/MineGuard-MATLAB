function [sys, eng, stats] = mgv2SensorDemo(varargin)
%MGV2SENSORDEMO Live mission with time-synchronised RGB, thermal, LiDAR and virtual GNSS/INS (V2-005).
%   SIMULATION ONLY: synthetic sensors on a synthetic scene; no real camera, LiDAR, GNSS or detection.
%   mgv2SensorDemo                         full mission, 3-D view + RGB + thermal (K legend) + LiDAR + status
%   mgv2SensorDemo('RealTime', 1)          pace to 1x wall time; measured pacing is printed (never faked)
%   mgv2SensorDemo('Environment', "LOW_CONTRAST")   or "OVERCAST"
%   mgv2SensorDemo('Palette', "WHITE_HOT") display palette only (the Kelvin samples are unchanged)
%   mgv2SensorDemo('Shots', [t1 ...], 'ShotDir', folder)   PNG screenshots at these SIMULATION times
%   mgv2SensorDemo('MaxTicks', n, 'SceneEvery', 4)
%   mgv2SensorDemo('SensorConfig', cfg)    e.g. cfg.THERMAL_LWIR.dropout_model.intervals_s = [30 35]
%   [sys, eng, stats] = mgv2SensorDemo(...)
%
%   From the repository root:  addpath('v2/matlab'); mgv2SensorDemo
%   One engine clock drives everything. Every panel shows the sample's own t_s/tick; a panel whose last
%   sample is older than its period is flagged STALE (it is never re-stamped).
p = inputParser;
p.addParameter('RealTime', 0); p.addParameter('Environment', "DAY_CLEAR"); p.addParameter('Palette', "IRONBOW");
p.addParameter('Shots', []); p.addParameter('ShotDir', ""); p.addParameter('MaxTicks', inf); p.addParameter('SceneEvery', 4);
p.addParameter('Visible', "on"); p.addParameter('SensorConfig', []);
p.parse(varargin{:}); o = p.Results;
world = mgv2.scene.buildWorld(); mc = mgv2.mission.defaultConfig();
sc0 = o.SensorConfig; if isempty(sc0), sc0 = mgv2.sensors.defaultSensorConfig(); end
sys = mgv2.sensors.SensorSystem(world, mc, SensorConfig=sc0, Environment=mgv2.sensors.defaultEnvironment(o.Environment));
eng = mgv2.engine.MissionEngine(mc, mgv2.scene.terrainProvider(world));
fprintf('\n=== MineGuard V2-005 synchronised virtual sensors — SIMULATION ONLY ===\n');
fprintf('run %s | seed %d | dt %.3f s | RGB %g Hz, thermal %g Hz, LiDAR %g Hz, nav %g Hz | env %s\n', mc.run_id, mc.seed, mc.dt_s, ...
    sys.Config.RGB_NADIR.rate_hz, sys.Config.THERMAL_LWIR.rate_hz, sys.Config.LIDAR_TERRAIN.rate_hz, sys.Config.VIRTUAL_GNSS_INS.rate_hz, o.Environment);
f = figure('Name', 'MineGuard V2-005 — synchronised virtual sensors (SIMULATION)', 'Color', [0.1 0.11 0.13], ...
    'Position', [30 30 1560 900], 'Visible', o.Visible, 'NumberTitle', 'off');
p3 = uipanel(f, 'Units', 'normalized', 'Position', [0 0.04 0.52 0.89], 'BorderType', 'none', 'BackgroundColor', [0.58 0.72 0.86]);
p2 = uipanel(f, 'Units', 'normalized', 'Position', [0.52 0.04 0.48 0.89], 'BorderType', 'none', 'BackgroundColor', [0.1 0.11 0.13]);
ax3 = axes(p3, 'Position', [0 0 1 1]);           % the panel clips the perspective 3-D view to its area
r = mgv2.scene.SceneRenderer(world, Parent=ax3); r.setCameraMode("follow");
tl = tiledlayout(p2, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axR = nexttile(tl, 1); axT = nexttile(tl, 2); axL = nexttile(tl, 3); axS = nexttile(tl, 4);
H = struct();
H.rgb = image(axR, zeros(240, 320, 3, 'uint8')); axis(axR, 'image', 'off'); H.rgbT = title(axR, 'RGB\_NADIR', 'Color', 'w', 'FontSize', 8);
H.th = image(axT, zeros(120, 160, 3, 'uint8')); axis(axT, 'image', 'off'); H.thT = title(axT, 'THERMAL\_LWIR', 'Color', 'w', 'FontSize', 8);
[~, cm0] = mgv2.sensors.thermalPalette(300, o.Palette, [299 301]); colormap(axT, cm0); H.cb = colorbar(axT, 'Color', 'w');
H.cb.Label.String = 'apparent temperature [K] (display palette only)';
H.li = scatter3(axL, NaN, NaN, NaN, 6, NaN, 'filled'); axis(axL, 'equal'); grid(axL, 'on'); view(axL, -35, 35);
set(axL, 'Color', [0.08 0.08 0.1], 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w'); colormap(axL, parula);
xlabel(axL, 'E [m]'); ylabel(axL, 'N [m]'); zlabel(axL, 'U [m]'); H.liT = title(axL, 'LIDAR\_TERRAIN (ENU points)', 'Color', 'w', 'FontSize', 8);
axis(axS, 'off'); H.st = text(axS, 0, 1, '', 'Color', 'w', 'FontName', 'Consolas', 'FontSize', 9, 'VerticalAlignment', 'top', 'Interpreter', 'none');
last = struct(); pal = string(o.Palette);
    function onSample(s)
        last.(char(s.sensor_id)) = struct('tick', double(s.tick_id), 't', s.t_s, 'valid', s.valid, 'reason', s.invalid_reason);
        switch s.sensor_id
            case "RGB_NADIR"
                H.rgb.CData = s.image_rgb_uint8;
                H.rgbT.String = sprintf('RGB_NADIR 320x240\nt=%.2f s  tick %d  %s', s.t_s, s.tick_id, ternary(s.valid, "VALID", s.invalid_reason));
                H.rgbT.Interpreter = 'none';
            case "THERMAL_LWIR"
                if any(s.valid_pixel_mask(:))
                    [img, cm, lim] = mgv2.sensors.thermalPalette(s.temperature_K, pal);
                    H.th.CData = img; colormap(axT, cm); clim(axT, lim); H.cb.Visible = 'on';
                else
                    H.th.CData = uint8(64 * ones(120, 160, 3));   % SENSOR OFFLINE placeholder (no numbers invented)
                    H.cb.Visible = 'off';                           % no stale temperature scale while offline
                end
                H.thT.String = sprintf('THERMAL_LWIR 160x120 apparent K\nt=%.2f s  tick %d  %s', s.t_s, s.tick_id, ternary(s.valid, "VALID", s.invalid_reason + " (SIMULATED)"));
                H.thT.Interpreter = 'none';
            case "LIDAR_TERRAIN"
                v = s.valid_ray_mask; P = s.points_enu_m(v, :);
                set(H.li, 'XData', P(:,1), 'YData', P(:,2), 'ZData', P(:,3), 'CData', P(:,3));
                H.liT.String = sprintf('LIDAR_TERRAIN %d/%d returns\nt=%.2f s  tick %d  AGL(obs) %.2f m', s.return_count, numel(v), s.t_s, s.tick_id, s.altitude_agl_m);
                H.liT.Interpreter = 'none';
        end
    end
sys.subscribe(@onSample);
sys.attach(eng); eng.start();
shots = sort(o.Shots(:))'; si = 1; tw = tic; late = 0; nScene = 0; sceneMs = zeros(0, 1); wall60 = NaN; nShots = 0;
if strlength(string(o.ShotDir)) > 0 && ~isfolder(o.ShotDir), mkdir(o.ShotDir); end
while eng.TickId < o.MaxTicks
    if o.RealTime > 0
        lag = eng.time() / o.RealTime - toc(tw);
        if lag > 0, pause(lag); elseif lag < -0.05, late = late + 1; end
    end
    if ~eng.step(), break; end
    s = eng.snapshot();
    shotNow = si <= numel(shots) && s.t_s >= shots(si);
    if mod(s.tick_id, o.SceneEvery) == 0 || eng.isTerminal() || shotNow
        tu = tic; r.update(s); nScene = nScene + 1;
        H.st.String = statusText(sys, s, last, toc(tw));
        drawnow limitrate; sceneMs(end+1, 1) = 1e3 * toc(tu); %#ok<AGROW>
    end
    if isnan(wall60) && s.t_s >= 60, wall60 = toc(tw); end
    if shotNow && strlength(string(o.ShotDir)) > 0
        drawnow; fn = fullfile(o.ShotDir, sprintf('V2-005-live-t%06.2f-tick%04d-%s.png', s.t_s, s.tick_id, s.phase));
        exportapp(f, fn); fprintf('  screenshot %s\n', fn); si = si + 1; nShots = nShots + 1;
    end
end
wall = toc(tw); L = sys.Log;
ss = sort(sceneMs);
stats = struct('phase', eng.Phase, 'sim_s', eng.time(), 'wall_s', wall, 'sim_to_wall', eng.time() / wall, 'ticks', eng.TickId, ...
    'late_ticks', late, 'scene_updates', nScene, 'scene_every', o.SceneEvery, 'screenshots', nShots, ...
    'scene_update_median_ms', median(ss), 'scene_update_p95_ms', ss(max(1, ceil(0.95 * numel(ss)))), 'scene_update_max_ms', ss(end), ...
    'scene_stalls_over_100ms', nnz(ss > 100), 'wall_at_60s_sim', wall60, ...
    'invalid_samples', nnz(~sys.Log.valid), 'emitted_samples', height(sys.Log));
for id = sys.Order
    g = sort(L.gen_ms(L.sensor_id == id)); k = L.sensor_id == id;
    stats.(char(id)) = struct('samples', nnz(k), 'valid', nnz(L.valid(k)), 'median_ms', median(g), 'p95_ms', g(max(1, ceil(0.95 * numel(g)))), 'max_ms', g(end));
    fprintf('  %-17s samples %4d valid %4d | generation median %6.1f ms p95 %6.1f max %6.1f\n', id, nnz(k), nnz(L.valid(k)), median(g), stats.(char(id)).p95_ms, g(end));
end
fprintf(['result: %s | SceneEvery %d | sim %.2f s, wall %.2f s (x%.3f) | 60 s sim reached at %.2f s wall | ticks %d | ', ...
    'scene updates %d (scheduled; NOT measured screen FPS): median %.1f ms p95 %.1f max %.1f, >100 ms %d | screenshots %d | samples %d, invalid %d\n'], ...
    stats.phase, o.SceneEvery, stats.sim_s, stats.wall_s, stats.sim_to_wall, wall60, stats.ticks, nScene, stats.scene_update_median_ms, ...
    stats.scene_update_p95_ms, stats.scene_update_max_ms, stats.scene_stalls_over_100ms, nShots, stats.emitted_samples, stats.invalid_samples);
end

function txt = statusText(sys, s, last, wall)
lines = sprintf('SIMULATION  t_sim %7.2f s  tick %5d  %s\nwall %7.2f s  sim/wall %.2f\n\n', s.t_s, s.tick_id, s.phase, wall, s.t_s / max(wall, eps));
lines = [lines sprintf('%-17s %6s %8s %-7s %s\n', 'channel', 'tick', 't_s', 'state', 'reason')];
for id = sys.Order
    if isfield(last, char(id))
        q = last.(char(id)); age = s.tick_id - q.tick; stale = age > sys.Period.(id);
        st = ternary(stale, "STALE", ternary(q.valid, "VALID", "INVALID"));
        lines = [lines sprintf('%-17s %6d %8.2f %-7s %s\n', id, q.tick, q.t, st, q.reason)]; %#ok<AGROW>
    else
        lines = [lines sprintf('%-17s %6s %8s %-7s\n', id, '-', '-', 'NONE')]; %#ok<AGROW>
    end
end
L = sys.Log; lines = [lines sprintf('\nsamples emitted: %d   invalid: %d', height(L), nnz(~L.valid))];
txt = lines;
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
