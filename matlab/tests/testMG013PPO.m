classdef testMG013PPO < matlab.unittest.TestCase
    %TESTMG013PPO MG-012 acceptance tests P-01..P-20 for the MG-013 PPO coverage environment and policy.
    %   Run from repo root: addpath('matlab'); runtests('matlab/tests/testMG013PPO.m')
    %   P-14/P-15/P-16/P-20 also read the frozen experiment artifacts in tasks/evidence/MG-013/.
    %   SYNTHETIC coverage only; no detection or physical-flight claim.

    properties (Constant)
        Ev = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'tasks', 'evidence', 'MG-013')
        % Committed checkpoint copy (repo .gitignore allows *.mat only under results/approved/).
        Ck = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'results', 'approved', 'mg013_ppo_checkpoint.mat')
    end

    methods (TestClassSetup)
        function addPaths(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'experiments')));
        end
    end

    methods (Static)
        function [G, c] = grid(polys)
            c = mg013ScenarioConfig(1, "P-TEST");
            if nargin < 1, polys = {}; end
            c.exclusion_polygons_enu_m = polys;
            [g, ~] = mineguard.scenario.generateScenario(c);
            G = mineguard.rl.buildSurveyGrid(mineguard.navigation.navigationConfigFromExperiment(c), g);
        end
        function pol = untrained()
            pol = struct('kind', "untrained_test", 'version', "test", 'layout_id', "cov-2N+5-v1", 'n_cells', 25);
        end
        function F = frozen()
            F = jsondecode(fileread(fullfile(testMG013PPO.Ev, 'MG-013-frozen-policy.json')));
        end
        function pol = frozenPolicy()
            L = load(testMG013PPO.Ck);
            pol = struct('kind', "ppo", 'version', "mg013-ppo-1.0", 'layout_id', "cov-2N+5-v1", 'n_cells', 25, 'agent', L.saveAgent);
        end
        function h = sha256(f)
            [~, out] = system(sprintf('certutil -hashfile "%s" SHA256', f));
            lines = splitlines(string(out)); h = lower(erase(strtrim(lines(2)), " "));
        end
    end

    methods (Test)
        function p01_gridMatchesMG005(tc)
            [G, c] = testMG013PPO.grid();
            tc.verifyEqual([G.N G.nx G.ny G.dx G.dy], [25 5 5 2 2]);
            nav = mineguard.navigation.navigationConfigFromExperiment(c);
            route = mineguard.navigation.makeGridRoute(nav, G.geometry);
            tc.verifyEqual(sortrows(route(:,1:2)), sortrows(G.centers), 'AbsTol', 1e-12);
            tc.verifyEqual(mineguard.rl.cellOfPoint(G, route(1,1), route(1,2)), 1, 'start = first MG-005 waypoint');
            E = mineguard.rl.runEpisode(G, mineguard.rl.defaultEnvConfig(), mineguard.rl.gridBaselineSequence(G), "P01");
            C5 = mineguard.navigation.computeCoverage(nav, G.geometry, mineguard.navigation.simulatePose(nav, G.geometry, route));
            tc.verifyEqual([E.coverage_fraction E.distance_m E.mission_time_s], [C5.coverage_fraction C5.distance_m C5.mission_time_s], 'AbsTol', 1e-9);
        end

        function p02_observationLayout(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            S = mineguard.rl.resetSurvey(G, cfg); v = mineguard.rl.observationVector(S, G, cfg);
            tc.verifySize(v, [55 1]); tc.verifyClass(v, 'double'); tc.verifyTrue(all(isfinite(v) & v >= 0 & v <= 1));
            tc.verifyEqual(v(1:2)', [0.1 0.1], 'AbsTol', 1e-12); tc.verifyEqual(v(3), 1); tc.verifyEqual(v(53:55)', [1 1 0]);
            tc.verifyEqual(cfg.layout_id, "cov-2N+5-v1");
            env = mineguard.rl.makeSurveyEnv({G}, cfg, 1);
            tc.verifyEqual(getObservationInfo(env).Dimension, [55 1]);
            tc.verifyEqual(getActionInfo(env).Elements(:)', 1:25);
        end

        function p03_truthFirewall(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            S = mineguard.rl.resetSurvey(G, cfg); [o, ac] = mineguard.rl.observationRecords(S, G, cfg, "P03");
            id = 'mineguard:InvalidPolicyInput'; pol = testMG013PPO.untrained();
            o2 = o; o2.hidden_truth = 1;                    tc.verifyError(@() mineguard.rl.selectSurveyCell(o2, ac, pol), id);
            p2 = pol; p2.meta = struct('a', {{struct('label', "target")}}); tc.verifyError(@() mineguard.rl.selectSurveyCell(o, ac, p2), id);
            p3 = pol; p3.notes = struct('t', table(1));     tc.verifyError(@() mineguard.rl.selectSurveyCell(o, ac, p3), id);
            p4 = pol; p4.target_count = 3;                  tc.verifyError(@() mineguard.rl.selectSurveyCell(o, ac, p4), id);
            ac2 = ac; ac2.burial_depth_m = zeros(25, 1);    tc.verifyError(@() mineguard.rl.selectSurveyCell(o, ac2, pol), id);
            files = dir(fullfile(fileparts(which('mineguard.rl.stepSurvey')), '*.m'));
            for k = 1:numel(files)
                code = strjoin(regexprep(splitlines(string(fileread(fullfile(files(k).folder, files(k).name)))), '%.*$', ''), newline);
                tc.verifyFalse(contains(code, ["hidden_truth","TargetTruth","burial_depth_m","material_type","target_count", ...
                    ".label","generateScenario","scoreDetections","simulateThermal","simulateEM"]), files(k).name);
            end
        end

        function p04_legalMoveNoTeleport(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            S = mineguard.rl.resetSurvey(G, cfg);
            [S, ~, info] = mineguard.rl.stepSurvey(S, 2, G, cfg);
            tc.verifyEqual(info.status, "MOVED"); tc.verifyEqual(S.cell, 2); tc.verifyEqual(nnz(S.visited), 2);
            steps = hypot(diff(S.pose_xy(:,1)), diff(S.pose_xy(:,2)));
            tc.verifyLessThanOrEqual(max(steps), G.nav.speed_mps * G.nav.dt_s + 1e-9);
            tc.verifyEqual(S.pose_xy(end, :), G.centers(2, :), 'AbsTol', 1e-9);
        end

        function p05_illegalAndExclusionRejected(tc)
            cfg = mineguard.rl.defaultEnvConfig();
            G = testMG013PPO.grid({[4 4; 6 4; 6 6; 4 6]});          % covers centre cell 13
            tc.verifyFalse(G.legal(13));
            S = mineguard.rl.resetSurvey(G, cfg); S0 = S;
            [S, ~, info] = mineguard.rl.stepSurvey(S, 13, G, cfg);
            tc.verifyEqual(info.status, "REJECTED_INVALID"); tc.verifyEqual(S.cell, S0.cell); tc.verifyEqual(S.invalid_actions, 1);
            tc.verifyEqual(S.pose_xy, S0.pose_xy);
            tc.verifyFalse(G.reach(11, 15), 'leg (1,5)->(9,5) crosses the zone');
            Gn = testMG013PPO.grid({[1.99 0; 2.01 0; 2.01 10; 1.99 10]});   % narrow strip between cell centres
            tc.verifyTrue(all(Gn.legal)); tc.verifyFalse(Gn.reach(1, 2)); tc.verifyTrue(Gn.reach(1, 6));
            Gt = testMG013PPO.grid({[2 1; 2.5 1.8; 1.5 1.8]});        % triangle apex exactly on leg (1,1)->(3,1)
            tc.verifyTrue(Gt.legal(1) && Gt.legal(2));
            tc.verifyFalse(Gt.reach(1, 2), 'vertex graze (boundary contact) is rejected');
        end

        function p06_revisitNoCredit(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig(); w = cfg.w;
            S = mineguard.rl.resetSurvey(G, cfg);
            S = mineguard.rl.stepSurvey(S, 2, G, cfg);
            [S, r, info] = mineguard.rl.stepSurvey(S, 1, G, cfg);
            tc.verifyEqual(info.components(1), 0); tc.verifyEqual(info.components(4), 1); tc.verifyEqual(S.revisits, 1);
            tc.verifyEqual(r, -w.dist * 2/60 - w.time * 1/30 - w.visit - w.step, 'AbsTol', 1e-12);
        end

        function p07_malformedActionsBounded(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            S = mineguard.rl.resetSurvey(G, cfg);
            for a = {NaN, 2.5, 0, 26, 1, [1 2], -3}
                [S, r, info] = mineguard.rl.stepSurvey(S, a{1}, G, cfg);
                tc.verifyEqual(info.status, "REJECTED_INVALID"); tc.verifyEqual(r, -cfg.w.bad - cfg.w.step, 'AbsTol', 1e-12);
            end
            tc.verifyEqual(S.invalid_actions, 7); tc.verifyEqual(S.cell, 1); tc.verifyEqual(S.dist_m, 0);
            while ~S.done, S = mineguard.rl.stepSurvey(S, 1, G, cfg); end
            tc.verifyEqual(S.reason, "MAX_STEPS"); tc.verifyEqual(S.decisions, cfg.max_decisions);
            tc.verifyError(@() mineguard.rl.stepSurvey(S, 2, G, cfg), 'mineguard:EpisodeDone');
        end

        function p08_timeAndPoseContinuity(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            E = mineguard.rl.runEpisode(G, cfg, [5 25], "P08");
            P = E.poses;
            tc.verifyTrue(all(diff(P.t_s) > 0)); tc.verifyEqual(numel(unique(P.pose_sample_id)), height(P));
            tc.verifyEqual([E.distance_m E.mission_time_s P.t_s(end)], [16 8 8], 'AbsTol', 1e-9);
            tc.verifyLessThanOrEqual(max(hypot(diff(P.x_east_m), diff(P.y_north_m))), 0.2 + 1e-9);
            tc.verifyEqual([P.x_east_m(end) P.y_north_m(end)], [9 9], 'AbsTol', 1e-9);
        end

        function p09_budgetNeverExceeded(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig(); cfg.D_max_m = 9; cfg.T_max_s = 30;
            S = mineguard.rl.resetSurvey(G, cfg);
            S = mineguard.rl.stepSurvey(S, 5, G, cfg); tc.verifyEqual(S.dist_m, 8);
            [S, r, info] = mineguard.rl.stepSurvey(S, 4, G, cfg);
            tc.verifyEqual(info.status, "REJECTED_BUDGET"); tc.verifyEqual(S.reason, "BUDGET_EXHAUSTED");
            tc.verifyEqual(S.dist_m, 8); tc.verifyEqual(S.cell, 5); tc.verifyEqual(r, -cfg.w.step - cfg.w.end, 'AbsTol', 1e-12);
            Eg = mineguard.rl.runEpisode(G, cfg, mineguard.rl.gridBaselineSequence(G), "P09");
            tc.verifyEqual(Eg.reason, "BUDGET_EXHAUSTED"); tc.verifyLessThanOrEqual(Eg.distance_m, 9);
            cfg2 = mineguard.rl.defaultEnvConfig(); cfg2.T_max_s = 3.5;     % time cap binds first
            Et = mineguard.rl.runEpisode(G, cfg2, [2 3 4 5], "P09t");
            tc.verifyEqual(Et.reason, "BUDGET_EXHAUSTED"); tc.verifyLessThanOrEqual(Et.mission_time_s, 3.5);
        end

        function p10_terminationReasons(tc)
            cfg = mineguard.rl.defaultEnvConfig();
            G = testMG013PPO.grid();
            E = mineguard.rl.runEpisode(G, cfg, mineguard.rl.gridBaselineSequence(G), "P10");
            tc.verifyEqual(E.reason, "COVERAGE_GOAL"); tc.verifyEqual(E.coverage_fraction, 1);
            tc.verifyEqual(E.visited_legal_cells, E.coverage.visited_valid_cells, 'env coverage = MG-005 computeCoverage');
            Gi = testMG013PPO.grid({[1.9 0; 2.1 0; 2.1 2.1; 1.9 2.1], [0 1.9; 2.1 1.9; 2.1 2.1; 0 2.1]});
            S = mineguard.rl.resetSurvey(Gi, cfg);
            tc.verifyTrue(S.done); tc.verifyEqual(S.reason, "NO_LEGAL_ACTION");
            E2 = mineguard.rl.runEpisode(G, cfg, [2 1 2 1], "P10b");   % sequence ends early
            tc.verifyEqual(E2.reason, "ROUTE_END"); tc.verifyEqual(E2.visited_legal_cells, E2.coverage.visited_valid_cells);
        end

        function p11_rewardArithmetic(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig(); w = cfg.w;
            S = mineguard.rl.resetSurvey(G, cfg);
            [S, r1] = mineguard.rl.stepSurvey(S, 2, G, cfg);
            tc.verifyEqual(r1, w.cov / 25 - w.dist * 2/60 - w.time * 1/30 - w.step, 'AbsTol', 1e-12);
            [S, r2] = mineguard.rl.stepSurvey(S, 5, G, cfg);           % 6 m east: new cells 3,4,5
            tc.verifyEqual(r2, w.cov * 3/25 - w.dist * 6/60 - w.time * 3/30 - w.step, 'AbsTol', 1e-12);
            [~, r3] = mineguard.rl.stepSurvey(S, 99, G, cfg);
            tc.verifyEqual(r3, -w.bad - w.step, 'AbsTol', 1e-12);
            tc.verifyTrue(all(structfun(@(x) isfinite(x) && x >= 0, w)));
            tc.verifyEqual(sum(S.reward_log(:, end)), r1 + r2, 'AbsTol', 1e-12);
        end

        function p12_determinism(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            before = rng;
            E1 = mineguard.rl.runEpisode(G, cfg, [2 7 12 17 22 23], "P12");
            E2 = mineguard.rl.runEpisode(G, cfg, [2 7 12 17 22 23], "P12");
            tc.verifyTrue(isequaln(rmfield(E1, 'coverage'), rmfield(E2, 'coverage')));
            tc.verifyEqual(rng, before);
            a = mineguard.rl.ScenarioSampler(10, 5); b = mineguard.rl.ScenarioSampler(10, 5);
            tc.verifyEqual(arrayfun(@(~) a.next(), 1:20), arrayfun(@(~) b.next(), 1:20));
            tc.verifyEqual(rng, before, 'sampler uses a local stream');
        end

        function p13_rlFunctionEnvValidates(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            env = mineguard.rl.makeSurveyEnv({G}, cfg, 3);
            tc.verifyClass(env, 'rl.env.rlFunctionEnv');
            validateEnvironment(env);
            o = reset(env);
            tc.verifyEqual(o, mineguard.rl.observationVector(mineguard.rl.resetSurvey(G, cfg), G, cfg));
            [o2, r, d] = step(env, 2);
            [S, rr] = mineguard.rl.stepSurvey(mineguard.rl.resetSurvey(G, cfg), 2, G, cfg);
            tc.verifyEqual(o2, mineguard.rl.observationVector(S, G, cfg)); tc.verifyEqual(r, rr, 'AbsTol', 1e-12); tc.verifyFalse(d);
        end

        function p14_genuineTrainingAndCheckpoint(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            env = mineguard.rl.makeSurveyEnv({G}, cfg, 4);
            rng(77, 'twister');
            ag = rlPPOAgent(getObservationInfo(env), getActionInfo(env), rlAgentInitializationOptions('NumHiddenUnit', 16), ...
                rlPPOAgentOptions('ExperienceHorizon', 64, 'MiniBatchSize', 32, 'LearningFrequency', 64));   % explicit update cadence for a short run
            p0 = getLearnableParameters(getActor(ag));
            st = train(ag, env, rlTrainingOptions('MaxEpisodes', 40, 'MaxStepsPerEpisode', 50, 'Plots', 'none', 'Verbose', false, 'StopTrainingCriteria', 'none'));
            tc.verifyEqual(numel(st.EpisodeReward), 40);
            p1 = getLearnableParameters(getActor(ag));
            tc.verifyFalse(isequal(p0, p1), 'actor parameters must change: agent genuinely trained');
            f = fullfile(tempdir, 'p14_agent.mat'); saveAgent = ag; save(f, 'saveAgent'); L = load(f);
            ag.UseExplorationPolicy = false; L.saveAgent.UseExplorationPolicy = false;
            o = mineguard.rl.observationVector(mineguard.rl.resetSurvey(G, cfg), G, cfg);
            tc.verifyEqual(getAction(L.saveAgent, {o}), getAction(ag, {o}));
            % Frozen experiment artifacts: real training record and checkpoint integrity.
            F = testMG013PPO.frozen();
            T = readtable(fullfile(testMG013PPO.Ev, 'MG-013-training-episodes.csv'));
            tc.verifyGreaterThanOrEqual(height(T), 1000);
            tc.verifyEqual(testMG013PPO.sha256(testMG013PPO.Ck), string(F.checkpoint_sha256));
        end

        function p15_splitLeakage(tc)
            M = readtable(fullfile(testMG013PPO.Ev, 'MG-013-split-manifest.csv'), 'TextType', 'string');
            mineguard.evaluation.validateSplitManifest(M);
            tc.verifyEmpty(intersect(M.seed(M.split_id == "train"), M.seed(M.split_id == "test")));
            tc.verifyFalse(any(startsWith(M.scenario_id, "GF-")), 'independent of MG-014 sealed families');
            bad = M; bad.group_key(end) = bad.group_key(1);
            tc.verifyError(@() mineguard.evaluation.validateSplitManifest(bad), 'mineguard:SplitLeakage');
            F = testMG013PPO.frozen();
            tc.verifyEqual(string(F.manifest_sha256), testMG013PPO.sha256(fullfile(testMG013PPO.Ev, 'MG-013-split-manifest.csv')));
            V = readtable(fullfile(testMG013PPO.Ev, 'MG-013-validation-selection.csv'));
            [~, b] = max(V.val_mean_coverage); tc.verifyEqual(F.selected_chunk, V.chunk(b), 'checkpoint chosen by VALIDATION');
        end

        function p16_pairedFeasibleComparison(tc)
            P = readtable(fullfile(testMG013PPO.Ev, 'MG-013-test-paired.csv'), 'TextType', 'string');
            fz = P(P.grid_feasible == 1, :);
            tc.verifyNotEmpty(fz);
            tc.verifyEqual(fz.delta_coverage, fz.ppo_coverage - fz.grid_coverage, 'AbsTol', 1e-12);
            tc.verifyEqual(fz.delta_distance_m, fz.ppo_distance_m - fz.grid_distance_m, 'AbsTol', 1e-9);
            tc.verifyTrue(all(fz.ppo_distance_m <= 60 + 1e-9 & fz.grid_distance_m <= 60 + 1e-9), 'shared D_max');
            % Re-run one feasible held-out pair with the frozen policy: identical numbers.
            sid = fz.scenario_id(1); seed = str2double(extractAfter(sid, "MG013-"));
            G = mg013Grid(seed, sid); cfg = mineguard.rl.defaultEnvConfig();
            Ep = mineguard.rl.runEpisode(G, cfg, testMG013PPO.frozenPolicy(), sid);
            Eg = mineguard.rl.runEpisode(G, cfg, mineguard.rl.gridBaselineSequence(G), sid);
            tc.verifyEqual([Ep.coverage_fraction Eg.coverage_fraction], [fz.ppo_coverage(1) fz.grid_coverage(1)], 'AbsTol', 1e-12);
            tc.verifyEqual(Ep.poses(1, 3:4), Eg.poses(1, 3:4), 'same start');
        end

        function p17_infeasibleBaselineHonest(tc)
            G = testMG013PPO.grid({[4 4; 6 4; 6 6; 4 6]});
            [seq, feas, reason] = mineguard.rl.gridBaselineSequence(G);
            tc.verifyFalse(feas); tc.verifyEmpty(seq); tc.verifyEqual(reason, "INFEASIBLE_ROUTE_CONFLICT");
            P = readtable(fullfile(testMG013PPO.Ev, 'MG-013-test-paired.csv'), 'TextType', 'string');
            S = jsondecode(fileread(fullfile(testMG013PPO.Ev, 'MG-013-test-summary.json')));
            tc.verifyEqual(S.n_grid_infeasible, nnz(P.grid_feasible == 0));
            tc.verifyTrue(all(isnan(P.delta_coverage(P.grid_feasible == 0))), 'no PPO "win" scored against an infeasible baseline');
        end

        function p18_stochasticEvaluationSeeded(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            pol = testMG013PPO.frozenPolicy(); pol.use_exploration = true;
            rng(4321, 'twister'); E1 = mineguard.rl.runEpisode(G, cfg, pol, "P18");
            rng(4321, 'twister'); E2 = mineguard.rl.runEpisode(G, cfg, pol, "P18");
            tc.verifyEqual(E1.actions, E2.actions, 'seeded stochastic rollouts reproduce');
            pd = testMG013PPO.frozenPolicy();
            D1 = mineguard.rl.runEpisode(G, cfg, pd, "P18d"); D2 = mineguard.rl.runEpisode(G, cfg, pd, "P18d");
            tc.verifyEqual(D1.actions, D2.actions, 'deterministic evaluation mode');
            T = readtable(fullfile(testMG013PPO.Ev, 'MG-013-test-stochastic-and-random.csv'), 'TextType', 'string');
            tc.verifyEqual(height(T), 50);
        end

        function p19_optionalSensorFeaturesGated(tc)
            G = testMG013PPO.grid(); cfg = mineguard.rl.defaultEnvConfig();
            [o, ac] = mineguard.rl.observationRecords(mineguard.rl.resetSurvey(G, cfg), G, cfg, "P19");
            id = 'mineguard:InvalidPolicyInput'; pol = testMG013PPO.untrained();
            o2 = o; o2.uncertainty = zeros(25, 1);  tc.verifyError(@() mineguard.rl.selectSurveyCell(o2, ac, pol), id);
            o3 = o; o3.vector(3) = NaN;              tc.verifyError(@() mineguard.rl.selectSurveyCell(o3, ac, pol), id);
            o4 = o; o4.vector = [o.vector; 0];       tc.verifyError(@() mineguard.rl.selectSurveyCell(o4, ac, pol), id);
            tc.verifyEqual(mineguard.rl.selectSurveyCell(o, ac, pol), int32(2));
        end

        function p20_evidenceAndRollback(tc)
            F = testMG013PPO.frozen();
            for f = ["checkpoint_sha256","train_seed","sampler_seed","hyperparameters","env","git_sha","matlab_release","manifest_sha256","selected_chunk"]
                tc.verifyTrue(isfield(F, f), f);
            end
            tc.verifyEqual(string(F.matlab_release), string(version('-release')));
            P = readtable(fullfile(testMG013PPO.Ev, 'MG-013-test-paired.csv'), 'TextType', 'string');
            sid = P.scenario_id(1); G = mg013Grid(str2double(extractAfter(sid, "MG013-")), sid);
            E = mineguard.rl.runEpisode(G, mineguard.rl.defaultEnvConfig(), testMG013PPO.frozenPolicy(), sid);
            tc.verifyEqual([E.coverage_fraction E.distance_m E.invalid_actions], [P.ppo_coverage(1) P.ppo_distance_m(1) P.ppo_invalid(1)], 'AbsTol', 1e-9);
            tc.verifyEqual(E.reason, P.ppo_reason(1));
        end
    end
end
