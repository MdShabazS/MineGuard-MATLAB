classdef testMG009Detection < matlab.unittest.TestCase
    %TESTMG009DETECTION MG-008 acceptance tests F-01..F-18 for MG-009 detection, fusion and evaluation.
    %   Run from repo root: addpath('matlab'); runtests('matlab/tests/testMG009Detection.m')
    %   SIMULATION ONLY. These tests check software correctness on synthetic data, not mine detection.

    methods (TestClassSetup)
        function addPaths(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'experiments')));
        end
    end

    methods (Static)
        function P = poses(x, y, t)
            n = numel(x);
            P = table(compose("P-%06d", (1:n)'), t(:), x(:), y(:), repmat(0.3, n, 1), NaN(n, 1), ...
                'VariableNames', {'pose_sample_id','t_s','x_east_m','y_north_m','z_up_m','gps_sigma_m'});
        end
        function S = samples(kind, P, rows, values, valid)
            % kind "thermal" (values in K) or "em" (normalised). rows index into P.
            n = numel(rows);
            pre = "TH"; if kind == "em", pre = "EM"; end
            temp = NaN(n,1); resp = NaN(n,1);
            if kind == "thermal", temp(:) = values; else, resp(:) = values; end
            if nargin < 5, valid = true(n,1); end
            valid = logical(valid(:));
            reason = strings(n,1); reason(~valid) = "DROPPED_SAMPLE";
            temp(~valid & kind == "thermal") = NaN; resp(~valid & kind == "em") = NaN;
            S = table(compose(pre + "-%06d", (1:n)'), P.pose_sample_id(rows), P.t_s(rows), repmat(string(kind), n, 1), ...
                temp, resp, repmat(0.1, n, 1), repmat(0.3, n, 1), repmat(0.1, n, 1), valid, reason, ...
                'VariableNames', {'sample_id','pose_sample_id','t_s','sensor_kind','temperature_K','response_norm', ...
                'noise_sigma','standoff_m','footprint_radius_m','valid','invalid_reason'});
        end
        function m = model()
            m = struct('version', "test-model", 'thermal_background_K', 293.15, 'thermal_scale_K', 0.1, ...
                'em_background_norm', 0.05, 'em_scale_norm', 0.02, 'thermal_z_threshold', 3, 'em_z_threshold', 3, ...
                'w_thermal', 0.5, 'w_em', 0.5, 'cluster_time_window_s', 1, 'cluster_radius_m', 0.75, ...
                'weighted_fallback', struct('thermal_z_threshold', 3, 'em_z_threshold', 3), ...
                'provenance', struct('normaliser_split', "train", 'threshold_split', "validation"));
        end
        function dc = dc(method, rule, thr, tol)
            if nargin < 4, tol = 0.05; end
            dc = struct('schema_version', "mg-contract/1.0", 'scenario_id', "UNIT", 'association_tolerance_s', tol, ...
                'threshold', thr, 'method_name', string(method), 'missing_modality_rule', string(rule));
        end
        function rm = meta(mask, b, s)
            if nargin < 2, b = [0 2 0 2]; end
            if nargin < 3, s = 1; end
            rm = struct('scenario_id', "UNIT", 'grid', struct('bounds_enu_m', b, 'grid_spacing_m', s, 'exclusion_polygons_enu_m', {{}}), ...
                'evaluable_cell_mask', mask, 'algorithm', "unit", 'split_id', "test", 'localization_match_radius_m', 0.75);
        end
        function c = cfg()
            c = struct('schema_version', "mg-contract/1.0", 'scenario_id', "UNIT", 'seed', 1);
        end
        function ev = events(xy)
            n = size(xy, 1);
            ev = table(compose("EV-%05d", (1:n)'), zeros(n,1), xy(:,1), xy(:,2), NaN(n,1), NaN(n,1), strings(n,1), strings(n,1), ...
                repmat("or", n, 1), ones(n,1), repmat("SUSPECTED", n, 1), true(n,1), 'VariableNames', {'event_id','t_s','x_est_m', ...
                'y_est_m','confidence_0_1','uncertainty_m','thermal_sample_id','em_sample_id','method_name','threshold','status','valid'});
        end
        function t = truth(xy, labels)
            n = size(xy, 1);
            t = table(compose("OBJ-%04d", (1:n)'), xy(:,1), xy(:,2), repmat(0.05, n, 1), repmat("synthetic_metal_cased_surrogate", n, 1), ...
                categorical(labels(:), ["target" "clutter"]), repmat("synthetic_loam", n, 1), false(n,1), ...
                'VariableNames', {'target_id','x_east_m','y_north_m','burial_depth_m','material_type','label','soil_class','surface_exposed'});
        end
        function c = trialCfg(id, seed, nT, nC)
            c = struct('schema_version', "mg-contract/1.0", 'scenario_id', string(id), 'seed', seed, 'x_min_m', 0, 'x_max_m', 4, ...
                'y_min_m', 0, 'y_max_m', 4, 'terrain_id', "flat-datum", 'grid_spacing_m', 0.5, 'dt_s', 0.1, 'sampling_hz', 10, ...
                'altitude_m', 0.3, 'speed_mps', 2, 'noise_seed', seed + 50000, 'target_count', nT, 'clutter_count', nC, ...
                'min_separation_m', 0.5, 'soil_class', "synthetic_loam", 'model_version', "mg009-test");
            c.sensor_settings = mg007FixtureSettings();
        end
        function t = metal(t)
            t.material_type(:) = "synthetic_metal_cased_surrogate";
        end
        function t = shallow(t)
            t.burial_depth_m(:) = 0.02;
        end
    end

    methods (Test)
        function f01_pairingUnitsAndFusionRules(tc)
            P = testMG009Detection.poses([1 2 3], [1 1 1], [0 0.1 0.2]);
            S = [testMG009Detection.samples("thermal", P, 1:3, [293.65 293.15 293.65]); ...
                 testMG009Detection.samples("em", P, 1:3, [0.05 0.15 0.15])];      % z: T [5 0 5], EM [0 5 5]
            m = testMG009Detection.model();
            run = @(meth, thr) mineguard.detection.detectAnomalies(testMG009Detection.dc(meth, "abstain", thr), P, S, m);
            cols = ["event_id","t_s","x_est_m","y_est_m","confidence_0_1","uncertainty_m","thermal_sample_id", ...
                "em_sample_id","method_name","threshold","status","valid"];
            e = run("thermal_only", 3); tc.verifyEqual(e.x_est_m', [1 3]);
            tc.verifyEqual(string(e.Properties.VariableNames), cols);
            e = run("em_only", 3);      tc.verifyEqual(e.x_est_m', [2 3]);
            e = run("or", 1);           tc.verifyEqual(e.x_est_m', [1 2 3]);
            e = run("and", 1);          tc.verifyEqual(e.x_est_m', 3);
            tc.verifyEqual([e.thermal_sample_id e.em_sample_id], ["TH-000003" "EM-000003"]);   % same-pose pairing
            e = run("weighted", 3);     tc.verifyEqual(e.x_est_m', 3);          % 0.5*5+0.5*5 = 5
            e = run("weighted", 2.4);   tc.verifyEqual(e.x_est_m', [1 2 3]);    % about 2.5 at poses 1 and 2 (floating 0.15-0.05)
            tc.verifyEqual(e.method_name, repmat("weighted", 3, 1)); tc.verifyEqual(e.threshold, repmat(2.4, 3, 1));
            tc.verifyEqual(e.status, repmat("SUSPECTED", 3, 1)); tc.verifyTrue(all(isnan(e.confidence_0_1)));
        end

        function f02_toleranceTiesNoDuplicateUse(tc)
            m = testMG009Detection.model();
            P = testMG009Detection.poses([1 1], [1 1], [0 0.04]);
            S = [testMG009Detection.samples("thermal", P, 1, 293.65); testMG009Detection.samples("em", P, 2, 0.15)];
            [~, d0] = mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "single_valid", 1, 0), P, S, m);
            [~, d1] = mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "single_valid", 1, 0.05), P, S, m);
            tc.verifyEqual([d0.paired_candidates d0.thermal_only_candidates d0.em_only_candidates], [0 1 1]);
            tc.verifyEqual([d1.paired_candidates d1.thermal_only_candidates d1.em_only_candidates], [1 0 0]);
            % Equal |dt| tie: the earlier EM time wins.
            P = testMG009Detection.poses([5 1 9], [1 1 1], [0.5 0.25 0.75]);       % binary-exact times: |dt| 0.25 both
            S = [testMG009Detection.samples("thermal", P, 1, 293.65); testMG009Detection.samples("em", P, [2 3], [0.15 0.15])];
            e = mineguard.detection.detectAnomalies(testMG009Detection.dc("and", "abstain", 1, 0.25), P, S, m);
            tc.verifyEqual(e.em_sample_id, "EM-000001");
            % Same-time tie: the lexicographically smaller sample_id wins.
            S2 = S; S2.t_s(S2.sensor_kind == "em") = 0.5; S2.pose_sample_id(S2.sensor_kind == "em") = "P-000001";
            S2.sample_id(S2.sensor_kind == "em") = ["EM-B"; "EM-A"];
            e = mineguard.detection.detectAnomalies(testMG009Detection.dc("and", "abstain", 1, 0.25), P, S2, m);
            tc.verifyEqual(e.em_sample_id, "EM-A");
            % One EM sample cannot serve two thermal samples.
            P = testMG009Detection.poses([1 1 1], [1 1 1], [0 0.02 0.01]);
            S = [testMG009Detection.samples("thermal", P, [1 2], [293.65 293.65]); testMG009Detection.samples("em", P, 3, 0.15)];
            [~, d] = mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "single_valid", 1, 0.05), P, S, m);
            tc.verifyEqual([d.paired_candidates d.thermal_only_candidates d.em_only_candidates], [1 1 0]);
        end

        function f03_missingModalityRules(tc)
            m = testMG009Detection.model();
            P = testMG009Detection.poses(1, 1, 0);
            tInv = testMG009Detection.samples("thermal", P, 1, 293.65, false);
            eVal = testMG009Detection.samples("em", P, 1, 0.15);
            tVal = testMG009Detection.samples("thermal", P, 1, 293.65);
            eInv = testMG009Detection.samples("em", P, 1, 0.15, false);
            n = @(meth, rule, S) height(mineguard.detection.detectAnomalies(testMG009Detection.dc(meth, rule, ...
                1 + 2 * ismember(meth, ["thermal_only","em_only","weighted"])), P, S, m));
            S = [tInv; eVal];                 % thermal invalid, EM valid
            tc.verifyEqual(n("or", "single_valid", S), 1); tc.verifyEqual(n("or", "abstain", S), 0);
            tc.verifyEqual(n("or", "require_both", S), 0); tc.verifyEqual(n("em_only", "single_valid", S), 1);
            tc.verifyEqual(n("em_only", "require_both", S), 0); tc.verifyEqual(n("thermal_only", "single_valid", S), 0);
            tc.verifyEqual(n("weighted", "single_valid", S), 1); tc.verifyEqual(n("weighted", "abstain", S), 0);
            for r = ["single_valid","abstain","require_both"], tc.verifyEqual(n("and", r, S), 0, 'AND never single'); end
            e = mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "single_valid", 1), P, S, m);
            tc.verifyEqual(e.thermal_sample_id, ""); tc.verifyEqual(e.em_sample_id, "EM-000001");
            S = [tVal; eInv];                 % reverse
            tc.verifyEqual(n("or", "single_valid", S), 1); tc.verifyEqual(n("thermal_only", "abstain", S), 1);
            tc.verifyEqual(n("thermal_only", "require_both", S), 0); tc.verifyEqual(n("em_only", "single_valid", S), 0);
            S = [tInv; eInv];                 % both invalid: typed empty events everywhere
            for meth = ["thermal_only","em_only","or","and","weighted"]
                for r = ["single_valid","abstain","require_both"]
                    e = mineguard.detection.detectAnomalies(testMG009Detection.dc(meth, r, 1), P, S, m);
                    tc.verifyEqual(height(e), 0); tc.verifyEqual(width(e), 12); tc.verifyClass(e.event_id, 'string');
                end
            end
            tc.verifyTrue(isnan(S.temperature_K(1)) && isnan(S.response_norm(2)), 'invalid inputs stay NaN');
            % Weighted + single_valid without a frozen fallback is refused.
            m2 = rmfield(m, 'weighted_fallback');
            tc.verifyError(@() mineguard.detection.detectAnomalies(testMG009Detection.dc("weighted", "single_valid", 3), P, [tVal; eInv], m2), ...
                'mineguard:InvalidDetectorModel');
            tc.verifyError(@() mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "fallback_any", 1), P, S, m), ...
                'mineguard:InvalidDetectorConfig');
        end

        function f04_truthFirewall(tc)
            m = testMG009Detection.model();
            P = testMG009Detection.poses(1, 1, 0);
            S = [testMG009Detection.samples("thermal", P, 1, 293.65); testMG009Detection.samples("em", P, 1, 0.15)];
            for f = ["target_count","hidden_truth","label","x_east_m"]
                d = testMG009Detection.dc("or", "abstain", 1); d.(f) = 1;
                tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, S, m), 'mineguard:InvalidDetectorConfig', f);
            end
            m2 = m; m2.provenance.leak = struct('label', "target");
            tc.verifyError(@() mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "abstain", 1), P, S, m2), 'mineguard:InvalidDetectorModel');
            m3 = m; m3.truth = table(1);
            tc.verifyError(@() mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "abstain", 1), P, S, m3), 'mineguard:InvalidDetectorModel');
            tc.verifyEqual(nargin('mineguard.detection.detectAnomalies'), 4);
            files = dir(fullfile(fileparts(which('mineguard.detection.detectAnomalies')), '**', '*.m'));
            for k = 1:numel(files)
                code = strjoin(regexprep(splitlines(string(fileread(fullfile(files(k).folder, files(k).name)))), '%.*$', ''), newline);
                tc.verifyFalse(contains(code, ["hidden_truth","TargetTruth","burial_depth_m","material_type", ...
                    "target_count","scoreDetections","generateScenario",".label"]), files(k).name);
            end
        end

        function f05_deterministicRerun(tc)
            c = testMG009Detection.trialCfg("F05", 11, 2, 2);
            b = mineguard.evaluation.runTrial(c, struct('truthTransform', @testMG009Detection.metal));
            m = testMG009Detection.model();
            before = rng;
            e1 = mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "single_valid", 1), b.public.poses, b.public.samples, m);
            e2 = mineguard.detection.detectAnomalies(testMG009Detection.dc("or", "single_valid", 1), b.public.poses, b.public.samples, m);
            tc.verifyTrue(isequaln(e1, e2)); tc.verifyEqual(rng, before);
            tc.verifyGreaterThan(height(e1), 0);
        end

        function f06_schemaAndUnitFailures(tc)
            m = testMG009Detection.model(); d = testMG009Detection.dc("or", "abstain", 1);
            P = testMG009Detection.poses([1 2], [1 1], [0 0.1]);
            S = [testMG009Detection.samples("thermal", P, 1:2, [293.65 293.15]); testMG009Detection.samples("em", P, 1:2, [0.05 0.15])];
            id = 'mineguard:InvalidDetectorInput';
            bad = S; bad.temperature_K(1) = 0.15;                       % EM-scale value in kelvin column
            tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, bad, m), id);
            bad = S; bad.response_norm(1) = 0.1;                        % thermal row carrying EM value
            tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, bad, m), id);
            bad = S; bad.pose_sample_id(3) = "P-999999";               % unmatched pose
            tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, bad, m), id);
            bad = S; bad.t_s(1) = 0.5;                                  % time inconsistent with pose
            tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, bad, m), id);
            bad = S; bad.sample_id(2) = bad.sample_id(1);
            tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, bad, m), id);
            bad = removevars(S, 'noise_sigma');
            tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, bad, m), id);
            bad = S; bad.valid(1) = false;                              % invalid but value not NaN
            tc.verifyError(@() mineguard.detection.detectAnomalies(d, P, bad, m), id);
        end

        function f07_clusteringBoundsAlarms(tc)
            x = 0:0.1:1.9; P = testMG009Detection.poses(x, ones(size(x)), x);
            S = testMG009Detection.samples("thermal", P, 1:numel(x), repmat(293.65, 1, numel(x)));
            [e, d] = mineguard.detection.detectAnomalies(testMG009Detection.dc("thermal_only", "abstain", 3), P, S, testMG009Detection.model());
            tc.verifyEqual(d.raw_exceedances, 20);
            tc.verifyEqual(height(e), 2);          % centroid-radius rule: 16 + 4 members
        end

        function f08_emptyTruthAllTN(tc)
            [r, rep] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), testMG009Detection.events(zeros(0,2)), ...
                testMG009Detection.truth(zeros(0,2), strings(0,1)), testMG009Detection.meta(true(2,2)));
            tc.verifyEqual([r.tp r.fp r.tn r.fn], [0 0 4 0]);
            tc.verifyTrue(isnan(r.precision) && isnan(r.recall) && isnan(r.f1));
            tc.verifyEqual(r.false_alarm_rate, 0); tc.verifyEqual(rep.denominators.false_alarm_rate, 4);
            tc.verifyTrue(isnan(r.localization_error_m));
        end

        function f09_noEvaluableCellsOrAllInvalid(tc)
            [r, rep] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), testMG009Detection.events([0.5 0.5]), ...
                testMG009Detection.truth([0.5 0.5], "target"), testMG009Detection.meta(false(2,2)));
            tc.verifyEqual([r.tp r.fp r.tn r.fn], [0 0 0 0]);
            tc.verifyTrue(all(isnan([r.precision r.recall r.f1 r.false_alarm_rate])));
            tc.verifyEqual(rep.excluded_cell_count, 4); tc.verifyEqual(rep.unobserved_target_count, 1);
            tc.verifyEqual(cell2mat(struct2cell(rep.denominators))', zeros(1, 5));
            % All sensor observations invalid -> no evaluable cells from the support mask.
            P = testMG009Detection.poses([0.5 1.5], [0.5 1.5], [0 0.1]);
            S = [testMG009Detection.samples("thermal", P, 1:2, [293 293], [false false]); testMG009Detection.samples("em", P, 1:2, [0 0], [false false])];
            g = struct('bounds_enu_m', [0 2 0 2], 'grid_spacing_m', 1, 'exclusion_polygons_enu_m', {{}});
            for meth = ["thermal_only","em_only","or","and","weighted"]
                tc.verifyFalse(any(mineguard.evaluation.evaluableCellMask(g, P, S, meth, "single_valid"), 'all'));
            end
        end

        function f10_exactConfusionNoDuplicateInflation(tc)
            ev = testMG009Detection.events([0.4 0.4; 0.6 0.6; 1.5 1.5]);    % 2 events in the positive cell, 1 in a negative cell
            [r, rep] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), ev, testMG009Detection.truth([0.5 0.5], "target"), ...
                testMG009Detection.meta(true(2,2)));
            tc.verifyEqual([r.tp r.fp r.tn r.fn], [1 1 2 0]);
            tc.verifyEqual([r.precision r.recall r.f1 r.false_alarm_rate], [0.5 1 2/3 1/3], 'AbsTol', 1e-12);
            tc.verifyEqual(rep.object_event_matches, 1); tc.verifyEqual(rep.unmatched_events, 2);
            % Off-grid and invalid events cannot create a TP.
            ev2 = testMG009Detection.events([5 5; 0.5 0.5]); ev2.valid(2) = false;
            [r2, rep2] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), ev2, testMG009Detection.truth([0.5 0.5], "target"), ...
                testMG009Detection.meta(true(2,2)));
            tc.verifyEqual([r2.tp r2.fn], [0 1]); tc.verifyEqual(rep2.off_grid_events, 1);
        end

        function f11_clutterAlarmIsFalsePositive(tc)
            [r, rep] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), testMG009Detection.events([0.5 0.5]), ...
                testMG009Detection.truth([0.5 0.5], "clutter"), testMG009Detection.meta(true(2,2)));
            tc.verifyEqual([r.tp r.fp r.tn r.fn], [0 1 3 0]);
            tc.verifyEqual(rep.events_in_negative_cells, 1); tc.verifyEqual(rep.object_event_matches, 0);
            tc.verifyTrue(isnan(r.recall)); tc.verifyEqual(r.precision, 0);
        end

        function f12_multipleTargetsPerCell(tc)
            t = testMG009Detection.truth([0.3 0.3; 0.7 0.7; 1.5 1.5], ["target" "target" "target"]);
            ev = testMG009Detection.events([0.5 0.5; 0.32 0.32]);
            [r, rep] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), ev, t, testMG009Detection.meta(true(2,2)));
            tc.verifyEqual([r.tp r.fp r.tn r.fn], [1 0 2 1]);              % one positive cell detected, one missed
            tc.verifyEqual(rep.cells_with_multiple_targets, 1);
            tc.verifyEqual([rep.object_event_matches rep.unmatched_events rep.unmatched_targets], [2 0 1]);
        end

        function f13_maximumCardinalityMatching(tc)
            % Greedy (closest pair first: E1-T1 0.4) gives 1 match; the optimum gives 2 (E1-T2 0.7, E2-T1 0.6).
            t = testMG009Detection.truth([0.4 1; -0.7 1] + [1 0], ["target" "target"]);
            ev = testMG009Detection.events([0 1; 1.0 1] + [1 0]);
            rm = testMG009Detection.meta(true(2,4), [0 4 0 2], 1);
            [~, rep] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), ev, t, rm);
            tc.verifyEqual(rep.object_event_matches, 2);
            tc.verifyEqual(rep.event_localization_error_m, 0.65, 'AbsTol', 1e-12);
            [~, rep2] = mineguard.evaluation.scoreDetections(testMG009Detection.cfg(), ev, t, rm);
            tc.verifyEqual(rep2.match_pairs_event_target_dist, rep.match_pairs_event_target_dist);
        end

        function f14_splitLeakageRejected(tc)
            good = table(["G1";"G2";"G3"], ["S1";"S2";"S3"], [1;2;3], [11;12;13], ["train";"validation";"test"], ...
                'VariableNames', {'group_key','scenario_id','seed','noise_seed','split_id'});
            mineguard.evaluation.validateSplitManifest(good);
            id = 'mineguard:SplitLeakage';
            b = [good; table("G1", "S4", 4, 14, "test", 'VariableNames', good.Properties.VariableNames)];
            tc.verifyError(@() mineguard.evaluation.validateSplitManifest(b), id);         % same layout family in train + test
            b = [good; table("G4", "S4", 1, 14, "test", 'VariableNames', good.Properties.VariableNames)];
            tc.verifyError(@() mineguard.evaluation.validateSplitManifest(b), id);         % shared scenario seed
            b = [good; table("G4", "S4", 4, 11, "validation", 'VariableNames', good.Properties.VariableNames)];
            tc.verifyError(@() mineguard.evaluation.validateSplitManifest(b), id);         % shared noise family
            b = [good; table("G4", "S1", 4, 14, "test", 'VariableNames', good.Properties.VariableNames)];
            tc.verifyError(@() mineguard.evaluation.validateSplitManifest(b), id);         % duplicate scenario id
            tc.verifyError(@() mineguard.evaluation.validateSplitManifest(good(1:2,:)), id);  % no test split
            % Threshold selection refuses non-validation data, and the detector refuses test-fitted models.
            tc.verifyError(@() mineguard.evaluation.selectThresholds({}, {}, testMG009Detection.model(), struct('split_ids', "test")), id);
            m = testMG009Detection.model(); m.provenance.threshold_split = "test";
            P = testMG009Detection.poses(1, 1, 0); S = testMG009Detection.samples("thermal", P, 1, 293.2);
            tc.verifyError(@() mineguard.detection.detectAnomalies(testMG009Detection.dc("thermal_only", "abstain", 3), P, S, m), 'mineguard:InvalidDetectorModel');
        end

        function f15_matchedFiveMethodComparison(tc)
            cs = {testMG009Detection.trialCfg("F15-A", 21, 2, 2), testMG009Detection.trialCfg("F15-B", 22, 1, 2)};
            bs = cellfun(@(c) mineguard.evaluation.runTrial(c, struct('truthTransform', @testMG009Detection.metal)), cs, 'UniformOutput', false);
            m = testMG009Detection.model();
            meths = ["thermal_only","em_only","or","and","weighted"]; thr = [3 3 1 1 3];
            masks = cell(2, 1);
            for k = 1:2
                g = struct('bounds_enu_m', bs{k}.public.geometry.bounds_enu_m, 'grid_spacing_m', 0.5, 'exclusion_polygons_enu_m', {{}});
                mk = true; for meth = meths, mk = mk & mineguard.evaluation.evaluableCellMask(g, bs{k}.public.poses, bs{k}.public.samples, meth, "single_valid"); end
                masks{k} = mk;
            end
            o = struct('split_id', "test", 'association_tolerance_s', 0.05, 'localization_match_radius_m', 0.75, 'common_mask', {masks});
            pop = zeros(1, 5);
            for i = 1:5
                p = mineguard.evaluation.evaluateMethod(bs, cs, m, meths(i), "single_valid", thr(i), o);
                pop(i) = p.tp + p.fp + p.tn + p.fn;
                tc.verifyEqual(p.method, meths(i));
            end
            tc.verifyEqual(pop, repmat(pop(1), 1, 5), 'identical evaluated population across the five methods');
            tc.verifyEqual(pop(1), nnz(masks{1}) + nnz(masks{2}));
        end

        function f16_stressConditions(tc)
            m = testMG009Detection.model();
            c = testMG009Detection.trialCfg("F16-HIGH", 31, 2, 0); c.altitude_m = 5;
            b = mineguard.evaluation.runTrial(c, struct('truthTransform', @testMG009Detection.metal));
            em = b.public.samples(b.public.samples.sensor_kind == "em", :);
            tc.verifyTrue(all(~em.valid) && all(em.invalid_reason == "MODEL_OUT_OF_DOMAIN"));
            e = mineguard.detection.detectAnomalies(setfield(testMG009Detection.dc("em_only", "single_valid", 3), 'scenario_id', c.scenario_id), ...
                b.public.poses, b.public.samples, m);
            tc.verifyEqual(height(e), 0, 'no unsupported high-altitude EM detection');
            g = struct('bounds_enu_m', [0 4 0 4], 'grid_spacing_m', 0.5, 'exclusion_polygons_enu_m', {{}});
            tc.verifyFalse(any(mineguard.evaluation.evaluableCellMask(g, b.public.poses, b.public.samples, "em_only", "single_valid"), 'all'), ...
                'out-of-domain cells are not assessable (not TN)');
            % Negative thermal contrast still yields |z| anomalies (signed contrast is not assumed warm).
            c2 = testMG009Detection.trialCfg("F16-NEG", 32, 2, 0); c2.sensor_settings.thermal.contrast_amplitude_K = -2;
            b2 = mineguard.evaluation.runTrial(c2, struct('truthTransform', @testMG009Detection.shallow));
            th = b2.public.samples(b2.public.samples.sensor_kind == "thermal", :);
            tc.verifyLessThan(min(th.temperature_K), 293.15 - 0.3);   % cooler than background by > 3 sigma
            [~, d] = mineguard.detection.detectAnomalies(setfield(testMG009Detection.dc("thermal_only", "abstain", 3), 'scenario_id', c2.scenario_id), ...
                b2.public.poses, b2.public.samples, m);
            tc.verifyGreaterThan(d.raw_exceedances, 0);
            % EM rate mismatch: half the poses lack EM, so OR single_valid keeps thermal-only candidates while AND abstains.
            c3 = testMG009Detection.trialCfg("F16-RATE", 33, 1, 0);
            b3 = mineguard.evaluation.runTrial(c3, struct('em_pose_stride', 2));
            [~, d3] = mineguard.detection.detectAnomalies(setfield(testMG009Detection.dc("and", "single_valid", 1, 0), 'scenario_id', c3.scenario_id), ...
                b3.public.poses, b3.public.samples, m);
            tc.verifyGreaterThan(d3.thermal_only_candidates, 0);
            tc.verifyEqual(d3.decided_candidates, d3.paired_candidates);
        end

        function f17_geotagNoiseUsesEnu(tc)
            c = testMG009Detection.trialCfg("F17", 41, 2, 1);
            [g, t, env] = mineguard.scenario.generateScenario(c); t = testMG009Detection.metal(t);
            scen = struct('config', c, 'geometry', g, 'hidden_truth', t, 'environment', env);
            nav0 = mineguard.navigation.navigationConfigFromExperiment(c);
            nav1 = mineguard.navigation.navigationConfigFromExperiment(c, 'virtual_origin_lat_deg', 12.97, 'virtual_origin_lon_deg', 77.59, 'gps_sigma_m', 1.5);
            r = mineguard.navigation.makeGridRoute(nav0, g);
            p0 = mineguard.navigation.simulatePose(nav0, g, r); p1 = mineguard.navigation.simulatePose(nav1, g, r);
            tc.verifyTrue(all(isnan(p0.virtual_lat_deg))); tc.verifyTrue(all(isfinite(p1.virtual_lat_deg)));
            S = [mineguard.sensors.simulateThermal(c, scen, p0); mineguard.sensors.simulateEM(c, scen, p0)];
            d = setfield(testMG009Detection.dc("or", "single_valid", 1), 'scenario_id', c.scenario_id);
            e0 = mineguard.detection.detectAnomalies(d, p0, S, testMG009Detection.model());
            e1 = mineguard.detection.detectAnomalies(d, p1, S, testMG009Detection.model());
            tc.verifyGreaterThan(height(e0), 0);
            tc.verifyEqual([e1.x_est_m e1.y_est_m], [e0.x_est_m e0.y_est_m], 'ENU estimates independent of geotag noise');
            tc.verifyTrue(all(isnan(e0.uncertainty_m)), 'no origin -> uncertainty undeclared (NaN)');
            tc.verifyEqual(e1.uncertainty_m, repmat(1.5, height(e1), 1), 'declared geotag sigma carried');
        end

        function f18_resultSchemaProvenanceAndPublicBundle(tc)
            c = testMG009Detection.trialCfg("F18", 51, 2, 1);
            b = mineguard.evaluation.runTrial(c, struct('truthTransform', @testMG009Detection.metal));
            d = setfield(testMG009Detection.dc("or", "single_valid", 1), 'scenario_id', c.scenario_id);
            ev = mineguard.detection.detectAnomalies(d, b.public.poses, b.public.samples, testMG009Detection.model());
            g = struct('bounds_enu_m', [0 4 0 4], 'grid_spacing_m', 0.5, 'exclusion_polygons_enu_m', {{}});
            rm = struct('scenario_id', c.scenario_id, 'grid', g, 'evaluable_cell_mask', ...
                mineguard.evaluation.evaluableCellMask(g, b.public.poses, b.public.samples, "or", "single_valid"), ...
                'algorithm', "or/single_valid", 'split_id', "test", 'localization_match_radius_m', 0.75);
            mineguard.evaluation.checkProvenance(b, c, d, rm);
            r = mineguard.evaluation.scoreDetections(c, ev, b.private.truth, rm);
            frozen = ["schema_version","scenario_id","seed","algorithm","coverage_fraction","mission_time_s","distance_m", ...
                "tp","fp","tn","fn","precision","recall","f1","false_alarm_rate","localization_error_m","matlab_release", ...
                "toolbox_manifest","git_sha","split_id","scenario_seed"];
            tc.verifyEqual(string(fieldnames(r))', frozen);
            tc.verifyEqual([r.git_sha r.matlab_release r.toolbox_manifest], repmat("NOT_RECORDED", 1, 3));
            rm2 = rm; rm2.git_sha = "abc1234"; rm2.matlab_release = string(version('-release')); rm2.toolbox_manifest = "MATLAB";
            r2 = mineguard.evaluation.scoreDetections(c, ev, b.private.truth, rm2);
            tc.verifyEqual(r2.git_sha, "abc1234"); tc.verifyEqual(r2.seed, 51); tc.verifyEqual(r2.split_id, "test");
            % The public bundle carries no truth.
            tc.verifyFalse(any(ismember(fieldnames(b.public), {'truth','hidden_truth','environment'})));
            txt = jsonencode(struct('poses', b.public.poses, 'samples', b.public.samples, 'events', ev, 'geometry', b.public.geometry));
            tc.verifyFalse(contains(txt, ["OBJ-","""label""","synthetic_metal","burial_depth"]));
            % Provenance mismatches are rejected.
            id = 'mineguard:ProvenanceMismatch';
            d2 = d; d2.scenario_id = "OTHER";
            tc.verifyError(@() mineguard.evaluation.checkProvenance(b, c, d2, rm), id);
            c2 = c; c2.noise_seed = c.noise_seed + 1;
            tc.verifyError(@() mineguard.evaluation.checkProvenance(b, c2, d, rm), id);
            c3 = c; c3.sensor_settings.version = "other";
            tc.verifyError(@() mineguard.evaluation.checkProvenance(b, c3, d, rm), id);
            c4 = c; c4.sensor_settings.em.em_noise_sigma_norm = 0.03;     % same IDs, different config
            tc.verifyError(@() mineguard.evaluation.checkProvenance(b, c4, d, rm), id);
            rm3 = rm; rm3.scenario_id = "OTHER";
            tc.verifyError(@() mineguard.evaluation.scoreDetections(c, ev, b.private.truth, rm3), id);
        end
    end
end
