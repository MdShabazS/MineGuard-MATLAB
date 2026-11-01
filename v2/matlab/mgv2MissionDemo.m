function [eng, stats] = mgv2MissionDemo(varargin)
%MGV2MISSIONDEMO Live V2-002 mission-engine demonstration. SIMULATION ONLY (no real aircraft or GCS).
%   mgv2MissionDemo                       nominal mission on a terrain-following test surface, live 2-D monitor
%   mgv2MissionDemo('Wind', true)         same mission with seeded mean wind and gusts
%   mgv2MissionDemo('Plot', false)        headless: console phase log and statistics only
%   mgv2MissionDemo('RealTime', 1)        pace the simulation to 1x wall time (0 = as fast as possible)
%   mgv2MissionDemo('Config', cfg, 'Terrain', terrain)
%   [eng, stats] = mgv2MissionDemo(...)   eng: finished MissionEngine; stats: timing summary
%
%   From the repository root:  addpath('v2/matlab'); mgv2MissionDemo
%   The engine owns the clock; this function only calls eng.step() and redraws every few ticks.
%   The 3-D scene, terrain model and camera views are V2-003 (not part of this demo).
p = inputParser;
p.addParameter('Wind', false); p.addParameter('Plot', true); p.addParameter('RealTime', 0);
p.addParameter('Config', []); p.addParameter('Terrain', []); p.addParameter('RedrawEvery', 4);
p.parse(varargin{:}); o = p.Results;
cfg = o.Config; if isempty(cfg), cfg = mgv2.mission.defaultConfig(); end
if o.Wind
    cfg.wind = struct('enabled', true, 'mean_enu_mps', [2.5 1.0 0], 'gust_sigma_mps', 0.8, 'gust_tau_s', 3);
    cfg.run_id = cfg.run_id + "-WIND";
end
ter = o.Terrain;
if isempty(ter), ter = struct('id', "demo-wavy-slope", 'heightAt', @(x, y) 0.04 * x + 2 * sin(x / 15) .* cos(y / 20)); end
eng = mgv2.engine.MissionEngine(cfg, ter);
fprintf('\n=== MineGuard V2 live mission engine (V2-002) — SIMULATION ONLY ===\n');
fprintf('run %s | scenario %s | seed %d | dt %.3f s | terrain %s | wind %s\n', cfg.run_id, cfg.scenario_id, cfg.seed, ...
    cfg.dt_s, ter.id, string(cfg.wind.enabled));
fprintf('survey: %d lines, spacing %.1f m, route %.1f m, AGL %.1f m, speed %.1f m/s\n', eng.Plan.n_lines, ...
    cfg.line_spacing_m, eng.Route.length_m, cfg.alt_agl_setpoint_m, cfg.speed_mps);
H = [];
if o.Plot, H = setupMonitor(eng, cfg); end
eng.start(); lastPhase = ""; tw = tic; nDraw = 0; drawT = 0;
while true
    if o.RealTime > 0
        lag = eng.time() / o.RealTime - toc(tw);
        if lag > 0, pause(lag); end
    end
    if ~eng.step(), break; end
    s = eng.snapshot();
    if s.phase ~= lastPhase
        fprintf('  t=%7.2f s  tick %5d  %-12s  pos E%7.1f N%7.1f U%6.1f  AGL %5.2f m\n', s.t_s, s.tick_id, s.phase, ...
            s.position_enu_m, s.altitude_agl_m);
        lastPhase = s.phase;
    end
    if ~isempty(H) && (mod(s.tick_id, o.RedrawEvery) == 0 || eng.isTerminal())
        t0 = tic; H = updateMonitor(H, eng, s); drawnow limitrate; drawT = drawT + toc(t0); nDraw = nDraw + 1;
    end
end
wall = toc(tw);
T = eng.poseLog(); sv = T.phase == "SURVEY";
trk = vecnorm(T.position_enu_m(sv,1:2) - T.commanded_position_enu_m(sv,1:2), 2, 2);
stats = struct('phase', eng.Phase, 'fault', eng.FaultCode, 'sim_s', eng.time(), 'wall_s', wall, ...
    'ticks', eng.TickId, 'sim_to_wall', eng.time() / wall, 'redraws', nDraw, 'mean_redraw_ms', 1e3 * drawT / max(nDraw, 1), ...
    'max_track_err_m', max([trk; 0]), 'max_speed_mps', max(vecnorm(T.velocity_enu_mps(:,1:2), 2, 2)), ...
    'final_dist_home_m', norm(T.position_enu_m(end,1:2) - cfg.home_enu_m));
fprintf('result: %s %s | sim %.2f s in %.2f s wall (x%.1f) | %d ticks | max speed %.2f m/s | survey track error max %.2f m | final distance from home %.3f m\n', ...
    stats.phase, stats.fault, stats.sim_s, stats.wall_s, stats.sim_to_wall, stats.ticks, stats.max_speed_mps, ...
    stats.max_track_err_m, stats.final_dist_home_m);
if eng.Phase ~= "COMPLETE", fprintf('NOT COMPLETE: %s\n', eng.FaultMessage); end
end

function H = setupMonitor(eng, cfg)
f = figure('Name', 'MineGuard V2-002 mission engine monitor — SIMULATION', 'Color', 'w', 'Position', [80 80 1200 620]);
tl = tiledlayout(f, 2, 2); title(tl, 'SIMULATION — V2-002 live mission engine (2-D monitor; 3-D scene is V2-003)', 'Color', [0.7 0 0]);
ax = nexttile(tl, 1, [2 1]); hold(ax, 'on'); axis(ax, 'equal'); grid(ax, 'on');
P = cfg.survey_polygon_enu_m; b = cfg.bounds_enu_m;
plot(ax, b(1,[1 2 2 1 1]), b(2,[1 1 2 2 1]), 'k:', 'DisplayName', 'geofence');
fill(ax, P(:,1), P(:,2), [0.85 0.93 0.85], 'EdgeColor', [0 0.5 0], 'DisplayName', 'survey polygon');
plot(ax, eng.Route.xy(:,1), eng.Route.xy(:,2), '--', 'Color', [0.5 0.5 0.5], 'DisplayName', 'planned path');
plot(ax, cfg.home_enu_m(1), cfg.home_enu_m(2), 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'y', 'DisplayName', 'home');
H.cmd = animatedline(ax, 'Color', [0.95 0.6 0.1], 'DisplayName', 'commanded reference');
H.act = animatedline(ax, 'Color', [0 0.35 0.8], 'LineWidth', 1.4, 'DisplayName', 'actual (simulated)');
H.uav = quiver(ax, NaN, NaN, NaN, NaN, 0, 'r', 'LineWidth', 2, 'MaxHeadSize', 2, 'DisplayName', 'UAV heading');
xlabel(ax, 'x east [m]'); ylabel(ax, 'y north [m]'); legend(ax, 'Location', 'southoutside', 'NumColumns', 3);
H.ax = ax;
a2 = nexttile(tl, 2); hold(a2, 'on'); grid(a2, 'on'); ylabel(a2, 'AGL [m]'); xlabel(a2, 't_s [s]');
H.agl = animatedline(a2, 'Color', 'b'); yline(a2, cfg.alt_agl_setpoint_m, 'g--'); yline(a2, cfg.constraints.min_clearance_m, 'r:');
a3 = nexttile(tl, 4); hold(a3, 'on'); grid(a3, 'on'); ylabel(a3, 'speed [m/s]'); xlabel(a3, 't_s [s]');
H.spd = animatedline(a3, 'Color', 'k'); H.txt = title(a3, '');
end

function H = updateMonitor(H, ~, s)
% O(1) per redraw: append the current snapshot only (the engine log is never re-read here)
if all(isfinite(s.commanded_position_enu_m)), addpoints(H.cmd, s.commanded_position_enu_m(1), s.commanded_position_enu_m(2)); end
addpoints(H.act, s.position_enu_m(1), s.position_enu_m(2));
set(H.uav, 'XData', s.position_enu_m(1), 'YData', s.position_enu_m(2), 'UData', 6 * cos(s.yaw_rad), 'VData', 6 * sin(s.yaw_rad));
addpoints(H.agl, s.t_s, s.altitude_agl_m);
addpoints(H.spd, s.t_s, norm(s.velocity_enu_mps));
H.txt.String = sprintf('t_{sim} = %.2f s | %s | heading %.0f deg', s.t_s, s.phase, s.heading_deg);
title(H.ax, sprintf('%s  |  run %s', s.phase, s.run_id), 'Interpreter', 'none');
end
