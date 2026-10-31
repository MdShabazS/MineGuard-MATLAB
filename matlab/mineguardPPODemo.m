function [cmpApp, gridBundle, ppoBundle, T] = mineguardPPODemo(seed, varargin)
%MINEGUARDPPODEMO One-command fixed-grid vs PPO demonstration (MG-019). SIMULATION ONLY.
%   mineguardPPODemo                 seed 7307 (first preregistered MG019-SPLIT-1 scenario where the fixed grid is
%                                    feasible, so both planners can be shown; display choice only, all 20 are reported)
%   mineguardPPODemo(7301)           any other preregistered seed (7301 makes the grid infeasible: PPO runs alone)
%   mineguardPPODemo(..., 'ExportTo', folder)   also export the verified comparison (CSV/TXT/PNG)
%   mineguardPPODemo(..., 'OpenReplay', true)   also open the full MG-011 replay of the PPO mission
%   [cmpApp, gridBundle, ppoBundle, T] = mineguardPPODemo(...)
%
%   From the repository root:   addpath('matlab'); mineguardPPODemo
%   Steps:
%     1. verify the frozen MG-013 checkpoint (SHA-256), failing safely if it is missing or invalid
%     2. generate the compatible 5x5 scenario
%     3. run the fixed grid and the genuine PPO inference under the same budget
%     4. run sensors, the frozen detector and the separate evaluation for each route
%     5. print the measured comparison and open the side-by-side window
%   The fixed-grid demo mineguardDemo is unchanged.
if nargin < 1 || isempty(seed), seed = 7307; end
p = inputParser; p.addParameter('ExportTo', ""); p.addParameter('OpenReplay', false); p.parse(varargin{:});
here = fileparts(mfilename('fullpath')); addpath(here, fullfile(here, 'experiments'));
fprintf('\n=== MineGuard PPO vs fixed-grid demo — SIMULATION ONLY (synthetic; not validated for real landmine detection or clearance) ===\n');
policy = mineguard.integration.loadPPOCheckpoint();
fprintf('[1/5] PPO checkpoint verified: SHA-256 %s (55-d observation, 25 actions, deterministic inference)\n', policy.checksum);
c = mg019ScenarioConfig(seed);
fprintf('[2/5] Scenario %s | seed %d | 10x10 m, 2 m cells (25) | %d no-fly zone(s) | budget 60 m / 30 s / 50 decisions\n', ...
    c.scenario_id, c.seed, numel(c.exclusion_polygons_enu_m));
[gridBundle, gr] = mineguard.integration.runSurveyMission(c, "grid");
[ppoBundle, pr] = mineguard.integration.runSurveyMission(c, "ppo", struct('policy', policy));
T = mineguard.integration.comparisonTable({gr, pr});
fprintf('[3/5] Missions executed:\n');
fprintf('      %-5s %-26s %5s  %8s  %8s  %7s  %7s  %8s  %6s\n', 'plan', 'termination', 'cov', 'cells', 'dist[m]', 'time[s]', 'invalid', 'revisits', 'events');
for k = 1:height(T)
    fprintf('      %-5s %-26s %5.3f  %5g/%-2d  %8.1f  %7.1f  %7g  %8g  %6g\n', T.planner(k), T.reason(k), ...
        T.coverage_fraction(k), T.unique_cells(k), T.n_legal(k), T.distance_m(k), T.mission_time_s(k), T.invalid_actions(k), T.revisits(k), T.events(k));
end
if gr.executed
    fprintf('[4/5] Paired (PPO - grid): coverage %+.3f, distance %+.1f m, time %+.1f s\n', pr.coverage_fraction - gr.coverage_fraction, ...
        pr.distance_m - gr.distance_m, pr.mission_time_s - gr.mission_time_s);
else
    fprintf('[4/5] Fixed grid NOT RUN (%s): MG-005 does not reroute; PPO metrics stand alone, not counted as a PPO win.\n', gr.reason);
end
fprintf('      Exploratory detection (different routes -> different readings): grid TP/FP %g/%g, PPO TP/FP %g/%g\n', gr.tp, gr.fp, pr.tp, pr.fp);
if ~isempty(gridBundle), gridBundle.comparison = T; end
ppoBundle.comparison = T;
cmpApp = mineguard.app.openComparisonApp(gridBundle, ppoBundle, T);
if strlength(string(p.Results.ExportTo)) > 0
    cmpApp.exportComparison(p.Results.ExportTo); fprintf('      %s\n', cmpApp.StatusText);
end
if p.Results.OpenReplay, cmpApp.openReplay("ppo"); end
fprintf('[5/5] Comparison window open (use "Open PPO replay" / "Open fixed-grid replay" / "Export comparison"). Fixed grid remains the release baseline.\n\n');
end
