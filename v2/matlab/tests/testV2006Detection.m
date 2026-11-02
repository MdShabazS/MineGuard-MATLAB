classdef testV2006Detection < matlab.unittest.TestCase
    %TESTV2006DETECTION V2-006 suspected-anomaly detection, mission map, evidence and evaluation. SIMULATED.
    %   From the repository root:  addpath('v2/matlab'); runtests('v2/matlab/tests/testV2006Detection.m')
    %   Headless except d17 (invisible figure). TestClassSetup runs: the DEMO FIXTURE mission (full), two
    %   counterfactual partial runs (truth-only difference), a clutter-only negative control and a thermal
    %   dropout run (partial). TEST groups are never run.

    properties
        Demo; DemoTruth; CfA; CfB; CfTruthA; CfTruthB; Neg; NegTruth; Drop
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
            G = mgv2.eval.scenarioGroups();
            g = mgv2.eval.demoFixtureGroup();
            tc.Demo = mgv2.eval.runScenario(g, KeepFrames=4000); [~, ~, tc.DemoTruth] = mgv2.eval.buildScenario(g);
            a = G(1); b = a; b.n_blind_targets = 3;                  % differ ONLY in no-signature hidden targets
            tc.CfA = mgv2.eval.runScenario(a, MaxTicks=500); tc.CfB = mgv2.eval.runScenario(b, MaxTicks=500);
            [~, ~, tc.CfTruthA] = mgv2.eval.buildScenario(a); [~, ~, tc.CfTruthB] = mgv2.eval.buildScenario(b);
            n = G([G.group_id] == "G03");                               % N1_CLUTTER: zero hidden targets
            tc.Neg = mgv2.eval.runScenario(n, MaxTicks=700); [~, ~, tc.NegTruth] = mgv2.eval.buildScenario(n);
            tc.Drop = mgv2.eval.runScenario(G([G.group_id] == "G06"), MaxTicks=800, KeepFrames=400);   % thermal dropout 22-34 s
        end
    end

    methods (Static)
        function s = sampleByFrame(sys, frameId)
            row = sys.Log(sys.Log.frame_id == frameId, :); s = [];
            S = sys.samplesAt(row.tick_id);
            for k = 1:numel(S), if S{k}.frame_id == frameId, s = S{k}; end, end
        end
        function s = firstValid(sys, id)
            % a valid frame from the middle of the retained run (aircraft at survey altitude)
            L = sys.Log; r = find(L.sensor_id == id & L.valid); r = r(ceil(numel(r) / 2));
            s = testV2006Detection.sampleByFrame(sys, L.frame_id(r));
        end
        function [d, sys, eng] = freshPipeline(nTicks)
            g = mgv2.eval.demoFixtureGroup(); [pub, fwd] = mgv2.eval.buildScenario(g);
            eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world));
            sys = mgv2.sensors.SensorSystem(pub.world, pub.mission, SensorConfig=pub.sensor_config, Environment=pub.environment, ...
                SurfaceFeatures=fwd, KeepFrames=200);
            d = mgv2.detect.AnomalyDetector(pub.world, pub.mission); sys.attach(eng);
            if nargin > 0, eng.run(nTicks); end
        end
        function r = contrast(a, b)
            l = @(c) sum([0.2126 0.7152 0.0722] .* ((c <= 0.03928) .* c / 12.92 + (c > 0.03928) .* ((c + 0.055) / 1.055) .^ 2.4));
            v = sort([l(a) l(b)], 'descend'); r = (v(1) + 0.05) / (v(2) + 0.05);
        end
        function r = worstTextContrast(f)
            % WCAG contrast of every text colour against the surface it is drawn on (axes, colorbars, legends, annotations)
            C = @testV2006Detection.contrast; w = [1 1 1]; r = inf;
            for h = findall(f, 'Type', 'textboxshape')', r = min(r, C(h.Color, w)); end
            for h = findall(f, 'Type', 'colorbar')', r = min([r C(h.Color, w) C(h.Label.Color, w)]); end
            for h = findall(f, 'Type', 'legend')', r = min(r, C(h.TextColor, h.Color)); end
            for ax = findall(f, 'Type', 'axes')'
                r = min([r C(ax.XColor, w) C(ax.YColor, w) C(ax.Title.Color, w) C(ax.XLabel.Color, w) C(ax.YLabel.Color, w)]);
                for h = findall(ax, 'Type', 'text')', if ~isempty(h.String), r = min(r, C(h.Color, w)); end, end
            end
        end
        function E = eventsAsTable(E)
            E = table([E.event_id]', [E.x_est_m]', [E.y_est_m]', [E.model_score]', [E.n_observations]', ...
                'VariableNames', ["id","x","y","score","n"]);
        end
    end

    methods (Test)
        function d01_detectorContractAndConfig(tc)                           % versioned contract, fingerprint
            c = mgv2.detect.contract(); cfg = mgv2.detect.defaultDetectorConfig();
            tc.verifyEqual(c.schema_version, "mg-v2-detector/1.0"); tc.verifyEqual(c.statuses, "SUSPECTED");
            tc.verifyEqual(cfg.parameter_hash, mgv2.sensors.configFingerprint(cfg));
            x = cfg; x.thermal.dT_threshold_K = 1.1; x = mgv2.detect.validateDetectorConfig(x);
            tc.verifyNotEqual(x.parameter_hash, cfg.parameter_hash);
            x = cfg; x.parameter_hash = "fnv1a64:forged"; tc.verifyEqual(mgv2.detect.validateDetectorConfig(x).parameter_hash, cfg.parameter_hash);
            bad = {@(q) setfield(q, 'score_mode', "ORACLE"), @(q) setfield(q, 'extra', 1), ...
                @(q) setfield(q, 'rgb', setfield(q.rgb, 'window_px', 30)), @(q) setfield(q, 'TargetTruth', 1)}; %#ok<SFLD>
            for k = 1:numel(bad), tc.verifyError(@() mgv2.detect.validateDetectorConfig(bad{k}(cfg)), 'mgv2:InvalidDetectorConfig'); end
            E = tc.Demo.events; tc.assertNotEmpty(E);
            for k = 1:numel(E)
                mgv2.detect.validateEvent(E(k));
                tc.verifyEqual(string(fieldnames(E(k)))', c.event_fields);
                tc.verifyEqual(E(k).detector_fingerprint, tc.Demo.detector.Fingerprint);
            end
        end

        function d02_truthFirewallStructural(tc)                             % SC-17, EVAL-02, AC-017
            s = tc.firstValid(tc.Demo.sensors, "RGB_NADIR"); d = tc.freshPipeline();
            x = s; x.quality.TargetTruth = struct('x', 1); tc.verifyError(@() d.ingest(x), 'mgv2:TruthLeak');
            x = s; x.quality.nested = struct('burial_depth_m', 0.1); tc.verifyError(@() d.ingest(x), 'mgv2:TruthLeak');
            tc.verifyEqual(height(d.Log), 0);                                  % rejected before any processing
            [pub, fwd, TT] = mgv2.eval.buildScenario(mgv2.eval.demoFixtureGroup());
            mgv2.sensors.assertPublic(pub, "pub"); mgv2.sensors.assertPublic(fwd, "fwd");
            tc.verifyError(@() mgv2.sensors.assertPublic(struct('TargetTruth', TT)), 'mgv2:TruthLeak');
            tc.verifyError(@() mgv2.sensors.assertPublic(struct('t', TT)), 'mgv2:TruthLeak');
            w = pub.world; w.hidden_truth = 1;
            tc.verifyError(@() mgv2.detect.AnomalyDetector(w, pub.mission), 'mgv2:TruthLeak');
            tc.verifyError(@() mgv2.map.MissionMap(pub.world, setfield(pub.mission, 'target_count', 2)), 'mgv2:TruthLeak'); %#ok<SFLD>
            f = fwd; [f.label] = deal("x"); tc.verifyError(@() mgv2.sensors.validateSurfaceFeatures(f), 'mgv2:TruthLeak');
            mgv2.sensors.assertPublic(tc.Demo.events, "events"); mgv2.sensors.assertPublic(tc.Demo.track_table, "tracks");
            tc.Demo.map.snapshot();                                            % asserts public internally
            % code-level: public pipeline packages never reference the evaluator or truth objects
            root = fullfile(fileparts(fileparts(mfilename('fullpath'))), '+mgv2');
            for p = ["+detect","+map"]
                F = dir(fullfile(root, p, '*.m'));
                for k = 1:numel(F)
                    code = fileread(fullfile(F(k).folder, F(k).name));
                    code = regexprep(code, '%[^\n]*', '');                    % comments may mention policy
                    tc.verifyEmpty(regexp(code, 'mgv2\.eval|TargetTruth|buildScenario|SurfaceFeatures', 'once'), F(k).name);
                end
            end
        end

        function d03_counterfactualTruth(tc)                                 % SC-18, EVAL-05, G9
            A = tc.CfA; B = tc.CfB;
            tc.verifyNotEqual(height(tc.CfTruthA.targets), height(tc.CfTruthB.targets));
            tc.verifyEqual(A.sensors.Log.checksum, B.sensors.Log.checksum);   % identical observable samples
            tc.verifyEqual(A.detector.Log(:, ["frame_id","outcome","n_candidates"]), B.detector.Log(:, ["frame_id","outcome","n_candidates"]));
            tc.verifyEqual(A.track_table, B.track_table);
            ea = A.events; eb = B.events; tc.verifyEqual(numel(ea), numel(eb));
            if ~isempty(ea), tc.verifyEqual(ea, eb); end
            ra = mgv2.eval.evaluateEvents(ea, tc.CfTruthA); rb = mgv2.eval.evaluateEvents(eb, tc.CfTruthB);
            tc.verifyEqual(rb.n_targets - ra.n_targets, 2);                    % the evaluator does see the difference
            tc.verifyGreaterThanOrEqual(rb.FN_no_signature, ra.FN_no_signature);
        end

        function d04_clutterOnlyNegativeControl(tc)                          % EVAL-06, G4, N1
            R = mgv2.eval.evaluateEvents(tc.Neg.events, tc.NegTruth);
            tc.verifyEqual(R.n_targets, 0); tc.verifyEqual(R.TP, 0);
            tc.verifyEqual(R.FP, numel(tc.Neg.events));                        % every event reported is a false alarm
            tc.verifyTrue(isnan(R.recall)); tc.verifyTrue(isnan(R.TN));        % undefined, not 0 / 100 %
            if R.n_events == 0, tc.verifyTrue(isnan(R.precision)); else, tc.verifyEqual(R.precision, 0); end
            tc.verifyEqual(tc.NegTruth.family, "N1_CLUTTER");
            fprintf('    N1 clutter-only control (700 ticks): %d events, all FP\n', R.n_events);
        end

        function d05_demoFixturePositive(tc)                                 % AC-015, DEMO FIXTURE
            R = mgv2.eval.evaluateEvents(tc.Demo.events, tc.DemoTruth);
            tc.verifyTrue(tc.DemoTruth.demo_fixture); tc.verifyEqual(tc.DemoTruth.split, "DEMO_FIXTURE");
            tc.verifyEqual(R.TP, 1);
            e = tc.Demo.events(R.matched_event_index);
            tc.verifyEqual(e.status, "SUSPECTED"); tc.verifyEqual(e.detection_basis, "FUSED_RGB_THERMAL");
            tc.verifyLessThanOrEqual(R.match_error_m, 0.5);
            fprintf('    DEMO FIXTURE event %s at (%.3f, %.3f), error %.3f m, score %.3f (uncalibrated)\n', e.event_id, e.x_est_m, e.y_est_m, R.match_error_m, e.model_score);
        end

        function d06_geometricError(tc)                                      % AC-007 (<= 0.5 m), georegistration
            Q = tc.Demo.detector.landmarkResiduals();
            tc.verifyTrue(all(isfinite(Q.error_m))); tc.verifyLessThanOrEqual(Q.error_m, 0.5);
            fprintf('    landmark errors: %s m\n', mat2str(Q.error_m', 3));
            s = tc.firstValid(tc.Demo.sensors, "RGB_NADIR"); w = tc.Demo.world;
            cam = struct('fx', s.focal_lengths_px(1), 'fy', s.focal_lengths_px(2), 'cx', s.principal_point_px(1), 'cy', s.principal_point_px(2));
            [O, D] = mgv2.scene.pixelRays(cam, s.T_world_sensor, [1 1; 160.5 120.5; 320 240; 40 200]);
            [P1, h1] = mgv2.scene.intersectTerrain(w, O, D); [P2, h2] = mgv2.detect.georegisterRays(w, O, D);
            tc.verifyEqual(h2, h1); tc.verifyEqual(P2, P1, 'AbsTol', 1e-6);
            [~, h3] = mgv2.detect.georegisterRays(w, O(1:2, :), [0 0 1; 1 0 0]); tc.verifyFalse(any(h3));   % sky / horizon: no point
            uv = mgv2.scene.projectToImage(struct('fx', cam.fx, 'fy', cam.fy, 'cx', cam.cx, 'cy', cam.cy, 'width_px', 320, 'height_px', 240), s.T_world_sensor, P2(2, :));
            tc.verifyEqual(uv, [160.5 120.5], 'AbsTol', 1e-6);               % actual intrinsics/extrinsics round trip
        end

        function d07_eventAudit(tc)                                          % SC-21
            L = tc.Demo.sensors.Log; cfg = mgv2.detect.defaultDetectorConfig();
            for e = tc.Demo.events'
                tc.verifyTrue(all(ismember(e.evidence_frame_ids, L.frame_id)));
                tc.verifyNotEmpty(e.evidence_refs);
                for r = e.evidence_refs'
                    row = L(L.frame_id == r.frame_id, :);
                    tc.verifyEqual(row.checksum, r.sample_checksum); tc.verifyEqual(row.tick_id, r.tick_id);
                    tc.verifyEqual(r.t_s, double(r.tick_id) * 0.05, 'AbsTol', 1e-9);
                end
                tc.verifyEqual(e.score_kind, "UNCALIBRATED_HEURISTIC_SCORE (not a probability)");
                tc.verifyTrue(isfield(e.modality_validity, 'RGB_NADIR') && isfield(e.modality_validity, 'THERMAL_LWIR'));
                tc.verifyEqual(e.detector_fingerprint, cfg.parameter_hash);
                tc.verifyGreaterThanOrEqual(e.n_observations, cfg.event.min_detections);
            end
        end

        function d08_dropoutAndMissingModalities(tc)                         % EVAL-07, G7, N3
            D = tc.Drop; L = D.detector.Log; S = D.sensors.Log;
            dropT = S(S.sensor_id == "THERMAL_LWIR" & S.invalid_reason == "SENSOR_DROPOUT", :);
            tc.assertNotEmpty(dropT);
            tc.verifyTrue(all(dropT.t_s >= 22 & dropT.t_s <= 34));
            lt = L(ismember(L.frame_id, dropT.frame_id), :);
            tc.verifyTrue(all(lt.outcome == "INVALID_SAMPLE")); tc.verifyTrue(all(lt.n_candidates == 0));
            ob = D.detector.trackTable();                                      % no thermal observation was created during dropout
            for e = D.detector.events()'
                th = e.evidence_refs([e.evidence_refs.sensor_id] == "THERMAL_LWIR");
                tc.verifyFalse(any([th.t_s] >= 22 & [th.t_s] <= 34));
            end
            tc.verifyTrue(all(ob.looks_thermal >= ob.det_frames_thermal));
            m = D.map.snapshot(); tc.verifyGreaterThan(nnz(m.invalid_count), 0);
            fp = m.footprints([m.footprints.sensor_id] == "THERMAL_LWIR" & ~[m.footprints.valid]);
            tc.verifyTrue(all([fp.nominal])); tc.verifyEqual(numel(fp), height(dropT));
        end

        function d09_staleAndTimestampRejection(tc)                          % stale / mismatch policy
            [d, sys] = tc.freshPipeline(60);
            S = sys.samplesAt(40); S2 = sys.samplesAt(60);
            rgb40 = S{end}; rgb60 = S2{end};
            tc.verifyEqual(d.ingest(rgb60), "ACCEPTED");
            tc.verifyEqual(d.ingest(rgb60), "STALE_OR_DUPLICATE");
            th40 = S{end-1}; tc.verifyEqual(d.ingest(th40), "STALE_DATA");          % 20 ticks older than the clock
            x = S2{end-1}; x.t_s = x.t_s + 0.05; tc.verifyEqual(d.ingest(x), "TIMESTAMP_MISMATCH");
            x = S2{end-1}; x.run_id = "OTHER-RUN"; tc.verifyEqual(d.ingest(x), "RUN_MISMATCH");
            tc.verifyEqual(d.ingest(S2{end-1}), "ACCEPTED");                  % the genuine thermal frame still accepted
            T = d.trackTable(); tc.verifyTrue(all(T.last_tick <= 60));
            n = sum(d.Log.n_candidates(d.Log.outcome ~= "ACCEPTED")); tc.verifyEqual(n, 0);
            tc.verifyEqual(rgb40.tick_id, uint64(40));
        end

        function d10_noFutureLeakage(tc)                                     % EVAL-12, G8
            [d, sys, eng] = tc.freshPipeline(); d.attach(sys); eng.run(700);
            E1 = d.events(); t1 = d.CurrentTick;
            for e = E1', tc.verifyLessThanOrEqual(e.last_tick, t1); tc.verifyLessThanOrEqual(max(double([e.evidence_refs.tick_id])), t1); end
            L = d.Log; tc.verifyTrue(all(diff(double(L.tick_id)) >= 0));
            tc.verifyEqual(L.t_s, double(L.tick_id) * 0.05, 'AbsTol', 1e-9);
            eng.run(200); E2 = d.events();
            ids1 = [E1.event_id]; ids2 = [E2.event_id];
            % stable ids: an event present at tick 700 keeps its id (it may only gain evidence later)
            for k = 1:numel(E1)
                j = find(ids2 == ids1(k));
                if ~isempty(j), tc.verifyLessThan(hypot(E2(j).x_est_m - E1(k).x_est_m, E2(j).y_est_m - E1(k).y_est_m), 1.0); end
            end
            tc.verifyGreaterThan(d.CurrentTick, t1);
        end

        function d11_determinism(tc)                                         % same seed/config -> same events
            [d1, s1, e1] = tc.freshPipeline(); d1.attach(s1); e1.run(400);
            [d2, s2, e2] = tc.freshPipeline(); d2.attach(s2); e2.run(400);
            tc.verifyEqual(d1.trackTable(), d2.trackTable());
            tc.verifyEqual(d1.events(), d2.events());
        end

        function d12_associationAndDedup(tc)                                 % deterministic association, stable ids
            T = tc.Demo.track_table; cfg = mgv2.detect.defaultDetectorConfig();
            tc.verifyEqual(numel(unique(T.track_no)), height(T));
            D = hypot(T.x_m - T.x_m', T.y_m - T.y_m'); D(1:height(T)+1:end) = inf;
            tc.verifyGreaterThan(min(D(:)), cfg.association.merge_m);          % no two live tracks within merge distance
            R = mgv2.eval.evaluateEvents(tc.Demo.events, tc.DemoTruth);
            near = hypot([tc.Demo.events.x_est_m] - 5.5, [tc.Demo.events.y_est_m] - 3.25) < 1.0;
            tc.verifyEqual(nnz(near), 1);                                      % one fixture -> one event (no duplicates)
            e = tc.Demo.events(R.matched_event_index);
            tc.verifyGreaterThan(e.n_observations, 10);                        % many frames merged into one track
            tc.verifyEqual(numel(unique([tc.Demo.events.event_id])), numel(tc.Demo.events));
        end

        function d13_uncertaintyReported(tc)                                 % uncertainty or explicit reason
            cfg = mgv2.detect.defaultDetectorConfig(); c = mgv2.detect.contract();
            for e = tc.Demo.events'
                tc.verifyTrue(isfinite(e.uncertainty_m) && e.uncertainty_m >= cfg.association.pose_sigma_m);
                tc.verifyTrue(ismember(e.uncertainty_status, c.uncertainty_statuses));
            end
            T = tc.Demo.track_table; one = T(T.n_obs_rgb + T.n_obs_thermal == 1, :);
            tc.verifyTrue(all(one.sigma_m >= cfg.association.pose_sigma_m));
            E = tc.Demo.detector.events(Threshold=0); s1 = E([E.n_observations] == 1);
            tc.verifyEmpty(s1);                                                % min_detections = 2 blocks single sightings
        end

        function d14_coverageIntegrity(tc)                                   % AC-008, SC-20
            m = tc.Drop.map.snapshot(); C = m.cell_state;
            tc.verifyEqual(m.state_names, ["UNOBSERVED","PLANNED","TRAVERSED","INVALID_OBSERVED","VALID_OBSERVED"]);
            tc.verifyTrue(all(ismember(unique(C(:))', uint8(0:4))));
            tc.verifyTrue(all(m.valid_rgb_count(C == 3) == 0 & m.valid_thermal_count(C == 3) == 0));
            tc.verifyTrue(all(m.valid_rgb_count(C == 4) > 0 | m.valid_thermal_count(C == 4) > 0));
            tc.verifyTrue(all(m.traversed_count(C == 2) > 0));
            cv = m.coverage;
            tc.verifyEqual(cv.valid_any_camera_pct + cv.invalid_only_pct + cv.traversed_only_pct + cv.unobserved_pct, 100, 'AbsTol', 1e-9);
            tc.verifyTrue(contains(cv.meaning, "NOT detector accuracy") && contains(cv.meaning, "NOT a land-release"));
            full = tc.Demo.map.snapshot().coverage;
            tc.verifyEqual(full.valid_any_camera_pct, 100);                     % 100 % evidence coverage ...
            R = mgv2.eval.evaluateEvents(tc.Demo.events, tc.DemoTruth);
            tc.verifyGreaterThan(R.FP, 0);                                     % ... still has false alarms: coverage is not accuracy
            mgv2.detect.assertNoBannedWords(rmfield(m, {'footprints','actual_route'}), "map");
        end

        function d15_mapInitialisation(tc)                                   % AC-006
            [pub] = mgv2.eval.buildScenario(mgv2.eval.demoFixtureGroup());
            eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world));
            m = mgv2.map.MissionMap(pub.world, pub.mission); m.attach(eng); S = m.snapshot();
            tc.verifyEqual(S.boundary_enu_m, pub.mission.survey_polygon_enu_m);
            tc.verifyEqual(S.home_enu_m, pub.mission.home_enu_m);
            tc.verifyEqual(S.planned_route_enu_m, eng.Route.xy);
            tc.verifyEqual(numel(S.actual_route.x), 1); tc.verifyTrue(isfinite(S.actual_route.heading_deg));
            tc.verifyTrue(contains(S.frame, "virtual")); tc.verifyEqual(S.coverage.valid_any_camera_pct, 0);
            tc.verifyEqual(nnz(S.cell_state == 1), S.coverage.planned_cells);
        end

        function d16_footprintsTiedToTicks(tc)                               % AC-007 (timestamped footprints)
            F = tc.Demo.map.Footprints; L = tc.Demo.sensors.Log; P = tc.Demo.engine.poseLog();
            cam = L(L.sensor_id ~= "VIRTUAL_GNSS_INS", :);
            tc.verifyEqual(numel(F), height(cam));
            [ok, j] = ismember([F.frame_id]', cam.frame_id); tc.verifyTrue(all(ok));
            tc.verifyEqual([F.tick_id]', double(cam.tick_id(j))); tc.verifyEqual([F.t_s]', cam.t_s(j));
            tc.verifyEqual([F.t_s]', P.t_s([F.tick_id] + 1), 'AbsTol', 1e-12);
            s = tc.firstValid(tc.Demo.sensors, "THERMAL_LWIR");
            k = find([F.frame_id] == s.frame_id); tc.verifyEqual(F(k).polygon_enu_m, s.footprint_enu_m);
        end

        function d17_offlineMapView(tc)                                      % AC-009
            f = figure('Visible', 'off'); c = onCleanup(@() close(f)); ax = axes(f);
            v = mgv2.map.MapView(ax, tc.Demo.world, tc.Demo.map); v.refresh();
            tc.verifyTrue(contains(strjoin(string(ax.Title.String)), "OFFLINE LOCAL BASE MAP"));
            tc.verifyNotEmpty(findobj(ax, 'Type', 'image'));
            root = fullfile(fileparts(fileparts(mfilename('fullpath'))), '+mgv2', '+map');
            for F = dir(fullfile(root, '*.m'))'
                code = fileread(fullfile(F.folder, F.name));
                tc.verifyEmpty(regexp(code, 'webread|websave|webmap|geobasemap|geoaxes|urlread|http', 'once'), F.name);
            end
            tc.verifyTrue(contains(tc.Demo.map.snapshot().base_map, "OFFLINE"));
        end

        function d18_evidenceInspector(tc)                                   % AC-016: exact sample references
            D = tc.Demo; R = mgv2.eval.evaluateEvents(D.events, tc.DemoTruth); e = D.events(R.matched_event_index);
            ins = mgv2.detect.inspectEvent(e, D.detector, D.sensors.Log);
            tc.verifyTrue(all([ins.items.verified_against_sensor_log]));
            tc.verifyTrue(contains(ins.score_text, "uncalibrated"));
            tc.verifyEqual(sort(ins.sensors_used), ["RGB_NADIR","THERMAL_LWIR"]);
            for it = ins.items
                s = tc.sampleByFrame(D.sensors, it.frame_id); tc.assertNotEmpty(s);
                o = it.crop_origin_px; [h, w, ~] = size(it.crop);
                if it.sensor_id == "RGB_NADIR", ref = s.image_rgb_uint8(o(2):o(2)+h-1, o(1):o(1)+w-1, :);
                else, ref = s.temperature_K(o(2):o(2)+h-1, o(1):o(1)+w-1); end
                tc.verifyEqual(it.crop, ref);                                  % pixels from exactly that sample
            end
            bad = e; bad.evidence_refs(1).sample_checksum = "0000";
            tc.verifyError(@() mgv2.detect.inspectEvent(bad, D.detector, D.sensors.Log), 'mgv2:EvidenceMismatch');
            Lb = D.sensors.Log; Lb.checksum(Lb.frame_id == e.evidence_refs(1).frame_id) = "tampered";
            tc.verifyError(@() mgv2.detect.inspectEvent(e, D.detector, Lb), 'mgv2:EvidenceMismatch');
        end

        function d19_splitManifestFrozen(tc)                                 % EVAL-01, SC-24
            root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            J = jsondecode(fileread(fullfile(root, 'v2', 'data', 'V2-006', 'split_manifest.json'))); M = mgv2.eval.splitManifest();
            tc.verifyEqual(string(J.manifest_sha256), M.manifest_sha256);
            tc.verifyEqual(string({J.groups.definition_sha256})', [M.groups.definition_sha256]');
            G = mgv2.eval.scenarioGroups();
            for f = ["scene_seed","layout_seed","mission_seed"], tc.verifyEqual(numel(unique([G.(f)])), numel(G)); end
            sp = [G.split]; tc.verifyEqual([nnz(sp == "TRAIN") nnz(sp == "VAL") nnz(sp == "TEST")], [6 2 2]);
            allSeeds = @(s) [[G(sp == s).scene_seed] [G(sp == s).layout_seed] [G(sp == s).mission_seed]];
            tc.verifyEmpty(intersect(allSeeds("TRAIN"), allSeeds("VAL"))); tc.verifyEmpty(intersect(allSeeds("TRAIN"), allSeeds("TEST")));
            tc.verifyEmpty(intersect(allSeeds("VAL"), allSeeds("TEST")));
            for g = G(sp == "TEST"), tc.verifyError(@() mgv2.eval.runScenario(g), 'mgv2:TestSealed'); end
            g = G(1); g.scene_seed = 1; tc.verifyNotEqual(mgv2.eval.sha256(jsonencode(g)), M.groups(1).definition_sha256);
        end

        function d20_frozenThresholdAndValBaselines(tc)                      % EVAL-08
            root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))); dd = fullfile(root, 'v2', 'data', 'V2-006');
            F = jsondecode(fileread(fullfile(dd, 'detector_frozen.json'))); cfg = mgv2.detect.defaultDetectorConfig();
            tc.verifyEqual(string(F.detector_fingerprint), cfg.parameter_hash);
            tc.verifyEqual(string(F.split_manifest_sha256), mgv2.eval.splitManifest().manifest_sha256);
            S = readtable(fullfile(dd, 'train_selection.csv'), 'TextType', 'string');
            for k = 1:height(S), tc.verifyEqual(cfg.event.score_threshold.(char(S.score_mode(k))), S.threshold(k), 'AbsTol', 1e-12); end
            P = readtable(fullfile(dd, 'tuning_log.csv'), 'TextType', 'string'); G = mgv2.eval.scenarioGroups();
            tc.verifyEqual(sort(unique(P.group_id))', sort([G([G.split] == "TRAIN").group_id]));   % tuning saw TRAIN only
            V = readtable(fullfile(dd, 'val_results.csv'), 'TextType', 'string');
            tc.verifyEqual(sort(unique(V.group_id))', sort([G([G.split] == "VAL").group_id]));
            tc.verifyEqual(sort(unique(V.score_mode))', ["FUSED","RGB_ONLY","THERMAL_ONLY"]);
            tc.verifyFalse(any(ismember(V.group_id, [G([G.split] == "TEST").group_id])));
            tc.verifyEqual(V.TP + V.FN, V.n_targets); tc.verifyEqual(V.TP + V.FP, V.n_events);
        end

        function d21_uncalibratedScoresAndWording(tc)                        % SC-22 wording, no probability
            for e = tc.Demo.events'
                tc.verifyTrue(contains(e.score_kind, "UNCALIBRATED")); tc.verifyFalse(any(contains(lower(string(fieldnames(e))), "prob")));
                mgv2.detect.assertNoBannedWords(e, "event");
            end
            for t = ["area is SAFE", "ground cleared", "Confirmed mine", "clearance done", "probability of detection"]
                tc.verifyError(@() mgv2.detect.assertNoBannedWords(struct('t', t)), 'mgv2:BannedWording');
            end
            mgv2.detect.assertNoBannedWords(struct('t', "unconfirmed; safety note"));    % whole words only
            e = tc.Demo.events(1); e.status = "CONFIRMED"; tc.verifyError(@() mgv2.detect.validateEvent(e), 'mgv2:InvalidEvent');
            e = tc.Demo.events(1); e.label_text = "SAFE"; tc.verifyError(@() mgv2.detect.validateEvent(e), 'mgv2:BannedWording');
        end

        function d22_interpretableFeatures(tc)                               % RGB z, thermal K, LiDAR height
            cfg = mgv2.detect.defaultDetectorConfig(); w = tc.Demo.world;
            s = tc.firstValid(tc.Demo.sensors, "THERMAL_LWIR"); x = s;
            [U, V] = meshgrid(1:x.image_width, 1:x.image_height); disc = hypot(U - 60, V - 50) <= 4;
            x.temperature_K = 290 + zeros(size(x.temperature_K)); x.temperature_K(disc) = 293; x.valid_pixel_mask(:) = true;
            C = mgv2.detect.frameCandidates(x, w, cfg);
            tc.assertEqual(numel(C.u_px), 1);
            tc.verifyEqual([C.u_px C.v_px], [60 50], 'AbsTol', 0.5);
            tc.verifyGreaterThan(C.strength, 2.0); tc.verifyLessThanOrEqual(C.strength, 3.0); tc.verifyEqual(C.polarity, 1);
            cam = struct('fx', x.focal_lengths_px(1), 'fy', x.focal_lengths_px(2), 'cx', x.principal_point_px(1), 'cy', x.principal_point_px(2));
            [O, D] = mgv2.scene.pixelRays(cam, x.T_world_sensor, [60 50]); P = mgv2.scene.intersectTerrain(w, O, D);
            tc.verifyLessThan(hypot(C.x_m - P(1), C.y_m - P(2)), 0.05);
            x.temperature_K(:) = 290; tc.verifyEmpty(mgv2.detect.frameCandidates(x, w, cfg).u_px);   % flat frame: no forced hotspot
            r = tc.firstValid(tc.Demo.sensors, "RGB_NADIR"); y = r; y.image_rgb_uint8(:) = 120; y.valid_pixel_mask(:) = true;
            y.image_rgb_uint8 = y.image_rgb_uint8 + uint8(randi(RandStream('mrg32k3a', 'Seed', 1), [0 4], size(y.image_rgb_uint8)));
            [U2, V2] = meshgrid(1:320, 1:240); d = hypot(U2 - 200, V2 - 120) <= 4;   % small disc, about 0.6 m; larger discs: see d26
            for c = 1:3, ch = y.image_rgb_uint8(:,:,c); ch(d) = 40; y.image_rgb_uint8(:,:,c) = ch; end
            Cr = mgv2.detect.frameCandidates(y, w, cfg);
            tc.assertGreaterThanOrEqual(numel(Cr.u_px), 1); tc.verifyEqual(Cr.polarity(1), -1); tc.verifyGreaterThan(Cr.strength(1), cfg.rgb.z_threshold);
            E = tc.Demo.events; ctx = arrayfun(@(e) e.features.lidar_context, E);
            tc.verifyTrue(all(ismember(ctx, ["FLAT","PROTRUDING_OBJECT","UNAVAILABLE"])));
            T = tc.Demo.track_table; O2 = tc.Demo.world.objects; rk = O2(O2.kind == "rock" & O2.height_m > 0.3, :);
            hasRock = false;
            for k = 1:height(rk)
                j = find(hypot(T.x_m - rk.x_east_m(k), T.y_m - rk.y_north_m(k)) < 0.7 & T.lidar_returns > 0, 1);
                if ~isempty(j), hasRock = true; tc.verifyGreaterThan(T.lidar_height_m(j), 0.15); end
            end
            tc.verifyTrue(hasRock);
            fix = E(hypot([E.x_est_m] - 5.5, [E.y_est_m] - 3.25) < 1); tc.verifyEqual(fix.features.lidar_context, "FLAT");   % flat paint: LiDAR blind
        end

        function d23_missingModalityPolicy(tc)                               % single-channel labelling, policy switch
            D = tc.Drop.detector; E = D.events(); c = mgv2.detect.contract();
            tc.verifyTrue(all(ismember([E.detection_basis], c.bases)));
            T = D.trackTable(); cfg = D.Config;
            [keep] = mgv2.detect.selectEvents(T, "FUSED", cfg.event.score_threshold.FUSED, cfg);
            single = keep & (T.n_obs_rgb == 0 | T.n_obs_thermal == 0);
            Eb = [E.detection_basis];
            tc.verifyEqual(nnz(Eb ~= "FUSED_RGB_THERMAL"), nnz(single));
            cfg2 = cfg; cfg2.event.emit_single_channel = false; cfg2 = mgv2.detect.validateDetectorConfig(cfg2);
            k2 = mgv2.detect.selectEvents(T, "FUSED", cfg2.event.score_threshold.FUSED, cfg2);
            tc.verifyEqual(nnz(k2), nnz(keep) - nnz(single));
            noTh = T(T.looks_thermal == 0 & T.n_obs_rgb > 0, :);
            for r = 1:height(noTh), tc.verifyTrue(isnan(noTh.support_thermal(r))); tc.verifyEqual(noTh.score_fused(r), noTh.support_rgb(r)); end
            s = tc.firstValid(tc.Drop.sensors, "RGB_NADIR"); x = s; x.valid = false; x.invalid_reason = "SENSOR_DROPOUT";
            tc.verifyEmpty(mgv2.detect.frameCandidates(x, tc.Drop.world, cfg).u_px);       % invalid frame: nothing
        end

        function d24_forwardHookBackwardCompatible(tc)                       % V2-005 unchanged without features
            w = mgv2.scene.buildWorld(); mc = mgv2.mission.defaultConfig();
            e1 = mgv2.engine.MissionEngine(mc, mgv2.scene.terrainProvider(w)); s1 = mgv2.sensors.SensorSystem(w, mc); s1.attach(e1); e1.run(60);
            e2 = mgv2.engine.MissionEngine(mc, mgv2.scene.terrainProvider(w)); s2 = mgv2.sensors.SensorSystem(w, mc, SurfaceFeatures=[]); s2.attach(e2); e2.run(60);
            tc.verifyEqual(s1.Log.checksum, s2.Log.checksum);
            [pub, fwd] = mgv2.eval.buildScenario(mgv2.eval.demoFixtureGroup());
            a = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world));
            sa = mgv2.sensors.SensorSystem(pub.world, pub.mission, SurfaceFeatures=fwd); sa.attach(a); a.run(40);
            b = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world));
            sb = mgv2.sensors.SensorSystem(pub.world, pub.mission); sb.attach(b); b.run(40);
            li = sa.Log.sensor_id == "LIDAR_TERRAIN" | sa.Log.sensor_id == "VIRTUAL_GNSS_INS";
            tc.verifyEqual(sa.Log.checksum(li), sb.Log.checksum(li));          % flat features: LiDAR / nav unaffected
            f = fwd; f(1).radius_m = -1; tc.verifyError(@() mgv2.sensors.validateSurfaceFeatures(f), 'mgv2:InvalidSensorConfig');
        end

        function d25_performanceLogged(tc)                                   % detector cost per sample (SC-29 style)
            L = tc.Demo.detector.Log;
            tc.verifyEqual(height(L), height(tc.Demo.sensors.Log));
            tc.verifyTrue(all(isfinite(L.proc_ms) & L.proc_ms >= 0));
            g = groupsummary(L, 'sensor_id', 'median', 'proc_ms');
            fprintf('    detector median ms: %s\n', strjoin(g.sensor_id + "=" + compose("%.1f", g.median_proc_ms), ", "));
        end

        function d26_knownLimitationRgbLargeObjectHalo(tc)                   % KNOWN LIMITATION of the frozen detector
            % Documents a weakness, not a desired behaviour: a dark disc whose true diameter is INSIDE the size
            % limit is dropped, because the box-mean halo inflates its component past max_diameter_m. If the
            % detector is ever changed so that this fails, the limitation and the evidence must be revisited.
            cfg = mgv2.detect.defaultDetectorConfig(); w = tc.Demo.world;
            F = jsondecode(fileread(fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), 'v2', 'data', 'V2-006', 'detector_frozen.json')));
            tc.assertEqual(cfg.parameter_hash, string(F.detector_fingerprint));  % the frozen detector, untuned
            r = tc.firstValid(tc.Demo.sensors, "RGB_NADIR"); y = r; y.valid_pixel_mask(:) = true;
            base = uint8(120 * ones(240, 320, 3)) + uint8(randi(RandStream('mrg32k3a', 'Seed', 1), [0 4], [240 320 3]));
            diag = cfg; diag.size.max_diameter_m = 20; diag = mgv2.detect.validateDetectorConfig(diag);   % measurement only
            [U, V] = meshgrid(1:320, 1:240); rad = [4 5 6 8 12]; nKept = zeros(size(rad)); meas = nan(size(rad)); gsd = NaN;
            for k = 1:numel(rad)
                d = hypot(U - 200, V - 120) <= rad(k); I = base;
                for c = 1:3, ch = I(:,:,c); ch(d) = 40; I(:,:,c) = ch; end
                y.image_rgb_uint8 = I;
                C = mgv2.detect.frameCandidates(y, w, cfg); nKept(k) = nnz(hypot(C.u_px - 200, C.v_px - 120) <= rad(k) + 2);
                M = mgv2.detect.frameCandidates(y, w, diag); [~, j] = max(M.area_px); meas(k) = M.diameter_m(j); gsd = M.gsd_m(j);
                fprintf('    r %2d px: true diameter %.2f m | measured %.2f m | frozen detector keeps %d\n', rad(k), 2 * rad(k) * gsd, meas(k), nKept(k));
            end
            tc.verifyLessThanOrEqual(2 * rad(4) * gsd, cfg.size.max_diameter_m);  % 8 px disc: true size is inside the limit
            tc.verifyEqual(nKept(1:2), [1 1]);                                 % small discs are kept (see also d22)
            tc.verifyEqual(nKept(3:end), [0 0 0]);                             % larger discs are lost
            tc.verifyGreaterThan(meas(3:4), cfg.size.max_diameter_m);          % because the halo inflates the measurement
            tc.verifyGreaterThan(meas(3:4), 1.5 * 2 * rad(3:4) * gsd);
        end

        function d27_inspectorSelectsPublicEventId(tc)                       % demo selection uses public output only
            before = findall(groot, 'Type', 'figure'); c = onCleanup(@() delete(setdiff(findall(groot, 'Type', 'figure'), before)));
            R = mgv2.eval.evaluateEvents(tc.Demo.events, tc.DemoTruth);         % evaluator step of this test only
            fixtureId = tc.Demo.events(R.matched_event_index).event_id;
            tc.verifyEqual(fixtureId, "SUS-00296");
            a = mgv2DetectionDemo(Run=tc.Demo, EventId="SUS-00296");
            tc.verifyEqual(a.inspector.event_id, fixtureId); tc.verifyEqual(a.selected_by, "explicit public event id");
            tc.verifyTrue(all([a.inspector.items.verified_against_sensor_log]));
            tc.verifyTrue(contains(a.label, "SYNTHETIC DEMO FIXTURE") && contains(a.label, "not VALIDATION evidence"));
            b = mgv2DetectionDemo(Run=tc.Demo);
            tc.verifyEqual(b.selected_event_id, "SUS-00113");                  % default: strongest fused score ...
            tc.verifyNotEqual(b.selected_event_id, fixtureId);                 % ... which is a false alarm here
            tc.verifyError(@() mgv2DetectionDemo(Run=tc.Demo, EventId="SUS-99999"), 'mgv2:EventNotFound');
            d = tempname; mkdir(d); cd2 = onCleanup(@() rmdir(d, 's')); fclose(fopen(fullfile(d, 'map-demo-fixture.png'), 'w'));
            tc.verifyError(@() mgv2DetectionDemo(Run=tc.Demo, ShotDir=d), 'mgv2:EvidenceExists');
            code = regexprep(fileread(which('mgv2DetectionDemo')), '%[^\n]*', '');   % no truth path in the demo
            tc.verifyEmpty(regexp(code, 'TargetTruth|buildScenario|evaluateEvents|demo_fixture', 'once'));
        end

        function d28_demoLabelsReadableInBothDesktopThemes(tc)               % UI-13: SIMULATED/SUSPECTED stay visible
            s = settings(); mt = s.matlab.appearance.MATLABTheme;
            c = onCleanup(@() mt.clearTemporaryValue());
            before = findall(groot, 'Type', 'figure'); c2 = onCleanup(@() delete(setdiff(findall(groot, 'Type', 'figure'), before)));
            for desktop = ["Dark","Light"]
                mt.TemporaryValue = desktop; t0 = tic; base = "";              % the switch applies asynchronously
                while base ~= lower(desktop) && toc(t0) < 15
                    pause(0.25); ctl = figure('Visible', 'off'); base = string(ctl.Theme.BaseColorStyle); delete(ctl);
                end
                tc.assumeEqual(base, lower(desktop), 'this host cannot switch the desktop theme');
                a = mgv2DetectionDemo(Run=tc.Demo, EventId="SUS-00296");
                for f = [a.map_figure a.inspector_figure]
                    tc.verifyEqual(string(f.Theme.BaseColorStyle), "light", desktop + " desktop: " + f.Name);
                    tc.verifyEqual(f.Color, [1 1 1]);
                    tc.verifyGreaterThanOrEqual(testV2006Detection.worstTextContrast(f), 4.5, desktop + " desktop: " + f.Name);
                end
                txt = lower(strjoin(string(get(findall(a.inspector_figure, 'Type', 'textboxshape'), 'String'))));
                tc.verifyTrue(contains(txt, "simulated") && contains(txt, "synthetic demo fixture"));
                delete([a.map_figure a.inspector_figure]);
            end
        end
    end
end
