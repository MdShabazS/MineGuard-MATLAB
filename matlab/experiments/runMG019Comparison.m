function out = runMG019Comparison(outFolder)
%RUNMG019COMPARISON Fixed grid vs frozen PPO on the preregistered MG019-SPLIT-1 scenarios (MG-019).
%   out = runMG019Comparison(outFolder)
%   1. Verify that the preregistered manifest experiments/mg019/mg019_scenario_manifest.json is
%      unchanged (LF-normalised SHA-256) and that the checkpoint SHA-256 matches the manifest.
%   2. For every listed scenario (20 evaluation + 10 replication), run BOTH planners once with
%      mineguard.integration.runSurveyMission under the identical config and budget.
%   3. Write the per-scenario paired table, the paired navigation summary (grid-feasible only, with
%      bootstrap CI over scenarios), the exploratory detection summary and a plot.
%   No scenario is dropped or replaced. No checkpoint, budget, sensor, detector or threshold changes.
%   SIMULATION ONLY.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
mf = fullfile(root, 'experiments', 'mg019', 'mg019_scenario_manifest.json');
if ~exist(outFolder, 'dir'), mkdir(outFolder); end
expectManifest = "dda848a1324a63abc45c1443cf095a000d12d605d36e4dae9924573bb1d29bd5";
if lfSha(mf) ~= expectManifest
    error('mineguard:RunLockMismatch', 'MG019-SPLIT-1 manifest changed since preregistration; comparison not run.');
end
M = jsondecode(fileread(mf));
policy = mineguard.integration.loadPPOCheckpoint("", string(M.policy.checkpoint_sha256));
sets = [repmat("evaluation", numel(M.evaluation_set.seeds), 1); repmat("replication", numel(M.replication_set.seeds), 1)];
seeds = [M.evaluation_set.seeds(:); M.replication_set.seeds(:)];
rows = {}; t0 = tic;
for k = 1:numel(seeds)
    c = mg019ScenarioConfig(seeds(k), sets(k));
    [~, g] = mineguard.integration.runSurveyMission(c, "grid");
    [~, p] = mineguard.integration.runSurveyMission(c, "ppo", struct('policy', policy));
    rows{end+1, 1} = pairRow(sets(k), seeds(k), c, g, p); %#ok<AGROW>
end
P = vertcat(rows{:});
writetable(P, fullfile(outFolder, 'MG-019-paired-missions.csv'));
S = struct('manifest_sha256', expectManifest, 'checkpoint_sha256', policy.checksum, 'runtime_s', toc(t0), ...
    'evaluation', summarise(P(P.set == "evaluation", :), 1901), 'replication', summarise(P(P.set == "replication", :), 1902));
fid = fopen(fullfile(outFolder, 'MG-019-summary.json'), 'w'); fprintf(fid, '%s', jsonencode(S, 'PrettyPrint', true)); fclose(fid);
plotCoverage(P(P.set == "evaluation", :), fullfile(outFolder, 'MG-019-coverage-evaluation.png'));
out = struct('paired', P, 'summary', S);
end

function r = pairRow(set, seed, c, g, p)
r = table(set, seed, string(c.scenario_id), numel(c.exclusion_polygons_enu_m), p.n_legal, g.executed, string(g.reason), ...
    g.coverage_fraction, g.unique_cells, g.distance_m, g.mission_time_s, g.invalid_actions, g.revisits, g.runtime_s, ...
    string(p.reason), p.completed, p.coverage_fraction, p.unique_cells, p.distance_m, p.mission_time_s, p.coverage_per_m, ...
    p.coverage_per_s, p.invalid_actions, p.revisits, p.decisions, p.runtime_s, ...
    p.coverage_fraction - g.coverage_fraction, p.distance_m - g.distance_m, p.mission_time_s - g.mission_time_s, ...
    g.events, g.tp, g.fp, g.tn, g.fn, g.evaluable_cells, p.events, p.tp, p.fp, p.tn, p.fn, p.evaluable_cells, ...
    p.invalid_thermal_fraction, p.invalid_em_fraction, ...
    'VariableNames', {'set','seed','scenario_id','n_exclusions','n_legal','grid_feasible','grid_reason', ...
    'grid_coverage','grid_cells','grid_distance_m','grid_time_s','grid_invalid','grid_revisits','grid_runtime_s', ...
    'ppo_reason','ppo_completed','ppo_coverage','ppo_cells','ppo_distance_m','ppo_time_s','ppo_cov_per_m', ...
    'ppo_cov_per_s','ppo_invalid','ppo_revisits','ppo_decisions','ppo_runtime_s', ...
    'delta_coverage','delta_distance_m','delta_time_s', ...
    'grid_events','grid_tp','grid_fp','grid_tn','grid_fn','grid_evaluable','ppo_events','ppo_tp','ppo_fp','ppo_tn','ppo_fn','ppo_evaluable', ...
    'ppo_invalid_thermal_frac','ppo_invalid_em_frac'});
end

function s = summarise(P, bootSeed)
f = P(P.grid_feasible, :);
s = struct('n', height(P), 'n_grid_feasible', height(f), 'n_grid_infeasible', height(P) - height(f), ...
    'feasible_mean_delta_coverage', mean(f.delta_coverage), 'feasible_median_delta_coverage', median(f.delta_coverage), ...
    'feasible_delta_coverage_ci95', ci(f.delta_coverage, bootSeed), 'feasible_mean_delta_distance_m', mean(f.delta_distance_m), ...
    'feasible_delta_distance_ci95', ci(f.delta_distance_m, bootSeed + 10), 'feasible_mean_delta_time_s', mean(f.delta_time_s), ...
    'feasible_ppo_wins', nnz(f.delta_coverage > 0), 'feasible_ties', nnz(f.delta_coverage == 0), 'feasible_grid_wins', nnz(f.delta_coverage < 0), ...
    'feasible_mean_grid_coverage', mean(f.grid_coverage), 'feasible_mean_ppo_coverage', mean(f.ppo_coverage), ...
    'feasible_mean_grid_cov_per_m', mean(f.grid_coverage ./ f.grid_distance_m), 'feasible_mean_ppo_cov_per_m', mean(f.ppo_cov_per_m), ...
    'all_mean_ppo_coverage', mean(P.ppo_coverage), 'infeasible_mean_ppo_coverage', mean(P.ppo_coverage(~P.grid_feasible)), ...
    'ppo_completed', nnz(P.ppo_completed), 'ppo_total_invalid_actions', sum(P.ppo_invalid), 'ppo_missions_with_invalid', nnz(P.ppo_invalid > 0), ...
    'ppo_mean_revisits', mean(P.ppo_revisits), 'ppo_termination_counts', countReasons(P.ppo_reason), ...
    'grid_mean_revisits_feasible', mean(f.grid_revisits), ...
    'exploratory_detection', struct('grid_feasible_tp_fp_tn_fn', [sum(f.grid_tp) sum(f.grid_fp) sum(f.grid_tn) sum(f.grid_fn)], ...
        'ppo_same_scenarios_tp_fp_tn_fn', [sum(f.ppo_tp) sum(f.ppo_fp) sum(f.ppo_tn) sum(f.ppo_fn)], ...
        'ppo_all_tp_fp_tn_fn', [sum(P.ppo_tp) sum(P.ppo_fp) sum(P.ppo_tn) sum(P.ppo_fn)], ...
        'note', "Exploratory only: routes sample different positions, so evaluable populations and noise realisations differ."));
end

function c = countReasons(r)
u = unique(r); c = struct();
for k = 1:numel(u), c.(matlab.lang.makeValidName(u(k))) = nnz(r == u(k)); end
end

function v = ci(x, seed)
if numel(x) < 2, v = [NaN NaN]; return; end
s = RandStream('mt19937ar', 'Seed', seed); m = zeros(2000, 1);
for b = 1:2000, m(b) = mean(x(randi(s, numel(x), numel(x), 1))); end
v = quantile(m, [0.025 0.975]);
end

function plotCoverage(P, file)
f = figure('Visible', 'off', 'Position', [100 100 1100 420]); c = onCleanup(@() close(f));
y = [P.grid_coverage P.ppo_coverage];   % NaN (grid infeasible) draws no bar, never a fake 0
b = bar(categorical(string(P.seed)), y, 'grouped'); b(1).DisplayName = 'Fixed grid (no bar = INFEASIBLE route, not run)'; b(2).DisplayName = 'PPO (frozen MG-013)';
ylabel('coverage fraction (legal cells)'); ylim([0 1.05]); legend('Location', 'southoutside', 'Orientation', 'horizontal'); grid on;
title({'MG-019 evaluation set (MG019-SPLIT-1): coverage under equal budget (60 m / 30 s / 50 decisions)', 'SIMULATION ONLY — synthetic scenarios; not real landmine detection'});
exportgraphics(f, file, 'Resolution', 110);
end

function h = lfSha(f)
raw = fileread(f); tmp = [tempname '.lf'];
fid = fopen(tmp, 'w'); fwrite(fid, unicode2native(strrep(raw, char(13), ''), 'UTF-8')); fclose(fid);
c = onCleanup(@() delete(tmp));
[~, out] = system(sprintf('certutil -hashfile "%s" SHA256', tmp));
l = splitlines(string(out)); h = lower(erase(strtrim(l(2)), " "));
end
