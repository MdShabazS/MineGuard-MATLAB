classdef testMG015Integration < matlab.uitest.TestCase
    %TESTMG015INTEGRATION MG-014 locked integration tests L-01..L-22 (+ demo D-03..D-08) for MG-015.
    %   Needs an interactive MATLAB desktop (dashboard tests render the real uifigure).
    %   Run from repo root: addpath('matlab'); runtests('matlab/tests/testMG015Integration.m')
    %   L-10 and L-21 read held-out outputs written by runMG015Locked("heldout", ...). They stay
    %   INCOMPLETE (assumption failed) until the reviewed run-lock allows TEST to be opened.
    %   SIMULATION ONLY.

    properties (Constant)
        Ev = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'tasks', 'evidence', 'MG-015')
        Root = fileparts(fileparts(fileparts(mfilename('fullpath'))))
    end
    properties
        S0
        S0Bundle
        S0Record
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(tc.Root, 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(tc.Root, 'matlab', 'experiments')));
            tc.S0 = mg015DemoConfig("S0");
            [tc.S0Bundle, tc.S0Record] = mineguard.runExperiment(tc.S0);
        end
    end

    methods (Static)
        function t = truthOf(c, transform)
            % Evaluator-side helper (tests only): regenerate the same seeded truth.
            [~, t] = mineguard.scenario.generateScenario(rmfield(c, intersect(fieldnames(c), {'detector_settings','run_options','sensor_settings'})));
            if nargin > 1, t = transform(t); end
        end
        function t = setMat(t, targetMat, clutterMat)
            isT = string(t.label) == "target";
            t.material_type(isT) = targetMat; t.material_type(~isT) = clutterMat;
        end
        function [cells, nx] = cellOf(c, x, y)
            nx = ceil((c.x_max_m - c.x_min_m) / c.grid_spacing_m - 1e-9); ny = ceil((c.y_max_m - c.y_min_m) / c.grid_spacing_m - 1e-9);
            dx = (c.x_max_m - c.x_min_m) / nx; dy = (c.y_max_m - c.y_min_m) / ny;
            cells = (min(ny, floor((y - c.y_min_m) / dy) + 1) - 1) * nx + min(nx, floor((x - c.x_min_m) / dx) + 1);
        end
    end

    methods (Test)
        function L01_manifestLocked(tc)
            M = jsondecode(fileread(fullfile(tc.Root, 'experiments', 'locked', 'mg014_scenario_manifest.json')));
            G = struct2table(M.groups); sp = string(G.split_id); pr = string(G.profile_id);
            tc.verifyEqual([nnz(sp == "train") nnz(sp == "validation") nnz(sp == "test")], [18 6 6]);
            tc.verifyEqual(numel(unique(G.seed)), 30); tc.verifyEqual(numel(unique(G.noise_seed)), 30); tc.verifyEqual(numel(unique(string(G.scenario_id))), 30);
            u = unique(pr); tc.verifyNumElements(u, 6);
            for k = 1:6, tc.verifyEqual([nnz(pr == u(k) & sp == "train") nnz(pr == u(k) & sp == "validation") nnz(pr == u(k) & sp == "test")], [3 1 1]); end
            mineguard.evaluation.validateSplitManifest(table(string(G.group_id), string(G.scenario_id), G.seed, G.noise_seed, sp, ...
                'VariableNames', {'group_key','scenario_id','seed','noise_seed','split_id'}));
            tc.verifyEqual(string(M.plan_status), "PREDECLARED_NOT_GENERATED");
            L = jsondecode(fileread(fullfile(tc.Ev, 'MG014-RUNLOCK-1.json')));
            raw = fileread(fullfile(tc.Root, 'experiments', 'locked', 'mg014_scenario_manifest.json'));
            tmp = [tempname '.lf']; fid = fopen(tmp, 'w'); fwrite(fid, unicode2native(strrep(raw, char(13), ''), 'UTF-8')); fclose(fid);
            [~, o] = system(sprintf('certutil -hashfile "%s" SHA256', tmp)); delete(tmp);
            l = splitlines(string(o)); tc.verifyEqual(lower(erase(strtrim(l(2)), " ")), string(L.manifest_sha256), 'sealed manifest unchanged (LF-normalised SHA-256)');
        end

        function L02_sceneReproducible(tc)
            c = mg015GroupConfig("GF-003"); before = rng;
            cc = rmfield(c, {'sensor_settings','run_options'});
            [g1, t1, e1] = mineguard.scenario.generateScenario(cc); [g2, t2, e2] = mineguard.scenario.generateScenario(cc);
            tc.verifyEqual(g1, g2); tc.verifyEqual(t1, t2); tc.verifyTrue(isequaln(e1, e2)); tc.verifyEqual(rng, before);
            tc.verifyEqual(height(t1), 3); tc.verifyEqual(e1.rng.thermal_seed, mod(550303 + 1000003, 2^32));
        end

        function L03_fixedGridBaseline(tc)
            c = mg015GroupConfig("GF-001", mg015DetectorSettings("RUNLOCK"));
            rb = mineguard.runExperiment(c);
            tc.verifySize(rb.route_enu_m, [100 3]);
            tc.verifyTrue(all(diff(rb.poses.t_s) > 0));
            tc.verifyEqual([rb.coverage.coverage_fraction rb.coverage.visited_valid_cells rb.coverage.total_valid_cells], [1 100 100]);
            tc.verifyEqual([rb.coverage.distance_m rb.coverage.mission_time_s], [198 99], 'AbsTol', 1e-9);
            tc.verifyTrue(all(rb.poses.z_up_m == 2));
        end

        function L04_exclusionConflictExplicit(tc)
            c = mg015GroupConfig("GF-002", mg015DetectorSettings("RUNLOCK"));
            c.scenario_id = "MG015-L04-FIXTURE"; c.run_options.split_id = "stress";
            c.exclusion_polygons_enu_m = {[9.9 3; 10.1 3; 10.1 17; 9.9 17]};      % narrow interior barrier (fixture, not a sealed group)
            tc.verifyError(@() mineguard.runExperiment(c), 'mineguard:RouteConflict');
            c.exclusion_polygons_enu_m = {[0 0; 4 0; 4 20; 0 20]};               % edge strip: feasible, legal-cell denominator shrinks
            rb = mineguard.runExperiment(c);
            tc.verifyEqual(rb.coverage.total_valid_cells, 80); tc.verifyFalse(any(rb.poses.x_east_m < 4));
        end

        function L05_sensorTablesUnits(tc)
            rb = tc.S0Bundle;
            cols = ["sample_id","pose_sample_id","t_s","sensor_kind","temperature_K","response_norm","noise_sigma","standoff_m","footprint_radius_m","valid","invalid_reason"];
            tc.verifyEqual(string(rb.thermal_samples.Properties.VariableNames), cols); tc.verifyEqual(string(rb.em_samples.Properties.VariableNames), cols);
            tc.verifyTrue(all(rb.thermal_samples.temperature_K > 250 & rb.thermal_samples.temperature_K < 350));
            tc.verifyTrue(all(isnan(rb.thermal_samples.response_norm)) && all(isnan(rb.em_samples.temperature_K)));
            tc.verifyTrue(all(ismember(rb.thermal_samples.pose_sample_id, rb.poses.pose_sample_id)));
            tc.verifyTrue(all(isfinite(rb.em_samples.response_norm(rb.em_samples.valid))));
        end

        function L06_highStandoffAndNonmetallic(tc)
            c = mg015GroupConfig("GF-006", mg015DetectorSettings("RUNLOCK", "em_only", "single_valid"));
            tc.verifyEqual(c.altitude_m, 5);
            [rb, rec] = mineguard.runExperiment(c);
            tc.verifyTrue(all(~rb.em_samples.valid) && all(rb.em_samples.invalid_reason == "MODEL_OUT_OF_DOMAIN") && all(isnan(rb.em_samples.response_norm)));
            tc.verifyEqual(rec.evaluable_cells, 0, 'not assessable is not a detection or a TN');
            tc.verifyEqual([rb.result.tp rb.result.fp rb.result.tn rb.result.fn], [0 0 0 0]); tc.verifyEqual(height(rb.events), 0);
            % Deterministic nonmetallic control: plastic and rock (EM gain 0) give identical EM; metal differs.
            s = tc.S0; s.run_options.evaluate = false;
            s.run_options.truth_transform = @(t) testMG015Integration.setMat(t, "synthetic_plastic_surrogate", "synthetic_rock"); rp = mineguard.runExperiment(s);
            s.run_options.truth_transform = @(t) testMG015Integration.setMat(t, "synthetic_rock", "synthetic_rock");            rr = mineguard.runExperiment(s);
            s.run_options.truth_transform = @(t) testMG015Integration.setMat(t, "synthetic_metal_cased_surrogate", "synthetic_rock"); rm = mineguard.runExperiment(s);
            tc.verifyEqual(rp.em_samples.response_norm, rr.em_samples.response_norm, 'no metal contribution from a nonmetallic surrogate');
            tc.verifyGreaterThan(max(rm.em_samples.response_norm - rp.em_samples.response_norm), 0.1);
        end

        function L07_clutterFalseAlarmNeverTP(tc)
            s = tc.S0; tf = @(t) testMG015Integration.setMat(t, "synthetic_plastic_surrogate", "synthetic_rock");
            s.run_options.truth_transform = tf;
            [rb, rec] = mineguard.runExperiment(s);
            truth = testMG015Integration.truthOf(s, tf);
            tc.assertTrue(all(truth.material_type(string(truth.label) == "clutter") == "synthetic_rock"), 'fixture material asserted before use');
            tgtCells = testMG015Integration.cellOf(s, truth.x_east_m(string(truth.label) == "target"), truth.y_north_m(string(truth.label) == "target"));
            rockCells = setdiff(testMG015Integration.cellOf(s, truth.x_east_m(string(truth.label) == "clutter"), truth.y_north_m(string(truth.label) == "clutter")), tgtCells);
            evCells = unique(testMG015Integration.cellOf(s, rb.events.x_est_m, rb.events.y_est_m));
            tc.verifyGreaterThan(numel(intersect(evCells, rockCells)), 0, 'hot rock produced a SUSPECTED event (false alarm)');
            tc.verifyLessThanOrEqual(rb.result.tp, numel(unique(tgtCells)), 'clutter alarms never counted as TP');
            tc.verifyEqual(rb.result.fp, numel(setdiff(evCells, tgtCells)));
            tc.verifyGreaterThan(rec.report.events_in_negative_cells, 0);
        end

        function L08_missingModalityRules(tc)
            s = tc.S0; s.sensor_settings = rmfield(s.sensor_settings, 'thermal');
            s.detector_settings = mg015DetectorSettings("MG009", "or", "single_valid"); rbS = mineguard.runExperiment(s);
            tc.verifyTrue(all(isnan(rbS.thermal_samples.temperature_K)) && all(rbS.thermal_samples.invalid_reason == "UNCONFIGURED_SENSOR"));
            tc.verifyGreaterThan(height(rbS.events), 0); tc.verifyTrue(all(rbS.events.thermal_sample_id == ""), 'EM-only fallback events');
            s.detector_settings = mg015DetectorSettings("MG009", "or", "abstain");       rbA = mineguard.runExperiment(s);
            s.detector_settings = mg015DetectorSettings("MG009", "or", "require_both");  rbR = mineguard.runExperiment(s);
            s.detector_settings = mg015DetectorSettings("MG009", "and", "single_valid"); rbN = mineguard.runExperiment(s);
            tc.verifyEqual([height(rbA.events) height(rbR.events) height(rbN.events)], [0 0 0]);
            s2 = tc.S0; s2.sensor_settings = rmfield(s2.sensor_settings, {'thermal','em'});
            s2.detector_settings = mg015DetectorSettings("MG009", "or", "single_valid"); rb0 = mineguard.runExperiment(s2);
            tc.verifyEqual(height(rb0.events), 0, 'both missing -> no valid event');
        end

        function L09_alignmentAndIdValidation(tc)
            rb = tc.S0Bundle; d = tc.S0.detector_settings;
            dc = struct('schema_version', "mg-contract/1.0", 'scenario_id', rb.scenario_id, 'association_tolerance_s', d.association_tolerance_s, ...
                'threshold', d.threshold, 'method_name', d.method_name, 'missing_modality_rule', d.missing_modality_rule);
            S = [rb.thermal_samples; rb.em_samples]; id = 'mineguard:InvalidDetectorInput';
            b = S; b.t_s(5) = b.t_s(5) + 0.5;             tc.verifyError(@() mineguard.detection.detectAnomalies(dc, rb.poses, b, d.model), id);
            b = S; b.pose_sample_id(7) = "P-999999";      tc.verifyError(@() mineguard.detection.detectAnomalies(dc, rb.poses, b, d.model), id);
            b = S; b.sample_id(9) = b.sample_id(8);       tc.verifyError(@() mineguard.detection.detectAnomalies(dc, rb.poses, b, d.model), id);
            p = rb.poses; p.pose_sample_id(3) = p.pose_sample_id(2); tc.verifyError(@() mineguard.detection.detectAnomalies(dc, p, S, d.model), id);
            dc0 = dc; dc0.association_tolerance_s = 0;
            [~, g0] = mineguard.detection.detectAnomalies(dc0, rb.poses, S, d.model);
            tc.verifyEqual(g0.paired_candidates, height(rb.thermal_samples), 'same-pose samples pair at zero tolerance');
        end

        function L10_fiveMethodsHeldOut(tc)
            f = fullfile(tc.Ev, 'MG-015-test-comparison.csv');
            tc.assumeTrue(isfile(f), 'BLOCKED: sealed TEST not opened (run-lock awaiting review)');
            T = readtable(f, 'TextType', 'string'); L = jsondecode(fileread(fullfile(tc.Ev, 'MG014-RUNLOCK-1.json')));
            tc.verifyEqual(height(T), 15);
            for r = ["single_valid","abstain","require_both"]
                k = T.rule == r; tc.verifyEqual(numel(unique(T.tp(k) + T.fp(k) + T.tn(k) + T.fn(k))), 1, 'matched population across five methods');
            end
            for m = ["thermal_only","em_only","or","and","weighted"], tc.verifyEqual(unique(T.threshold(T.method == m)), L.method_thresholds.(m)); end
        end

        function L11_noEventInflation(tc)
            s = tc.S0; s.run_options.truth_transform = @(t) testMG015Integration.setMat(t, "synthetic_metal_cased_surrogate", "synthetic_root");
            [rb1, r1] = mineguard.runExperiment(s); rb2 = mineguard.runExperiment(s);
            tc.verifyGreaterThan(r1.diagnostics.raw_exceedances, height(rb1.events), 'clustering bounds alarms');
            tc.verifyEqual(rb1.events, rb2.events, 'stable deterministic event IDs');
            tc.verifyTrue(all(rb1.events.status == "SUSPECTED"));
            tc.verifyTrue(all(rb1.events.x_est_m >= min(rb1.poses.x_east_m) & rb1.events.x_est_m <= max(rb1.poses.x_east_m)), 'coordinates from poses');
        end

        function L12_emptyField(tc)
            [rb, rec] = mineguard.runExperiment(mg015GroupConfig("GF-001", mg015DetectorSettings("RUNLOCK")));
            r = rb.result;
            tc.verifyEqual([r.tp r.fn rec.report.positive_cells_evaluable], [0 0 0]); tc.verifyTrue(isnan(r.recall) && isnan(r.f1) || r.fp > 0);
            tc.verifyTrue(isnan(r.recall));
            if r.fp == 0, tc.verifyTrue(isnan(r.precision)); tc.verifyEqual(r.false_alarm_rate, 0);
            else, tc.verifyEqual(r.precision, 0); tc.verifyEqual(r.false_alarm_rate, r.fp / (r.fp + r.tn), 'AbsTol', 1e-12); end
            tc.verifyEqual(r.tn + r.fp, 100);
            app = mineguard.app.openMissionApp(rb); tc.addTeardown(@() app.close());
            tc.verifyEmpty(regexp(lower(strjoin(string(app.uiHandles().eval.Value), " ")), '\<(safe|cleared|all clear)\>', 'once'), 'no "clear area" claim');
        end

        function L13_zeroEvaluableCells(tc)
            s = tc.S0; s.sensor_settings = rmfield(s.sensor_settings, {'thermal','em'});
            [rb, rec] = mineguard.runExperiment(s); r = rb.result;
            tc.verifyEqual([r.tp r.fp r.tn r.fn], [0 0 0 0]); tc.verifyEqual(rec.evaluable_cells, 0);
            tc.verifyTrue(all(isnan([r.precision r.recall r.f1 r.false_alarm_rate])));
            tc.verifyEqual(rec.report.excluded_cell_count, 400);
            tc.verifyEqual(rec.report.unobserved_target_count, rec.report.target_objects);
        end

        function L14_independentConfusionCheck(tc)
            s = tc.S0; rb = tc.S0Bundle;
            truth = testMG015Integration.truthOf(s);
            tCells = unique(testMG015Integration.cellOf(s, truth.x_east_m(string(truth.label) == "target"), truth.y_north_m(string(truth.label) == "target")));
            eCells = unique(testMG015Integration.cellOf(s, rb.events.x_est_m, rb.events.y_est_m));
            N = 400;   % all cells evaluable here (both channels valid at every pose)
            tp = numel(intersect(tCells, eCells)); fp = numel(setdiff(eCells, tCells)); fn = numel(setdiff(tCells, eCells)); tn = N - tp - fp - fn;
            tc.verifyEqual([rb.result.tp rb.result.fp rb.result.tn rb.result.fn], [tp fp tn fn]);
            tc.verifyEqual(tc.S0Record.evaluable_cells, N);
            tc.verifyLessThanOrEqual(rb.result.tp, height(rb.events), 'multiple alarms in one cell never inflate TP');
        end

        function L15_multiTargetCellsAndMatching(tc)
            [~, rec] = mineguard.runExperiment(mg015GroupConfig("GF-005", mg015DetectorSettings("RUNLOCK")));
            rp = rec.report;
            tc.verifyEqual(rp.target_objects, 2);
            tc.verifyLessThanOrEqual(rp.object_event_matches, min(rec.events, rp.target_objects));
            tc.verifyEqual(rp.unmatched_targets, rp.target_objects - rp.object_event_matches);
            tc.verifyEqual(rp.unmatched_events, rp.valid_events - rp.off_grid_events - rp.object_event_matches);
            r = runtests(fullfile(tc.Root, 'matlab', 'tests', 'testMG009Detection.m'), 'ProcedureName', {'f12_multipleTargetsPerCell','f13_maximumCardinalityMatching'});
            tc.verifyTrue(all([r.Passed]), 'F-12/F-13 regression');
        end

        function L16_truthFirewall(tc)
            rb = tc.S0Bundle; mineguard.app.validateRunBundle(rb);
            txt = jsonencode(struct('p', rb.poses, 't', rb.thermal_samples, 'e', rb.em_samples, 'v', rb.events, 'g', rb.geometry, 'pr', rb.provenance, 'r', rb.result));
            tc.verifyFalse(contains(txt, ["OBJ-","""label""","synthetic_cased","synthetic_rock","burial_depth","target_count"]));
            rtxt = jsonencode(rmfield(tc.S0Record, 'diagnostics'));
            tc.verifyFalse(contains(rtxt, ["OBJ-","burial_depth","match_pairs","""label"""]), 'record carries aggregates only');
            b = rb; b.hidden_truth = table(1); tc.verifyError(@() mineguard.app.openMissionApp(b), 'mineguard:InvalidRunBundle');
            src = fileread(fullfile(tc.Root, 'matlab', '+mineguard', 'runExperiment.m'));
            tc.verifySubstring(src, 'detectAnomalies(dc, trial.public.poses, trial.public.samples, ds.model)');
            tc.verifyEqual(numel(strfind(src, 'trial.private.truth')), 1, 'truth used exactly once (evaluator)');
        end

        function L17_virtualGeotagUnavailable(tc)
            rb = tc.S0Bundle; tc.verifyTrue(all(isnan(rb.poses.virtual_lat_deg)));
            app = mineguard.app.openMissionApp(rb); tc.addTeardown(@() app.close());
            tc.verifyTrue(any(contains(app.viewState().telemetry, "Virtual GPS unavailable")));
        end

        function L18_realReplay(tc)
            rb = tc.S0Bundle; app = mineguard.app.openMissionApp(rb); tc.addTeardown(@() app.close()); h = app.uiHandles();
            tc.press(h.play); pause(0.8); tc.press(h.pause); tc.verifyEqual(app.State, "PAUSED");
            app.seek(rb.poses.t_s(end)); v = app.viewState();
            tc.verifyEqual(v.trace_points, height(rb.poses)); tc.verifyEqual(numel(v.visible_event_ids), height(rb.events));
            tc.verifyEqual(sort(h.ev.XData(:)), sort(rb.events.x_est_m));
            tc.press(h.reset); tc.verifyEqual(app.State, "READY");
            tc.verifySubstring(v.banner, "SIMULATION");
        end

        function L19_exportRoundTripAndCancel(tc)
            rb = tc.S0Bundle; app = mineguard.app.openMissionApp(rb); tc.addTeardown(@() app.close());
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            tc.verifyTrue(app.exportRun(d)); X = app.LastExport;
            m = load(fullfile(X.folder, 'run_bundle_redacted.mat')); tc.verifyTrue(isequaln(m.runBundle, rb));
            T = readtable(fullfile(X.folder, 'events.csv'), 'TextType', 'string'); tc.verifyEqual(height(T), height(rb.events));
            js = jsondecode(fileread(fullfile(X.folder, 'summary.json'))); tc.verifyEqual(string(js.provenance.run_id), rb.provenance.run_id);
            tc.verifyGreaterThan(size(imread(fullfile(X.folder, 'snapshot.png')), 1), 300);
            tc.verifyFalse(app.exportRun(0)); tc.verifySubstring(app.StatusText, "cancelled");
        end

        function L20_endToEndReproducible(tc)
            [a, ra] = mineguard.runExperiment(tc.S0); [b, rb2] = mineguard.runExperiment(tc.S0);
            a.provenance = rmfield(a.provenance, 'run_timestamp_utc'); b.provenance = rmfield(b.provenance, 'run_timestamp_utc');
            tc.verifyTrue(isequaln(a, b), 'identical run bundle (wall-clock timestamp excluded, MG-003 §6)');
            tc.verifyTrue(isequaln(ra, rb2));
            tc.verifyEqual(a.result.tp + a.result.fp + a.result.tn + a.result.fn, ra.evaluable_cells);
        end

        function L21_stressReport(tc)
            f = fullfile(tc.Ev, 'MG-015-stress.csv');
            tc.assumeTrue(isfile(f), 'BLOCKED: sealed TEST not opened (run-lock awaiting review)');
            T = readtable(f, 'TextType', 'string');
            tc.verifyEqual(sort(unique(T.condition))', sort(["noise_x3","dropout_0p3","negative_contrast","soil_shift","em_rate_half"]));
            tc.verifyGreaterThan(unique(T.invalid_sample_fraction(T.condition == "dropout_0p3")), 0.2);
            tc.verifyEqual(height(T), 25);
        end

        function L22_provenance(tc)
            p = tc.S0Bundle.provenance;
            for f = ["scenario_id","seed","noise_seed","model_version","sensor_settings_version","detector_model_version","method_name", ...
                    "missing_modality_rule","threshold","matlab_release","git_sha","run_id","run_timestamp_utc","toolbox_manifest","split_id","simulation_flags"]
                tc.verifyFalse(isequal(string(p.(f)), "NOT_RECORDED"), f);
            end
            L = jsondecode(fileread(fullfile(tc.Ev, 'MG014-RUNLOCK-1.json')));
            tc.verifyTrue(all(structfun(@(v) isfinite(v), L.method_thresholds)));
            tc.verifyEqual(numel(L.config_digests), 30); tc.verifyNotEmpty(L.software_git_sha);
            tc.verifyEqual(string(computer), "PCWIN64"); tc.verifyEqual(string(version('-release')), "2026b");
        end

        function D03_D08_oneCommandDemo(tc)
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            [app, rb] = mineguardDemo("S0", 'ExportTo', d); tc.addTeardown(@() app.close());
            tc.verifyEqual(app.State, "READY"); tc.verifyTrue(isfield(app.LastExport, 'folder') && isfolder(app.LastExport.folder), 'demo export verified');
            tc.verifyEqual(rb.provenance.seed, 3001);
            tc.verifyTrue(all(rb.events.status == "SUSPECTED"));
            tc.verifyError(@() mineguardDemo("GF-027"), 'mineguard:SealedTest');
            [app2, rb2] = mineguardDemo("GF-020"); tc.addTeardown(@() app2.close());
            tc.verifyEqual(rb2.provenance.split_id, "validation");
        end
    end
end
