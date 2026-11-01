function [r, eng, stats] = mgv2SceneDemo(varargin)
%MGV2SCENEDEMO V2-003 3-D scene driven LIVE by the V2-002 mission engine. SIMULATION ONLY.
%   mgv2SceneDemo                          full mission, camera schedule per flight phase
%   mgv2SceneDemo('Camera', "chase")       fixed camera mode (isometric|follow|chase|topdown|orbit)
%   mgv2SceneDemo('RealTime', 1)           pace to 1x wall time (0 = as fast as possible)
%   mgv2SceneDemo('RenderEvery', 2)        redraw every N engine ticks (2 -> 10 Hz scene at dt 0.05 s)
%   mgv2SceneDemo('Wind', true)            seeded wind/gusts (V2-002)
%   mgv2SceneDemo('Shots', [t1 t2 ...], 'ShotDir', folder)   save PNG screenshots at these SIM times
%   [r, eng, stats] = mgv2SceneDemo(...)
%
%   From the repository root:  addpath('v2/matlab'); mgv2SceneDemo
%   The engine owns time; the renderer only displays snapshots. Nothing here is a real aircraft,
%   camera feed or hazard map.
p = inputParser;
p.addParameter('Camera', "schedule"); p.addParameter('RealTime', 0); p.addParameter('RenderEvery', 2);
p.addParameter('Wind', false); p.addParameter('Shots', []); p.addParameter('ShotDir', ""); p.addParameter('Visible', "on");
p.addParameter('MaxTicks', inf);
p.parse(varargin{:}); o = p.Results;
world = mgv2.scene.buildWorld();
cfg = mgv2.mission.defaultConfig();
if o.Wind
    cfg.wind = struct('enabled', true, 'mean_enu_mps', [2.5 1.0 0], 'gust_sigma_mps', 0.8, 'gust_tau_s', 3);
    cfg.run_id = cfg.run_id + "-WIND";
end
eng = mgv2.engine.MissionEngine(cfg, mgv2.scene.terrainProvider(world));
fprintf('\n=== MineGuard V2 3-D scene (V2-003) driven by the live mission engine (V2-002) — SIMULATION ONLY ===\n');
fprintf('world %s seed %d: %d vertices, %d triangles, %d objects | run %s | dt %.3f s | render every %d ticks\n', ...
    world.scene_id, world.seed, size(world.V, 1), size(world.F, 1), height(world.objects), cfg.run_id, cfg.dt_s, o.RenderEvery);
r = mgv2.scene.SceneRenderer(world, Visible=o.Visible);
sched = struct('PREFLIGHT', "orbit", 'TAKEOFF', "orbit", 'CLIMB', "follow", 'TRANSIT', "chase", 'SURVEY', "chase", ...
    'RETURN_HOME', "follow", 'LANDING', "orbit", 'COMPLETE', "orbit", 'FAILED', "follow", 'ABORTED', "follow");
shots = sort(o.Shots(:))'; si = 1;
if strlength(string(o.ShotDir)) > 0 && ~isfolder(o.ShotDir), mkdir(o.ShotDir); end
eng.start(); tw = tic; frame = zeros(0, 1); lastPhase = "";
while eng.TickId < o.MaxTicks
    if o.RealTime > 0
        lag = eng.time() / o.RealTime - toc(tw); if lag > 0, pause(lag); end
    end
    if ~eng.step(), break; end
    s = eng.snapshot();
    if s.phase ~= lastPhase
        fprintf('  t=%7.2f s  %-12s AGL %5.2f m\n', s.t_s, s.phase, s.altitude_agl_m); lastPhase = s.phase;
        if o.Camera == "schedule", r.setCameraMode(sched.(s.phase)); end
    end
    if lastPhase ~= "" && o.Camera ~= "schedule" && r.CameraMode ~= o.Camera, r.setCameraMode(o.Camera); end
    shotNow = si <= numel(shots) && s.t_s >= shots(si);
    if mod(s.tick_id, o.RenderEvery) == 0 || eng.isTerminal() || shotNow
        t0 = tic; r.update(s); drawnow limitrate; frame(end+1, 1) = toc(t0); %#ok<AGROW>
    end
    if shotNow && strlength(string(o.ShotDir)) > 0
        drawnow;
        f = fullfile(o.ShotDir, sprintf('V2-003-live-t%06.2f-%s-%s.png', s.t_s, s.phase, r.CameraMode));
        exportgraphics(r.Figure, f, 'Resolution', 110, 'BackgroundColor', 'current'); fprintf('  screenshot %s\n', f);
        si = si + 1;
    end
end
wall = toc(tw); fs = sort(frame);
stats = struct('phase', eng.Phase, 'fault', eng.FaultCode, 'sim_s', eng.time(), 'wall_s', wall, 'sim_to_wall', eng.time() / wall, ...
    'frames', numel(frame), 'frame_median_ms', 1e3 * median(frame), 'frame_p95_ms', 1e3 * fs(max(1, round(0.95 * numel(fs)))), ...
    'frame_max_ms', 1e3 * max(frame), 'scene_fps_effective', numel(frame) / wall);
fprintf('result: %s %s | sim %.2f s, wall %.2f s (x%.2f) | %d frames, median %.1f ms, p95 %.1f ms, max %.1f ms | effective scene rate %.1f FPS\n', ...
    stats.phase, stats.fault, stats.sim_s, stats.wall_s, stats.sim_to_wall, stats.frames, stats.frame_median_ms, stats.frame_p95_ms, ...
    stats.frame_max_ms, stats.scene_fps_effective);
end
