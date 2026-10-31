classdef testMG019PPOIntegration < matlab.uitest.TestCase
    %TESTMG019PPOINTEGRATION MG-019 acceptance tests: frozen PPO integrated into the MineGuard pipeline.
    %   Needs an interactive MATLAB desktop (it renders the real apps). Run from repo root:
    %     addpath('matlab'); runtests('matlab/tests/testMG019PPOIntegration.m')
    %   SIMULATION ONLY.

    properties (Constant)
        Root = fileparts(fileparts(fileparts(mfilename('fullpath'))))
    end
    properties
        Policy
        C7307; G7307; P7307; Rg; Rp
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(tc.Root, 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(tc.Root, 'matlab', 'experiments')));
            tc.Policy = mineguard.integration.loadPPOCheckpoint();
            tc.C7307 = mg019ScenarioConfig(7307);
            [tc.G7307, tc.Rg] = mineguard.integration.runSurveyMission(tc.C7307, "grid");
            [tc.P7307, tc.Rp] = mineguard.integration.runSurveyMission(tc.C7307, "ppo", struct('policy', tc.Policy));
        end
    end

    methods (Static)
        function G = grid(c)
            [g, ~] = mineguard.scenario.generateScenario(c);
            G = mineguard.rl.buildSurveyGrid(mineguard.navigation.navigationConfigFromExperiment(c), g);
        end
    end

    methods (Test)
        function t01_checkpointShaAndReload(tc)
            tc.verifyEqual(tc.Policy.checksum, "5a0da1715a1c2f7044a3b954d8cdf5e6d234731a2f4619d82cb3ea87e875b8ad");
            tc.verifyClass(tc.Policy.agent, 'rl.agent.rlPPOAgent'); tc.verifyFalse(tc.Policy.agent.UseExplorationPolicy);
            tc.verifyError(@() mineguard.integration.loadPPOCheckpoint("", repmat('0', 1, 64)), 'mineguard:CheckpointMismatch');
            tc.verifyError(@() mineguard.integration.loadPPOCheckpoint(fullfile(tempdir, 'no_such_checkpoint.mat')), 'mineguard:CheckpointMissing');
            f = [tempname '.mat']; x = 1; save(f, 'x'); tc.addTeardown(@() delete(f));
            [~, o] = system(sprintf('certutil -hashfile "%s" SHA256', f)); l = splitlines(string(o)); h = lower(erase(strtrim(l(2)), " "));
            tc.verifyError(@() mineguard.integration.loadPPOCheckpoint(f, h), 'mineguard:CheckpointInvalid', 'never substitute a heuristic');
        end

        function t02_actionsComeFromTrainedAgent(tc)
            G = testMG019PPOIntegration.grid(tc.C7307);
            E = mineguard.rl.runEpisode(G, mineguard.rl.defaultEnvConfig(), tc.Policy, tc.C7307.scenario_id);
            tc.verifyEqual(E.actions, tc.Rp.actions, 'record actions = selectSurveyCell decisions of the frozen agent');
            o = mineguard.rl.observationVector(mineguard.rl.resetSurvey(G, mineguard.rl.defaultEnvConfig()), G, mineguard.rl.defaultEnvConfig());
            a = getAction(tc.Policy.agent, {o}); tc.verifyEqual(double(a{1}), tc.Rp.actions(1));
            tc.verifyNotEqual(tc.Rp.actions(:)', 2:numel(tc.Rp.actions) + 1, 'not a renamed serpentine route');
        end

        function t03_observationActionCompatibility(tc)
            oi = getObservationInfo(tc.Policy.agent); ai = getActionInfo(tc.Policy.agent);
            tc.verifyEqual(oi.Dimension, [55 1]); tc.verifyEqual(double(ai.Elements(:))', 1:25);
            G = testMG019PPOIntegration.grid(tc.C7307); tc.verifyEqual(G.N, 25);
            v = mineguard.rl.observationVector(mineguard.rl.resetSurvey(G, mineguard.rl.defaultEnvConfig()), G, mineguard.rl.defaultEnvConfig());
            tc.verifySize(v, [55 1]);
        end

        function t04_rejects25v100Mismatch(tc)
            c = mg015GroupConfig("GF-001", mg015DetectorSettings("RUNLOCK"));   % 20x20 m, 2 m cells -> 100 cells (TRAIN family)
            tc.verifyError(@() mineguard.integration.runSurveyMission(c, "ppo", struct('policy', tc.Policy)), 'mineguard:IncompatiblePolicy');
            G = testMG019PPOIntegration.grid(c); cfg = mineguard.rl.defaultEnvConfig();
            [o, ac] = mineguard.rl.observationRecords(mineguard.rl.resetSurvey(G, cfg), G, cfg, "X");
            tc.verifyError(@() mineguard.rl.selectSurveyCell(o, ac, tc.Policy), 'mineguard:InvalidPolicyInput');
        end

        function t05_truthFirewall(tc)
            txt = jsonencode(struct('p', tc.P7307.poses, 't', tc.P7307.thermal_samples, 'e', tc.P7307.em_samples, ...
                'v', tc.P7307.events, 'g', tc.P7307.geometry, 'pr', tc.P7307.provenance));
            tc.verifyFalse(contains(txt, ["OBJ-","""label""","synthetic_cased","burial_depth","target_count"]));
            tc.verifyFalse(contains(jsonencode(rmfield(tc.Rp, 'actions')), ["OBJ-","burial","label"]));
            p2 = tc.Policy; p2.meta = struct('label', "target");
            G = testMG019PPOIntegration.grid(tc.C7307); cfg = mineguard.rl.defaultEnvConfig();
            [o, ac] = mineguard.rl.observationRecords(mineguard.rl.resetSurvey(G, cfg), G, cfg, "X");
            tc.verifyError(@() mineguard.rl.selectSurveyCell(o, ac, p2), 'mineguard:InvalidPolicyInput');
            src = fileread(fullfile(tc.Root, 'matlab', '+mineguard', '+integration', 'runSurveyMission.m'));
            tc.verifySubstring(src, 'detectAnomalies(dc, poses, samples, ds.model)');
            tc.verifySubstring(src, 'mineguard.rl.runEpisode(G, cfg, policy, string(config.scenario_id))');
            tc.verifyEqual(numel(regexp(src, '\<truth\>(?!_)', 'match')) >= 1, true);
            r = runtests(fullfile(tc.Root, 'matlab', 'tests', 'testMG013PPO.m'), 'ProcedureName', 'p03_truthFirewall');
            tc.verifyTrue(r.Passed, 'MG-013 P-03 source/injection firewall regression');
        end

        function t06_invalidActionsRejectedAndPenalised(tc)
            c = mg019ScenarioConfig(7306); [~, r] = mineguard.integration.runSurveyMission(c, "ppo", struct('policy', tc.Policy));
            tc.verifyEqual(r.reason, "MAX_STEPS"); tc.verifyEqual(r.invalid_actions, 43); tc.verifyEqual(r.decisions, 50);
            G = testMG019PPOIntegration.grid(c); cfg = mineguard.rl.defaultEnvConfig();
            E = mineguard.rl.runEpisode(G, cfg, tc.Policy, c.scenario_id);
            bad = E.reward_log(:, 5) == 1;
            tc.verifyEqual(nnz(bad), 43);
            tc.verifyEqual(E.reward_log(bad & E.reward_log(:, 7) == 0, end), repmat(-cfg.w.bad - cfg.w.step, nnz(bad & E.reward_log(:, 7) == 0), 1), 'AbsTol', 1e-12);
            tc.verifyTrue(all(E.reward_log(bad, 2) == 0), 'rejected actions do not move the vehicle');
        end

        function t07_deterministicReplay(tc)
            [b2, r2] = mineguard.integration.runSurveyMission(tc.C7307, "ppo", struct('policy', tc.Policy));
            a = tc.P7307; a.provenance = rmfield(a.provenance, 'run_timestamp_utc'); b2.provenance = rmfield(b2.provenance, 'run_timestamp_utc');
            tc.verifyTrue(isequaln(a, b2));
            tc.verifyTrue(isequaln(rmfield(tc.Rp, 'runtime_s'), rmfield(r2, 'runtime_s')));
        end

        function t08_equalBudgetsAndStart(tc)
            tc.verifyEqual(tc.Rg.budget, tc.Rp.budget); tc.verifyEqual(tc.Rg.budget, [60 30 50]);
            tc.verifyEqual(tc.Rg.start_cell, tc.Rp.start_cell);
            tc.verifyEqual(tc.G7307.poses{1, {'x_east_m','y_north_m','z_up_m'}}, tc.P7307.poses{1, {'x_east_m','y_north_m','z_up_m'}});
            tc.verifyLessThanOrEqual([tc.Rg.distance_m tc.Rp.distance_m], 60 + 1e-9); tc.verifyLessThanOrEqual([tc.Rg.mission_time_s tc.Rp.mission_time_s], 30 + 1e-9);
            tc.verifyEqual(unique([tc.G7307.poses.z_up_m; tc.P7307.poses.z_up_m]), 2);
            tc.verifyEqual(tc.G7307.thermal_samples(1, :).noise_sigma, tc.P7307.thermal_samples(1, :).noise_sigma, 'same sensor settings');
            tc.verifyEqual(tc.G7307.provenance.detector_model_version, tc.P7307.provenance.detector_model_version);
        end

        function t09_poseAndCoverageMG005(tc)
            c = tc.C7307; [g, ~] = mineguard.scenario.generateScenario(c); nav = mineguard.navigation.navigationConfigFromExperiment(c);
            for rb = {tc.G7307, tc.P7307}
                b = rb{1}; cov = mineguard.navigation.computeCoverage(nav, g, b.poses);
                tc.verifyEqual(cov.coverage_fraction, b.coverage.coverage_fraction); tc.verifyEqual(cov.visited_valid_cells, b.coverage.visited_valid_cells);
                tc.verifyTrue(all(diff(b.poses.t_s) > 0)); tc.verifyEqual(numel(unique(b.poses.pose_sample_id)), height(b.poses));
                tc.verifyLessThanOrEqual(max(hypot(diff(b.poses.x_east_m), diff(b.poses.y_north_m))), nav.speed_mps * nav.dt_s + 1e-9);
            end
            route = mineguard.navigation.makeGridRoute(nav, g);
            tc.verifyEqual(tc.G7307.route_enu_m(:, 1:2), route(:, 1:2), 'AbsTol', 1e-12);
            tc.verifyEqual([tc.Rg.coverage_fraction tc.Rg.distance_m tc.Rg.mission_time_s], [1 48 24], 'AbsTol', 1e-9);
        end

        function t10_sensorsAlongPPORoute(tc)
            b = tc.P7307;
            tc.verifyEqual(height(b.thermal_samples), height(b.poses)); tc.verifyEqual(height(b.em_samples), height(b.poses));
            tc.verifyEqual(b.thermal_samples.pose_sample_id, b.poses.pose_sample_id); tc.verifyEqual(b.em_samples.t_s, b.poses.t_s);
            tc.verifyTrue(all(b.thermal_samples.temperature_K > 250 & b.thermal_samples.temperature_K < 350));
            tc.verifyFalse(isequal(b.thermal_samples.temperature_K(1:min(end, height(tc.G7307.thermal_samples))), ...
                tc.G7307.thermal_samples.temperature_K(1:min(height(b.thermal_samples), end))), 'different routes -> different readings');
        end

        function t11_detectorEvaluatorSeparation(tc)
            c = tc.C7307; [~, truth] = mineguard.scenario.generateScenario(c); b = tc.P7307;
            nx = 5; cellOf = @(x, y) (min(5, floor(y / 2) + 1) - 1) * nx + min(5, floor(x / 2) + 1);
            tCells = unique(cellOf(truth.x_east_m(string(truth.label) == "target"), truth.y_north_m(string(truth.label) == "target")));
            visited = unique(cellOf(b.poses.x_east_m, b.poses.y_north_m));
            tEval = intersect(tCells, visited);
            eCells = unique(cellOf(b.events.x_est_m, b.events.y_est_m));
            tp = numel(intersect(tEval, eCells)); fp = numel(setdiff(intersect(eCells, visited), tCells)); fn = numel(setdiff(tEval, eCells));
            tc.verifyEqual([tc.Rp.tp tc.Rp.fp tc.Rp.fn], [tp fp fn], 'independent recount (all visited cells evaluable here)');
            tc.verifyEqual(tc.Rp.evaluable_cells, numel(visited));
        end

        function t12_bundlesValid(tc)
            mineguard.app.validateRunBundle(tc.G7307); mineguard.app.validateRunBundle(tc.P7307);
            tc.verifyEqual(tc.P7307.provenance.run_id, "MG019-PPO-" + tc.C7307.scenario_id);
            tc.verifySubstring(tc.P7307.provenance.simulation_flags, "planner=PPO");
            tc.verifyTrue(all(tc.P7307.events.status == "SUSPECTED"));
        end

        function t13_metricArithmetic(tc)
            T = mineguard.integration.comparisonTable({tc.Rg, tc.Rp});
            tc.verifyEqual(T.planner', ["grid" "ppo"]);
            tc.verifyEqual(T.coverage_per_m, T.coverage_fraction ./ T.distance_m, 'AbsTol', 1e-12);
            tc.verifyEqual(T.coverage_per_s, T.coverage_fraction ./ T.mission_time_s, 'AbsTol', 1e-12);
            tc.verifyEqual(T.unique_cells ./ T.n_legal, T.coverage_fraction, 'AbsTol', 1e-12);
            P = readtable(fullfile(tc.Root, 'tasks', 'evidence', 'MG-019', 'MG-019-paired-missions.csv'), 'TextType', 'string');
            f = P.grid_feasible == 1;
            tc.verifyEqual(P.delta_coverage(f), P.ppo_coverage(f) - P.grid_coverage(f), 'AbsTol', 1e-12);
            tc.verifyTrue(all(isnan(P.delta_coverage(~f))), 'no delta against an infeasible grid');
            [~, gi] = mineguard.integration.runSurveyMission(mg019ScenarioConfig(7301), "grid");
            tc.verifyFalse(gi.executed); tc.verifyEqual(gi.reason, "INFEASIBLE_ROUTE_CONFLICT"); tc.verifyTrue(isnan(gi.coverage_fraction));
        end

        function t14_emptySensorData(tc)
            c = tc.C7307; c = rmfield(c, 'sensor_settings');
            [b, r] = mineguard.integration.runSurveyMission(c, "ppo", struct('policy', tc.Policy));
            tc.verifyEqual([r.events r.evaluable_cells r.tp r.fp r.tn r.fn], [0 0 0 0 0 0]);
            tc.verifyTrue(all(isnan([r.precision r.recall r.f1 r.fpr])));
            tc.verifyEqual(r.coverage_fraction, tc.Rp.coverage_fraction, 'navigation unaffected by missing sensors');
            tc.verifyTrue(all(b.thermal_samples.invalid_reason == "UNCONFIGURED_SENSOR") && all(isnan(b.thermal_samples.temperature_K)));
        end

        function t15_dashboardReplay(tc)
            b = tc.P7307; b.comparison = mineguard.integration.comparisonTable({tc.Rg, tc.Rp});
            app = mineguard.app.openMissionApp(b); tc.addTeardown(@() app.close()); h = app.uiHandles();
            tc.press(h.play); pause(0.6); tc.press(h.pause); tc.verifyEqual(app.State, "PAUSED");
            app.seek(b.poses.t_s(end)); v = app.viewState();
            tc.verifyEqual(v.trace_points, height(b.poses)); tc.verifyEqual(h.trace.XData(:), b.poses.x_east_m);
            tc.verifyTrue(any(contains(string(h.eval.Value), "PPO vs fixed-grid comparison: supplied")));
            g = tc.G7307; g.comparison = b.comparison;
            ca = mineguard.app.openComparisonApp(g, b, b.comparison); tc.addTeardown(@() ca.close());
            s = ca.viewState();
            tc.verifyEqual([s.grid_route_points s.ppo_route_points], [height(g.poses) height(b.poses)]);
            tc.verifyEqual([s.grid_events s.ppo_events], [height(g.events) height(b.events)]);
            tc.verifySubstring(s.banner, "SIMULATION"); tc.verifySubstring(s.ppo_title, "PPO"); tc.verifyEqual(s.table_rows, 2);
            r1 = ca.openReplay("ppo"); tc.verifyClass(r1, 'mineguard.app.MissionApp');
            c1 = mg019ScenarioConfig(7301); [~, gi] = mineguard.integration.runSurveyMission(c1, "grid");
            [pb, pr] = mineguard.integration.runSurveyMission(c1, "ppo", struct('policy', tc.Policy));
            ci = mineguard.app.openComparisonApp([], pb, mineguard.integration.comparisonTable({gi, pr})); tc.addTeardown(@() ci.close());
            tc.verifySubstring(ci.viewState().grid_title, "NOT RUN"); tc.verifyEmpty(ci.openReplay("grid")); tc.verifySubstring(ci.StatusText, "NOT AVAILABLE");
            tc.verifyTrue(any(contains(ci.viewState().summary, "not a PPO 'win'")));
        end

        function t16_exportReadback(tc)
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            ca = mineguard.app.openComparisonApp(tc.G7307, tc.P7307, mineguard.integration.comparisonTable({tc.Rg, tc.Rp})); tc.addTeardown(@() ca.close());
            tc.verifyTrue(ca.exportComparison(d));
            T = readtable(fullfile(ca.LastExport.folder, 'comparison.csv'), 'TextType', 'string'); tc.verifyEqual(height(T), 2);
            tc.verifyGreaterThan(size(imread(fullfile(ca.LastExport.folder, 'comparison.png')), 1), 200);
            tc.verifyFalse(ca.exportComparison(0)); tc.verifySubstring(ca.StatusText, "cancelled");
            app = mineguard.app.openMissionApp(tc.P7307); tc.addTeardown(@() app.close());
            tc.verifyTrue(app.exportRun(d)); m = load(fullfile(app.LastExport.folder, 'run_bundle_redacted.mat'));
            tc.verifyTrue(isequaln(m.runBundle, tc.P7307));
        end

        function t17_originalDemoAndDashboardPreserved(tc)
            [~, o] = system(sprintf('git -C "%s" diff --stat origin/main -- matlab/+mineguard/runExperiment.m matlab/mineguardDemo.m matlab/+mineguard/+rl', tc.Root));
            tc.verifyEqual(strtrim(string(o)), "", 'runExperiment, mineguardDemo and +rl unchanged');
            [rb, rec] = mineguard.runExperiment(mg015DemoConfig("S0"));
            tc.verifyEqual([rb.result.tp rb.result.fp rb.result.tn rb.result.fn height(rb.events)], [1 4 395 0 5]);
            tc.verifyEqual(rec.evaluable_cells, 400);
            app = mineguard.app.openMissionApp(rb); tc.addTeardown(@() app.close());
            tc.verifyTrue(any(contains(string(app.uiHandles().eval.Value), "PPO comparison: NOT RUN")), 'no comparison -> unchanged NOT RUN text');
        end

        function t18_incompletePPOMission(tc)
            c = mg019ScenarioConfig(7315); [b, r] = mineguard.integration.runSurveyMission(c, "ppo", struct('policy', tc.Policy));
            tc.verifyFalse(r.completed); tc.verifyEqual(r.reason, "MAX_STEPS"); tc.verifyLessThan(r.coverage_fraction, 1);
            tc.verifyEqual(r.invalid_actions, 48);
            mineguard.app.validateRunBundle(b);
            app = mineguard.app.openMissionApp(b); tc.addTeardown(@() app.close()); app.seek(b.poses.t_s(end));
            tc.verifyEqual(app.viewState().trace_points, height(b.poses));
            tc.verifyTrue(all(tc.Rp.reason ~= "COVERAGE_GOAL") || tc.Rp.completed, 'completion flag consistent with reason');
        end

        function t20_comparisonAllowlistAccepted(tc)
            % Review correction: the valid comparison table matches the exact public allowlist.
            T = mineguard.integration.comparisonTable({tc.Rg, tc.Rp});
            tc.verifyEqual(string(T.Properties.VariableNames), mineguard.contract.comparisonColumns());
            mineguard.app.validateComparisonTable(T);
            b = tc.P7307; b.comparison = T; mineguard.app.validateRunBundle(b);
            c1 = mg019ScenarioConfig(7301); [~, gi] = mineguard.integration.runSurveyMission(c1, "grid");
            mineguard.app.validateComparisonTable(mineguard.integration.comparisonTable({gi, tc.Rp}));   % NaN rows (infeasible grid) allowed
        end

        function t21_comparisonRejectsUnexpectedColumns(tc)
            % Hidden-truth fields and misleading alternative names are rejected everywhere.
            T = mineguard.integration.comparisonTable({tc.Rg, tc.Rp});
            bad = ["label","target_count","clutter_count","burial_depth_m","target_id","material_type","x_east_m", ...
                   "hidden_truth","accuracy","detection_accuracy","detection_rate","mines_found","mine_count", ...
                   "safe_fraction","cleared_cells","confirmed_mines","probability","true_targets"];
            for c = bad
                X = T; X.(c) = zeros(height(T), 1);
                tc.verifyError(@() mineguard.app.validateComparisonTable(X), 'mineguard:InvalidComparison', c);
                b = tc.P7307; b.comparison = X;
                tc.verifyError(@() mineguard.app.validateRunBundle(b), 'mineguard:InvalidRunBundle', c);
                tc.verifyError(@() mineguard.app.openComparisonApp(tc.G7307, tc.P7307, X), 'mineguard:InvalidComparison', c);
            end
            % Renamed column (alias) and missing column are also rejected.
            X = renamevars(T, 'coverage_fraction', 'coverage'); tc.verifyError(@() mineguard.app.validateComparisonTable(X), 'mineguard:InvalidComparison');
            X = removevars(T, 'fp');                         tc.verifyError(@() mineguard.app.validateComparisonTable(X), 'mineguard:InvalidComparison');
            X = T(:, [2 1 3:end]);                           tc.verifyError(@() mineguard.app.validateComparisonTable(X), 'mineguard:InvalidComparison');
        end

        function t22_comparisonRejectsBadValues(tc)
            T = mineguard.integration.comparisonTable({tc.Rg, tc.Rp}); id = 'mineguard:InvalidComparison';
            X = T; X.planner(2) = "ppo2";               tc.verifyError(@() mineguard.app.validateComparisonTable(X), id);
            X = T; X.planner(2) = "grid";               tc.verifyError(@() mineguard.app.validateComparisonTable(X), id);
            X = T; X.coverage_fraction(1) = 1.5;        tc.verifyError(@() mineguard.app.validateComparisonTable(X), id);
            X = T; X.tp(1) = 0.5;                       tc.verifyError(@() mineguard.app.validateComparisonTable(X), id);
            X = T; X.distance_m(1) = Inf;               tc.verifyError(@() mineguard.app.validateComparisonTable(X), id);
            X = T; X.executed = double(X.executed);     tc.verifyError(@() mineguard.app.validateComparisonTable(X), id);
            tc.verifyError(@() mineguard.app.validateComparisonTable(table2struct(T)), id);
        end

        function t23_exportUsesAllowlist(tc)
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            ca = mineguard.app.openComparisonApp(tc.G7307, tc.P7307, mineguard.integration.comparisonTable({tc.Rg, tc.Rp})); tc.addTeardown(@() ca.close());
            tc.verifyTrue(ca.exportComparison(d));
            R = readtable(fullfile(ca.LastExport.folder, 'comparison.csv'), 'TextType', 'string');
            tc.verifyEqual(string(R.Properties.VariableNames), mineguard.contract.comparisonColumns(), 'exported columns = exact allowlist');
            src = fileread(fullfile(tc.Root, 'matlab', '+mineguard', '+app', 'ComparisonApp.m'));
            tc.verifySubstring(src, 'mineguard.app.validateComparisonTable(app.Comparison);');
        end

        function t19_evidenceConsistency(tc)
            ev = fullfile(tc.Root, 'tasks', 'evidence', 'MG-019');
            P = readtable(fullfile(ev, 'MG-019-paired-missions.csv'), 'TextType', 'string');
            tc.verifyEqual(height(P), 30); tc.verifyEqual(nnz(P.set == "evaluation"), 20);
            S = jsondecode(fileread(fullfile(ev, 'MG-019-summary.json')));
            tc.verifyEqual(string(S.checkpoint_sha256), tc.Policy.checksum);
            tc.verifyEqual(S.evaluation.n_grid_feasible, nnz(P.grid_feasible(P.set == "evaluation") == 1));
            k = P.set == "evaluation" & P.seed == 7307;
            tc.verifyEqual([P.ppo_coverage(k) P.grid_coverage(k) P.ppo_invalid(k)], [tc.Rp.coverage_fraction tc.Rg.coverage_fraction tc.Rp.invalid_actions], 'AbsTol', 1e-12);
        end
    end
end
