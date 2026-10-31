function out = runMG013Experiment(outFolder, opts)
%RUNMG013EXPERIMENT Train a real PPO coverage policy and compare it with the MG-005 fixed grid (E5).
%   out = runMG013Experiment(outFolder)
%   out = runMG013Experiment(outFolder, opts)   opts.chunks, opts.episodes_per_chunk (defaults 10 x 400)
%   Execution order (enforced; recorded in out.execution_order):
%     1. Versioned PPO split manifest MG013-SPLIT-1, independent of MG-014's sealed GF families:
%        TRAIN 7001-7030, VALIDATION 7101-7110, TEST 7201-7210. It is validated and hashed
%        BEFORE any training.
%     2. Build TRAIN and VALIDATION grids only.
%     3. Train rlPPOAgent in chunks (global rng seeded once). After each chunk, evaluate the
%        deterministic policy on VALIDATION and keep the best checkpoint (max mean VALIDATION
%        coverage, ties -> shorter distance).
%     4. Freeze: save the selected checkpoint and frozen config, record SHA-256 hashes, reload
%        the checkpoint from disk and verify identical inference.
%     5. Only then build the TEST grids. Evaluate the frozen PPO (deterministic, plus 5 seeded
%        stochastic rollouts), the MG-005 fixed grid (or INFEASIBLE) and a seeded random-legal
%        reference, all under the same shared budget.
%   SYNTHETIC coverage task only: no detection claim, no physical flight.
if nargin < 2, opts = struct(); end
if ~isfield(opts, 'chunks'), opts.chunks = 10; end
if ~isfield(opts, 'episodes_per_chunk'), opts.episodes_per_chunk = 400; end
if ~exist(outFolder, 'dir'), mkdir(outFolder); end
ckDir = fullfile(tempdir, "mg013_checkpoints_" + string(datetime('now', 'Format', 'yyyyMMddHHmmss')));
mkdir(ckDir);
cfg = mineguard.rl.defaultEnvConfig();
order = strings(0, 1);

% 1. Manifest (frozen before training).
seeds = [7001:7030, 7101:7110, 7201:7210]';
split = [repmat("train", 30, 1); repmat("validation", 10, 1); repmat("test", 10, 1)];
manifest = table("PPO-G" + string(seeds), "MG013-" + string(seeds), seeds, seeds + 50000, split, ...
    'VariableNames', {'group_key','scenario_id','seed','noise_seed','split_id'});
mineguard.evaluation.validateSplitManifest(manifest);
mfile = fullfile(outFolder, 'MG-013-split-manifest.csv');
writetable(manifest, mfile);
manifestSha = sha256(mfile);
order(end+1) = "MG013-SPLIT-1 manifest validated and hashed (SHA-256 " + manifestSha + ") before training";

% 2. TRAIN and VALIDATION grids.
tr = find(split == "train"); va = find(split == "validation"); te = find(split == "test");
Gtr = arrayfun(@(k) mg013Grid(seeds(k), manifest.scenario_id(k)), tr, 'UniformOutput', false);
Gva = arrayfun(@(k) mg013Grid(seeds(k), manifest.scenario_id(k)), va, 'UniformOutput', false);
order(end+1) = "built " + numel(Gtr) + " TRAIN and " + numel(Gva) + " VALIDATION grids";

% 3. PPO training with validation checkpoint selection.
trainSeed = 13013; samplerSeed = 13014;
rng(trainSeed, 'twister');
[env, ~] = mineguard.rl.makeSurveyEnv(Gtr, cfg, samplerSeed);
validateEnvironment(env);
hp = struct('ExperienceHorizon', 512, 'MiniBatchSize', 128, 'ClipFactor', 0.2, 'EntropyLossWeight', 0.01, ...
    'DiscountFactor', 0.99, 'NumEpoch', 4, 'ActorLearnRate', 1e-3, 'CriticLearnRate', 1e-3, 'NumHiddenUnit', 64);
ao = rlPPOAgentOptions('ExperienceHorizon', hp.ExperienceHorizon, 'MiniBatchSize', hp.MiniBatchSize, ...
    'ClipFactor', hp.ClipFactor, 'EntropyLossWeight', hp.EntropyLossWeight, 'DiscountFactor', hp.DiscountFactor, 'NumEpoch', hp.NumEpoch);
ao.ActorOptimizerOptions.LearnRate = hp.ActorLearnRate; ao.CriticOptimizerOptions.LearnRate = hp.CriticLearnRate;
agent = rlPPOAgent(getObservationInfo(env), getActionInfo(env), rlAgentInitializationOptions('NumHiddenUnit', hp.NumHiddenUnit), ao);
topt = rlTrainingOptions('MaxEpisodes', opts.episodes_per_chunk, 'MaxStepsPerEpisode', cfg.max_decisions, ...
    'Plots', 'none', 'Verbose', false, 'StopTrainingCriteria', 'none', 'ScoreAveragingWindowLength', 50);
epRows = {}; valRows = {}; best = struct('cov', -Inf, 'dist', Inf, 'chunk', 0, 'file', "");
tTrain = tic;
for ch = 1:opts.chunks
    st = train(agent, env, topt);
    n = numel(st.EpisodeReward);
    epRows{end+1, 1} = table(repmat(ch, n, 1), ((ch-1) * opts.episodes_per_chunk + (1:n))', st.EpisodeReward(:), st.EpisodeSteps(:), st.AverageReward(:), ...
        'VariableNames', {'chunk','episode','episode_reward','episode_steps','average_reward_50'}); %#ok<AGROW>
    pol = policyStruct(agent, "mg013-ppo-chunk" + ch, cfg, manifest.scenario_id(tr));
    V = cellfun(@(G) mineguard.rl.runEpisode(G, cfg, pol, G.geometry.scenario_id), Gva, 'UniformOutput', false); V = [V{:}];
    vc = mean([V.coverage_fraction]); vd = mean([V.distance_m]);
    valRows{end+1, 1} = table(ch, ch * opts.episodes_per_chunk, vc, vd, mean([V.invalid_actions]), mean([V.return]), toc(tTrain), ...
        'VariableNames', {'chunk','episodes_total','val_mean_coverage','val_mean_distance_m','val_mean_invalid','val_mean_return','elapsed_s'}); %#ok<AGROW>
    f = fullfile(ckDir, "chunk" + ch + ".mat");
    saveAgent = agent; save(f, 'saveAgent');
    if vc > best.cov + 1e-12 || (abs(vc - best.cov) <= 1e-12 && vd < best.dist)
        best = struct('cov', vc, 'dist', vd, 'chunk', ch, 'file', string(f));
    end
end
trainSeconds = toc(tTrain);
training = vertcat(epRows{:}); valSel = vertcat(valRows{:});
writetable(training, fullfile(outFolder, 'MG-013-training-episodes.csv'));
writetable(valSel, fullfile(outFolder, 'MG-013-validation-selection.csv'));
order(end+1) = "trained " + height(training) + " episodes in " + opts.chunks + " chunks; VALIDATION selected chunk " + best.chunk;

% 4. Freeze and reload.
ckFile = fullfile(outFolder, 'mg013_ppo_checkpoint.mat');
copyfile(best.file, ckFile);
ckSha = sha256(ckFile);
frozen = struct('policy_version', "mg013-ppo-1.0", 'checkpoint_file', "mg013_ppo_checkpoint.mat", 'checkpoint_sha256', ckSha, ...
    'selected_chunk', best.chunk, 'selected_episodes', best.chunk * opts.episodes_per_chunk, 'val_mean_coverage', best.cov, ...
    'env', cfg, 'hyperparameters', hp, 'train_seed', trainSeed, 'sampler_seed', samplerSeed, ...
    'manifest_sha256', manifestSha, 'train_wallclock_s', trainSeconds, 'matlab_release', string(version('-release')), ...
    'git_sha', gitSha(), 'selection_rule', "max mean VALIDATION coverage (deterministic policy); ties -> lower mean distance");
fid = fopen(fullfile(outFolder, 'MG-013-frozen-policy.json'), 'w'); fprintf(fid, '%s', jsonencode(frozen, 'PrettyPrint', true)); fclose(fid);
L = load(ckFile); fagent = L.saveAgent;
fpol = policyStruct(fagent, frozen.policy_version, cfg, manifest.scenario_id(tr));
S0 = mineguard.rl.resetSurvey(Gva{1}, cfg); o0 = mineguard.rl.observationVector(S0, Gva{1}, cfg);
mem = load(best.file); mem.saveAgent.UseExplorationPolicy = false; fagent.UseExplorationPolicy = false;
reloadOk = isequal(getAction(mem.saveAgent, {o0}), getAction(fagent, {o0}));
order(end+1) = "froze checkpoint (SHA-256 " + ckSha + "), reloaded from disk; identical inference = " + reloadOk;

% 5. TEST, built only now.
Gte = arrayfun(@(k) mg013Grid(seeds(k), manifest.scenario_id(k)), te, 'UniformOutput', false);
order(end+1) = "built " + numel(Gte) + " TEST grids after freezing";
rows = {}; stochRows = {};
for k = 1:numel(Gte)
    G = Gte{k}; sid = G.geometry.scenario_id;
    Ep = mineguard.rl.runEpisode(G, cfg, fpol, sid);
    [seq, feas, fr] = mineguard.rl.gridBaselineSequence(G);
    if feas
        Eg = mineguard.rl.runEpisode(G, cfg, seq, sid);
    else
        Eg = struct('reason', fr, 'coverage_fraction', NaN, 'distance_m', NaN, 'mission_time_s', NaN, 'invalid_actions', NaN, 'revisits', NaN, 'return', NaN);
    end
    rc = zeros(5, 1); pc = zeros(5, 1);
    for rep = 1:5
        rs = RandStream('mt19937ar', 'Seed', 900000 + 10 * k + rep);
        Er = mineguard.rl.runEpisode(G, cfg, @(S, GG) randomLegal(S, GG, rs), sid);
        rc(rep) = Er.coverage_fraction;
        rng(800000 + 10 * k + rep, 'twister');
        sp = fpol; sp.use_exploration = true;
        Es = mineguard.rl.runEpisode(G, cfg, sp, sid);
        pc(rep) = Es.coverage_fraction;
        stochRows{end+1, 1} = table(sid, rep, Es.coverage_fraction, Es.distance_m, Es.invalid_actions, Es.reason, Er.coverage_fraction, Er.reason, ...
            'VariableNames', {'scenario_id','rep','ppo_stochastic_coverage','ppo_stochastic_distance_m','ppo_stochastic_invalid','ppo_stochastic_reason','random_legal_coverage','random_legal_reason'}); %#ok<AGROW>
    end
    rows{end+1, 1} = table(sid, nnz(G.legal), numel(G.geometry.exclusion_polygons_enu_m), feas, ...
        Ep.coverage_fraction, Ep.distance_m, Ep.mission_time_s, Ep.invalid_actions, Ep.revisits, Ep.reason, Ep.decisions, ...
        Eg.coverage_fraction, Eg.distance_m, Eg.mission_time_s, Eg.invalid_actions, Eg.revisits, string(Eg.reason), ...
        Ep.coverage_fraction - Eg.coverage_fraction, Ep.distance_m - Eg.distance_m, Ep.mission_time_s - Eg.mission_time_s, ...
        mean(pc), std(pc), mean(rc), ...
        'VariableNames', {'scenario_id','n_legal','n_exclusions','grid_feasible','ppo_coverage','ppo_distance_m','ppo_time_s', ...
        'ppo_invalid','ppo_revisits','ppo_reason','ppo_decisions','grid_coverage','grid_distance_m','grid_time_s','grid_invalid', ...
        'grid_revisits','grid_reason','delta_coverage','delta_distance_m','delta_time_s','ppo_stochastic_mean_coverage', ...
        'ppo_stochastic_std_coverage','random_legal_mean_coverage'}); %#ok<AGROW>
end
paired = vertcat(rows{:}); stoch = vertcat(stochRows{:});
writetable(paired, fullfile(outFolder, 'MG-013-test-paired.csv'));
writetable(stoch, fullfile(outFolder, 'MG-013-test-stochastic-and-random.csv'));
fz = paired(paired.grid_feasible, :);
summary = struct('n_test', height(paired), 'n_grid_feasible', height(fz), 'n_grid_infeasible', height(paired) - height(fz), ...
    'feasible_mean_delta_coverage', mean(fz.delta_coverage), 'feasible_median_delta_coverage', median(fz.delta_coverage), ...
    'feasible_delta_coverage_ci95', bootci95(fz.delta_coverage, 4242), 'feasible_mean_delta_distance_m', mean(fz.delta_distance_m), ...
    'feasible_delta_distance_ci95', bootci95(fz.delta_distance_m, 4243), 'feasible_mean_ppo_coverage', mean(fz.ppo_coverage), ...
    'feasible_mean_grid_coverage', mean(fz.grid_coverage), 'infeasible_mean_ppo_coverage', mean(paired.ppo_coverage(~paired.grid_feasible)), ...
    'all_mean_ppo_coverage', mean(paired.ppo_coverage), 'all_mean_random_legal_coverage', mean(paired.random_legal_mean_coverage), ...
    'ppo_total_invalid_actions', sum(paired.ppo_invalid), 'grid_wins_or_ties', nnz(fz.delta_coverage <= 0), 'ppo_wins', nnz(fz.delta_coverage > 0));
fid = fopen(fullfile(outFolder, 'MG-013-test-summary.json'), 'w'); fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true)); fclose(fid);
order(end+1) = "evaluated TEST once with the frozen policy";
out = struct('manifest', manifest, 'frozen', frozen, 'training', training, 'validation', valSel, 'paired', paired, ...
    'stochastic', stoch, 'summary', summary, 'reload_identical', reloadOk, 'execution_order', order);
end

function pol = policyStruct(agent, version, cfg, trainIds)
pol = struct('kind', "ppo", 'version', string(version), 'layout_id', cfg.layout_id, 'n_cells', 25, 'agent', agent, ...
    'training_split', "MG013-SPLIT-1/train", 'train_scenario_ids', trainIds, 'use_exploration', false);
end

function a = randomLegal(S, G, rs)
r = find(G.reach(S.cell, :));
a = r(randi(rs, numel(r)));
end

function ci = bootci95(x, seed)
if numel(x) < 2, ci = [NaN NaN]; return; end
s = RandStream('mt19937ar', 'Seed', seed);
B = 2000; m = zeros(B, 1);
for b = 1:B, m(b) = mean(x(randi(s, numel(x), numel(x), 1))); end
ci = quantile(m, [0.025 0.975]);
end

function h = sha256(f)
[st, out] = system(sprintf('certutil -hashfile "%s" SHA256', f));
lines = splitlines(string(out));
if st ~= 0 || numel(lines) < 2, h = "NOT_RECORDED"; return; end
h = lower(erase(strtrim(lines(2)), " "));
end

function s = gitSha()
[st, o] = system('git rev-parse --short HEAD');
if st ~= 0, s = "NOT_RECORDED"; else, s = strtrim(string(o)); end
end
