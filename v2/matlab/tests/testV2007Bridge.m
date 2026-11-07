classdef testV2007Bridge < matlab.unittest.TestCase
    %TESTV2007BRIDGE V2-006 to V2-007 adapter on real public V2-005 samples. SIMULATED.
    %   From the repository root:  addpath('v2/matlab'); runtests('v2/matlab/tests/testV2007Bridge.m')
    %   Uses default-scene MissionSession runs. b18 alone uses the labelled DEMO FIXTURE, for integration only.
    %   No study stage runs, and TEST stays sealed. A pass here says nothing about detection success.

    properties (Constant)
        N = 500       % ticks of the shared run
    end
    properties
        Src; Ses
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
            [tc.Src, tc.Ses] = testV2007Bridge.flown(tc.N);
        end
    end

    methods (Static)
        function [src, ses] = flown(n, varargin)
            src = mgv2.bridge.V2006AnomalySource(varargin{:});
            ses = mgv2.ui.MissionSession(AnomalySource=src); ses.start();
            testV2007Bridge.advance(ses, n);
        end
        function advance(ses, n)
            for k = 1:n, if ~ses.step(), break; end, end
        end
        function [src, c, id] = rig()
            %RIG A real detector run whose provider returns a context the test controls. Nothing here reaches a session.
            ses = mgv2.ui.MissionSession(); w = ses.World; m = ses.MissionConfig; eng = mgv2.engine.MissionEngine(m, mgv2.scene.terrainProvider(w));
            sys = mgv2.sensors.SensorSystem(w, m); src = mgv2.bridge.V2006AnomalySource();
            c = containers.Map('KeyType', 'char', 'ValueType', 'any');
            c('ctx') = struct('run_id', string(m.run_id), 'generation', 1, 'state', "READY", 'tick', 0, 'sensor_log', sys.Log);
            src.bindEvidence(@() c('ctx')); src.bindRun(w, m); src.onPose(eng.snapshot());
            eng.subscribe(@(p) src.onPose(p)); sys.subscribe(@(s) src.onSample(s)); sys.attach(eng);
            eng.start(); for k = 1:testV2007Bridge.N, eng.step(); end
            c('ctx') = struct('run_id', string(m.run_id), 'generation', 1, 'state', "PAUSED", 'tick', double(eng.TickId), 'sensor_log', sys.Log);
            ev = src.suspectedEvents(); id = ev(1).event_id;
        end
        function withLog(src, c, g, L, id)
            g.sensor_log = L; c('ctx') = g; src.inspect(id);
        end
        function keepFrame(F, s)
            F(char(s.frame_id)) = s; %#ok<NASGU> handle object
        end
        function t = eventTable(E)
            t = table([E.event_id]', [E.x_est_m]', [E.y_est_m]', [E.model_score]', 'VariableNames', ["id","x","y","score"]);
        end
    end

    methods (Test)
        function b01_eventFieldMapping(tc)                                   % explicit mapping, schema unchanged
            ev = tc.Src.suspectedEvents(); E = tc.Src.Detector.events();
            tc.assertNotEmpty(ev); tc.verifyEqual(numel(ev), numel(E));
            for k = 1:numel(ev)
                tc.verifyEqual(ev(k).t_s, E(k).last_t_s); tc.verifyEqual(ev(k).confidence_kind, E(k).score_kind);
                tc.verifyEqual(ev(k).modality_flags, E(k).detection_basis); tc.verifyEqual(ev(k).x_est_m, E(k).x_est_m);
                tc.verifyEqual(ev(k).evidence_refs, E(k).evidence_refs); tc.verifyEqual(ev(k).status, "SUSPECTED");
                tc.verifyTrue(contains(ev(k).confidence_kind, "UNCALIBRATED"));
                mgv2.detect.validateEvent(E(k));                               % the detector event still meets its own contract
            end
            tc.verifyEqual(string(fieldnames(E))', mgv2.detect.contract().event_fields);
        end

        function b02_uiValidatorsAndPublicOutput(tc)
            v = tc.Ses.view();                                                 % the session runs both UI validators
            tc.verifyTrue(v.source.connected); tc.assertNotEmpty(v.events); tc.verifyNotEmpty(v.layers);
            mgv2.sensors.assertPublic(v.events, "events"); mgv2.sensors.assertPublic(v.layers, "layers"); mgv2.sensors.assertPublic(v.source, "info");
            F = jsondecode(fileread(fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), 'v2', 'data', 'V2-006', 'detector_frozen.json')));
            tc.verifyEqual(v.source.detector_fingerprint, string(F.detector_fingerprint));   % frozen detector, untuned
        end

        function b03_cacheAndFreshness(tc)                                   % rebuild by ticks, age is explicit
            [src, ses] = testV2007Bridge.flown(40, RefreshTicks=20);
            a = src.suspectedEvents(); n = src.Stats.rebuilds; i = src.sourceInfo();
            tc.verifyEqual(i.stale_ticks, i.current_tick - i.events_as_of_tick);
            for k = 1:5, b = src.suspectedEvents(); src.mapLayers(); end
            tc.verifyEqual(src.Stats.rebuilds, n); tc.verifyEqual(b, a);      % repeated requests reuse the validated result
            ses.step(); ses.step(); ses.step(); ses.step();
            src.suspectedEvents(); i2 = src.sourceInfo();
            if i.stale_ticks + 4 < 20
                tc.verifyEqual(src.Stats.rebuilds, n);
                tc.verifyEqual(i2.events_as_of_tick, i.events_as_of_tick); tc.verifyGreaterThan(i2.stale_ticks, i.stale_ticks);   % age is reported
            end
            testV2007Bridge.advance(ses, 20); src.suspectedEvents();
            tc.verifyGreaterThan(src.Stats.rebuilds, n);
            tc.verifyLessThan(src.sourceInfo().stale_ticks, 20);
            tc.verifyEqual(src.Stats.rebuild_tick, unique(src.Stats.rebuild_tick));   % as-of ticks only increase
        end

        function b04_freshWhenPausedOrEnded(tc)                              % no stale list once the clock holds
            [src, ses] = testV2007Bridge.flown(44, RefreshTicks=1000);
            src.suspectedEvents(); testV2007Bridge.advance(ses, 8);
            src.suspectedEvents(); tc.verifyGreaterThan(src.sourceInfo().stale_ticks, 0);   % ACTIVE: held by the budget
            ses.pauseRun(); tc.verifyEqual(ses.state(), "PAUSED");
            src.suspectedEvents(); tc.verifyEqual(src.sourceInfo().stale_ticks, 0);
            ses.resumeRun(); testV2007Bridge.advance(ses, 8); ses.abortRun(); tc.verifyEqual(ses.state(), "ENDED");
            src.suspectedEvents(); tc.verifyEqual(src.sourceInfo().stale_ticks, 0);
        end

        function b05_coverageMask(tc)                                        % UNOBSERVED transparent, never "cleared"
            L = tc.Src.mapLayers(); c = L([L.kind] == "raster"); tc.assertNumElements(c, 1);
            S = tc.Src.Map.snapshot(); rgba = mgv2.map.MapView.StateRGBA;
            tc.verifyEqual(c.x_enu_m, S.cell_x_m); tc.verifyEqual(c.y_enu_m, S.cell_y_m);
            tc.verifyEqual(size(c.alpha), size(S.cell_state)); tc.verifyEqual(size(c.cdata), [size(S.cell_state) 3]);
            tc.assertGreaterThan(nnz(S.cell_state == 0), 0);
            tc.verifyEqual(c.alpha(S.cell_state == 0), zeros(nnz(S.cell_state == 0), 1));   % unobserved stays absent
            tc.verifyTrue(all(c.alpha(S.cell_state == 4) == rgba(5, 4)));
            for l = L', tc.verifyEmpty(regexp(char(l.display_name), '\<(safe|cleared|confirmed|hazard-free)\>', 'once', 'ignorecase')); end
            tc.verifyTrue(contains(c.display_name, "evidence acquisition only"));
        end

        function b06_noDuplicateSubscriptions(tc)                            % every sample and pose exactly once
            src = tc.Src; ses = tc.Ses;
            tc.verifyEqual(src.Stats.binds, 1);
            tc.verifyEqual(height(src.Detector.Log), height(ses.Sensors.Log));
            tc.verifyEqual(src.Detector.Log.frame_id, ses.Sensors.Log.frame_id);
            tc.verifyEqual(numel(src.Map.Route.t_s), ses.Engine.TickId + 1);
            tc.verifyEqual(src.Map.Route.tick_id, (0:ses.Engine.TickId)');
            tc.verifyEqual(src.Stats.samples, height(ses.Sensors.Log));
            tc.verifyEqual(src.Stats.poses, ses.Engine.TickId + 1);
        end

        function b07_resetAndDeterministicReplay(tc)
            [src, ses] = testV2007Bridge.flown(200);
            E1 = src.Detector.events(); L1 = ses.Sensors.Log.checksum; first = src.Detector;
            ses.reset(); v = ses.view();
            tc.verifyEqual(numel(v.events), 0); tc.verifyEqual(double(v.pose.tick_id), 0); tc.verifyEqual(src.Stats.resets, 1);
            tc.verifyTrue(src.Detector ~= first);
            tc.verifyEqual(height(src.Detector.Log), height(ses.Sensors.Log));   % tick-0 samples of the new run only
            ses.start(); testV2007Bridge.advance(ses, 200);
            tc.verifyEqual(ses.Sensors.Log.checksum, L1);
            E2 = src.Detector.events(); tc.verifyEqual(E2, E1);               % same seed gives identical events
            tc.verifyEqual(src.Stats.binds, 2);                               % one per engine, none duplicated
            tc.verifyEqual(numel(src.Map.Route.t_s), 201);                    % poses of the new run only
            [src3, ~] = testV2007Bridge.flown(200); tc.verifyEqual(src3.Detector.events(), E1);
        end

        function b08_bindingRules(tc)
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(AnomalySource=src);
            tc.verifyEqual(src.Map.Route.x(1), ses.Engine.snapshot().position_enu_m(1));   % bound by the session itself
            tc.verifyEqual(src.Detector.RunId, string(ses.MissionConfig.run_id));
            tc.verifyEqual(height(src.Detector.Log), height(ses.Sensors.Log));   % tick-0 samples arrived through the seam
            tc.verifyError(@() mgv2.ui.MissionSession(AnomalySource=src), 'mgv2:BridgeAlreadyBound');   % one source, one session
            tc.verifyEqual(src.Stats.binds, 1);                                % the refused session changed nothing
        end

        function b09_unboundFailsClosed(tc)                                  % never invents output
            src = mgv2.bridge.V2006AnomalySource(); i = src.sourceInfo();
            tc.verifyFalse(i.connected); tc.verifyEmpty(src.suspectedEvents()); tc.verifyEmpty(src.mapLayers());
            tc.verifyEqual(i.status_text, "DETECTOR BRIDGE NOT BOUND");
            tc.verifyError(@() src.inspect("SUS-00001"), 'mgv2:BridgeNotBound');
            s = mgv2.ui.MissionSession().Sensors.latest("RGB_NADIR"); src.onSample(s); src.onPose(mgv2.ui.MissionSession().pose());
            tc.verifyEqual(src.Stats.samples, 0); tc.verifyEqual(src.Stats.samples_unbound, 1); tc.verifyEqual(src.Stats.poses, 0);
        end

        function b23_plainLaunchWorksThroughTheSeam(tc)                      % no manual bind, including verified evidence
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(AnomalySource=src); ses.start();
            testV2007Bridge.advance(ses, tc.N);
            tc.verifyEqual(height(src.Detector.Log), height(ses.Sensors.Log));
            tc.verifyEqual(src.Stats.poses, ses.Engine.TickId + 1);
            v = ses.view(); tc.assertNotEmpty(v.events); tc.verifyEqual(v.overlay_error, "");
            tc.verifyEqual(v.overlay_key, double(v.source.events_as_of_tick));
            id = v.events(1).event_id;
            ins = ses.inspect(id);                       % passes the UI's own validateInspection
            tc.verifyTrue(all([ins.items.verified_against_sensor_log]));
            tc.verifyEqual(ins.event_id, id); tc.verifyTrue(ins.simulated);
        end

        function b24_scenarioChangeStartsANewRun(tc)                         % new run id; nothing carried over
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(AnomalySource=src); first = src.Detector;
            ses.configure("Thermal dropout", 77);
            tc.verifyTrue(src.Detector ~= first); tc.verifyEqual(src.Detector.RunId, string(ses.MissionConfig.run_id));
            tc.verifyEqual(src.Stats.binds, 2); tc.verifyEqual(src.Stats.poses, 2);   % tick 0 of each engine, once
            ses.start(); testV2007Bridge.advance(ses, 300);
            tc.verifyEqual(height(src.Detector.Log), height(ses.Sensors.Log));
            v = ses.view(); tc.verifyEqual(v.overlay_error, "");
            L = src.Detector.Log; tc.verifyGreaterThan(nnz(L.outcome == "INVALID_SAMPLE"), 0);   % the dropout stays visible
            for e = reshape(v.events, 1, []), tc.verifyEqual(e.run_id, string(ses.MissionConfig.run_id)); end
        end

        function b25_freshnessTickChangesWithContent(tc)                     % the UI skips redraws while the tick is unchanged
            [src, ses] = testV2007Bridge.flown(40, RefreshTicks=1000);
            v1 = ses.view(); k1 = v1.overlay_key; testV2007Bridge.advance(ses, 5);
            ses.view(); tc.verifyEqual(src.sourceInfo().events_as_of_tick, k1);   % ACTIVE: held by the budget
            ses.pauseRun(); v2 = ses.view();
            tc.verifyGreaterThan(v2.overlay_key, k1);                          % new content arrives with a new tick
            tc.verifyEqual(v2.source.stale_ticks, 0);
            a = src.Stats.rebuilds; ses.view(); ses.view(); tc.verifyEqual(src.Stats.rebuilds, a);   % nothing new: no rebuild
        end

        function b10_wrongRunSampleRefused(tc)
            [src, ses] = testV2007Bridge.flown(40);
            s = ses.Sensors.latest("RGB_NADIR"); s.run_id = "OTHER-RUN"; s.tick_id = s.tick_id + 400; s.pose_id = s.tick_id;
            s.t_s = double(s.tick_id) * 0.05;
            nFoot = numel(src.Map.Footprints); nRef = src.Stats.samples_refused;
            src.onSample(s);
            tc.verifyEqual(src.Detector.Log.outcome(end), "RUN_MISMATCH");
            tc.verifyEqual(numel(src.Map.Footprints), nFoot);                  % never reaches the map
            tc.verifyEqual(src.Stats.samples_refused, nRef + 1);
            [ev, rej] = mgv2.bridge.toUiEvents(src.Detector.events(), "OTHER-RUN", src.Detector);
            tc.verifyEmpty(ev); tc.verifyEqual(numel(rej), numel(src.Detector.events()));   % wrong-run events rejected, all reported
        end

        function b11_invalidSensorFrames(tc)                                 % dropout stays visible and adds nothing
            cfg = mgv2.sensors.defaultSensorConfig(); cfg.THERMAL_LWIR.dropout_model.intervals_s = [2 6];
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(SensorConfig=cfg, AnomalySource=src); ses.start();
            testV2007Bridge.advance(ses, 200);
            L = ses.Sensors.Log; drop = L(L.invalid_reason == "SENSOR_DROPOUT", :); tc.assertNotEmpty(drop);
            D = src.Detector.Log; d = D(ismember(D.frame_id, drop.frame_id), :);
            tc.verifyTrue(all(d.outcome == "INVALID_SAMPLE")); tc.verifyTrue(all(d.n_candidates == 0));
            tc.verifyGreaterThan(nnz(src.Map.snapshot().invalid_count), 0);    % visible as invalid data on the map
            for e = reshape(src.Detector.events(), 1, [])
                th = e.evidence_refs([e.evidence_refs.sensor_id] == "THERMAL_LWIR");
                tc.verifyFalse(any([th.t_s] >= 2 & [th.t_s] <= 6));            % no evidence from a dropped frame
            end
        end

        function b12_truthFirewall(tc)
            [src, ses] = testV2007Bridge.flown(20);
            s = ses.Sensors.latest("RGB_NADIR"); x = s; x.quality.TargetTruth = struct('x', 1); n = src.Stats.samples;
            tc.verifyError(@() src.onSample(x), 'mgv2:TruthLeak'); tc.verifyEqual(src.Stats.samples, n);
            un = mgv2.bridge.V2006AnomalySource();
            tc.verifyError(@() un.onSample(x), 'mgv2:TruthLeak');              % also while unbound
            root = fullfile(fileparts(fileparts(mfilename('fullpath'))), '+mgv2', '+bridge');
            for F = dir(fullfile(root, '*.m'))'
                code = regexprep(fileread(fullfile(F.folder, F.name)), '%[^\n]*', '');
                tc.verifyEmpty(regexp(code, 'mgv2\.eval|TargetTruth|buildScenario|SurfaceFeatures|mgv2DetectorStudy', 'once'), F.name);
            end
        end

        function b13_missingEvidence(tc)
            d = tc.Src.Detector; E = d.events(); e = E(1); e.evidence_refs(1).ref_id = "OBS-99999999";
            tc.verifyError(@() mgv2.bridge.checkEvidence(e, d, tc.Ses.Sensors.Log, d.RunId), 'mgv2:EvidenceMissing');
            G = E; G(1) = e; [ev, rej] = mgv2.bridge.toUiEvents(G, d.RunId, d);
            tc.verifyEqual(rej, E(1).event_id); tc.verifyEqual(numel(ev), numel(E) - 1);
            g = E(1); g.evidence_refs = g.evidence_refs([]); [~, rej2] = mgv2.bridge.toUiEvents(g, d.RunId, d);
            tc.verifyEqual(rej2, g.event_id);                                  % no references, no display
            tc.verifyError(@() tc.Src.inspect("SUS-99999"), 'mgv2:EventNotFound');
        end

        function b14_checksumMismatch(tc)
            d = tc.Src.Detector; E = d.events(); e = E(1); L = tc.Ses.Sensors.Log;
            x = e; x.evidence_refs(1).sample_checksum = "0000";
            tc.verifyError(@() mgv2.bridge.checkEvidence(x, d, L, d.RunId), 'mgv2:EvidenceMismatch');
            [~, rej] = mgv2.bridge.toUiEvents(x, d.RunId, d); tc.verifyEqual(rej, e.event_id);
            Lb = L; Lb.checksum(Lb.frame_id == e.evidence_refs(1).frame_id) = "tampered";
            tc.verifyError(@() mgv2.bridge.checkEvidence(e, d, Lb, d.RunId), 'mgv2:EvidenceMismatch');
            tc.verifyError(@() mgv2.bridge.checkEvidence(e, d, L, "OTHER-RUN"), 'mgv2:BridgeRunMismatch');
        end

        function b15_inspectRealEvent(tc)                                    % crops come from exactly that sample
            ev = tc.Src.suspectedEvents(); ins = tc.Src.inspect(ev(1).event_id);
            tc.verifyEqual(ins.event_id, ev(1).event_id);
            tc.verifyTrue(all([ins.items.verified_against_sensor_log]));
            tc.verifyTrue(contains(ins.score_text, "uncalibrated"));
            tc.verifyNotEmpty(ins.items(1).crop);
        end

        function b16_bridgeDoesNotPerturbTheRun(tc)                          % same samples, same events as V2-006 alone
            ses0 = mgv2.ui.MissionSession(); ses0.start(); testV2007Bridge.advance(ses0, tc.N);
            tc.verifyEqual(tc.Ses.Sensors.Log.checksum, ses0.Sensors.Log.checksum);
            tc.verifyEqual(tc.Ses.Engine.poseLog(), ses0.Engine.poseLog());
            w = ses0.World; m = ses0.MissionConfig; eng = mgv2.engine.MissionEngine(m, mgv2.scene.terrainProvider(w));
            sys = mgv2.sensors.SensorSystem(w, m); d = mgv2.detect.AnomalyDetector(w, m); d.attach(sys); sys.attach(eng);
            eng.start(); for k = 1:tc.N, eng.step(); end
            tc.verifyEqual(tc.Src.Detector.events(), d.events());
        end

        function b17_noSecondRouteState(tc)                                  % MapPanel owns plan, UAV and flown route
            L = tc.Src.mapLayers();
            tc.verifyEmpty(setdiff([L.id], ["v2006_coverage","v2006_suspected"]));
            tc.verifyFalse(any(ismember([L.kind], "polyline")));
            ev = tc.Src.suspectedEvents(); p = L([L.id] == "v2006_suspected");
            tc.verifyEqual(p.x_enu_m, [ev.x_est_m]); tc.verifyEqual(p.y_enu_m, [ev.y_est_m]);
        end

        function b18_demoFixtureEvidence(tc)                                 % DEMO FIXTURE: integration only, not accuracy
            g = mgv2.eval.demoFixtureGroup(); o = mgv2.eval.runScenario(g, MaxTicks=1000);
            [ev, rej] = mgv2.bridge.toUiEvents(o.events, string(o.mission.run_id), o.detector);
            tc.verifyEmpty(rej); ev = mgv2.ui.validateEvents(ev); tc.verifyNumElements(ev, numel(o.events));
            [~, ~, TT] = mgv2.eval.buildScenario(g); tc.assertTrue(TT.demo_fixture);   % evaluator step of this test only
            R = mgv2.eval.evaluateEvents(o.events, TT); tc.assertEqual(R.TP, 1);
            e = o.events(R.matched_event_index);
            ins = mgv2.bridge.checkEvidence(e, o.detector, o.sensors.Log, string(o.mission.run_id));
            tc.verifyTrue(all([ins.items.verified_against_sensor_log]));
            fprintf('    DEMO FIXTURE only (excluded from accuracy): %d events through the bridge mapping, %s evidence verified\n', numel(ev), e.event_id);
        end

        function b19_appRendersBridgeOutput(tc)                              % real window: layers, table, reset
            src = mgv2.bridge.V2006AnomalySource();
            app = mgv2.ui.MissionControlApp(Visible="off", RealTime=0, MaxTicksPerRun=400, AnomalySource=src);
            c = onCleanup(@() delete(app));
            app.command("start"); drawnow;
            ax = app.Panels.map.Axes;                                          % layers have hidden handles: findall, not findobj
            tc.verifyNumElements(findall(ax, 'Tag', 'layer_v2006_coverage'), 1);
            ev = src.suspectedEvents(); tbl = app.Panels.events.Table;
            tc.assertNotEmpty(ev); tc.verifyEqual(size(tbl.Data, 1), numel(ev));
            tc.verifyEqual(string(tbl.Data{1, 1}), ev(1).event_id);
            m = findall(ax, 'Tag', 'layer_v2006_suspected'); tc.assertNumElements(m, 1);
            tc.verifyEqual(m.XData, [ev.x_est_m]);
            tc.verifyEqual(numel(findall(ax, 'Tag', 'map_flown')), 1);         % still one route line, owned by the panel
            tc.verifyTrue(contains(string(app.Panels.events.StatusLabel.Text), "uncalibrated"));
            app.command("abort"); app.command("reset"); drawnow;
            tc.verifyEqual(size(tbl.Data, 1), 0); tc.verifyEqual(double(app.Session.Engine.TickId), 0);
            tc.verifyEmpty(findall(ax, 'Tag', 'layer_v2006_suspected'));
            app.command("start"); drawnow;
            tc.verifyEqual(numel(src.Map.Route.t_s), app.Session.Engine.TickId + 1);   % the reset run is followed
        end

        function b21_duplicateAndStaleSamplesRefused(tc)                     % injected repeats change nothing
            [src, ses] = testV2007Bridge.flown(60);
            d = src.Detector; dt = d.Dt; E0 = d.events(); nFoot = numel(src.Map.Footprints); nRef = src.Stats.samples_refused;
            s = ses.Sensors.latest("RGB_NADIR"); src.onSample(s);              % exact repeat of a delivered sample
            tc.verifyEqual(d.Log.outcome(end), "STALE_OR_DUPLICATE");
            tc.verifyEqual(numel(src.Map.Footprints), nFoot); tc.verifyEqual(src.Stats.samples_refused, nRef + 1);
            tc.verifyEqual(d.events(), E0);
            l = ses.Sensors.latest("LIDAR_TERRAIN"); l.tick_id = l.tick_id + 100; l.pose_id = l.tick_id; l.t_s = double(l.tick_id) * dt;
            src.onSample(l); tc.assertEqual(d.Log.outcome(end), "ACCEPTED");   % moves the detector clock ahead
            nFoot = numel(src.Map.Footprints);
            r = s; r.tick_id = r.tick_id + 1; r.pose_id = r.tick_id; r.t_s = double(r.tick_id) * dt;
            src.onSample(r);                                                   % newer for its sensor, too old for the clock
            tc.verifyEqual(d.Log.outcome(end), "STALE_DATA");
            tc.verifyEqual(numel(src.Map.Footprints), nFoot); tc.verifyEqual(src.Stats.samples_refused, nRef + 2);
        end

        function b22_emptyEventsAreValidOutput(tc)                           % no events is shown as none, not as clear ground
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(AnomalySource=src);
            v = ses.view();
            tc.verifyEmpty(v.events); tc.verifyTrue(v.source.connected); tc.verifyEqual(v.source.rejected_events, 0);
            tc.verifyEqual([v.layers.id], "v2006_coverage");                   % no marker layer without events
            tc.verifyFalse(any(contains(lower(v.source.status_text), ["safe", "clear"])));
            [ev, rej] = mgv2.bridge.toUiEvents(src.Detector.events(), src.Detector.RunId, src.Detector);
            tc.verifyEmpty(ev); tc.verifyEmpty(rej);
            tc.verifyError(@() src.inspect("SUS-00001"), 'mgv2:EventNotFound');
        end

        function b26_automaticEvidenceInTheApp(tc)                           % plain launch, real table selection path
            src = mgv2.bridge.V2006AnomalySource();
            app = mgv2.ui.MissionControlApp(Visible="off", RealTime=0, MaxTicksPerRun=500, AnomalySource=src);
            c = onCleanup(@() delete(app)); app.command("start"); drawnow;
            ev = app.Session.view(false).events; tc.assertNotEmpty(ev); id = ev(1).event_id;
            app.selectEvent(id); drawnow;
            P = app.Panels.events; txt = string(P.DetailText.Text);
            tc.verifyTrue(contains(txt, id)); tc.verifyTrue(contains(txt, "verified against the sensor log"));
            tc.verifyFalse(contains(txt, "EVIDENCE NOT AVAILABLE"));
            tc.verifyNotEmpty(findall([P.RgbAxes P.ThermalAxes], 'Tag', 'event_crop'));
            app.selectEvent("SUS-99999"); drawnow;                             % an unknown event shows the failure and no image
            tc.verifyTrue(contains(string(P.DetailText.Text), "EVIDENCE NOT AVAILABLE"));
            tc.verifyEmpty(findall([P.RgbAxes P.ThermalAxes], 'Tag', 'event_crop'));
        end

        function b27_recordStatesRunAndAge(tc)                               % same run, exact as-of time, every row checked
            [src, ses] = testV2007Bridge.flown(tc.N, RefreshTicks=1000);
            ev = ses.view().events; tc.assertNotEmpty(ev); a = src.sourceInfo();
            testV2007Bridge.advance(ses, 7); ins = ses.inspect(ev(1).event_id); i = src.sourceInfo();
            tc.verifyEqual(ins.run_id, string(ses.MissionConfig.run_id));
            tc.verifyEqual(ins.events_as_of_tick, a.events_as_of_tick); tc.verifyEqual(ins.events_as_of_t_s, a.events_as_of_t_s);
            tc.verifyEqual(ins.events_as_of_t_s, a.events_as_of_tick * ses.MissionConfig.dt_s, AbsTol=1e-12);
            tc.verifyEqual(ins.current_tick, double(ses.Engine.TickId)); tc.verifyEqual(ins.stale_ticks, 7); tc.verifyEqual(i.stale_ticks, 7);
            L = ses.Sensors.Log;
            for it = reshape(ins.items, 1, [])
                r = L(L.frame_id == it.frame_id, :); tc.assertEqual(height(r), 1);
                tc.verifyEqual(r.checksum, it.sample_checksum); tc.verifyEqual(r.sensor_id, it.sensor_id); tc.verifyEqual(r.t_s, it.t_s); tc.verifyTrue(r.valid);
            end
        end

        function b28_otherRunRefused(tc)                                     % a provider that moved on is never trusted
            [src, c, id] = testV2007Bridge.rig(); ok = src.inspect(id); tc.verifyEqual(ok.event_id, id);
            g = c('ctx'); g.generation = g.generation + 1; c('ctx') = g;       %#ok<NASGU> same run id, later reset
            tc.verifyError(@() src.inspect(id), 'mgv2:BridgeRunMismatch');
            [src, c, id] = testV2007Bridge.rig(); g = c('ctx'); g.run_id = "OTHER-RUN"; c('ctx') = g; %#ok<NASGU>
            tc.verifyError(@() src.inspect(id), 'mgv2:BridgeRunMismatch');
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(); s = ses.evidenceContext();
            src.bindEvidence(@() setfield(s, 'run_id', "OTHER-RUN")); %#ok<SFLD>
            tc.verifyError(@() src.bindRun(ses.World, ses.MissionConfig), 'mgv2:BridgeRunMismatch');
        end

        function b29_resetAndRebind(tc)                                      % nothing of the old run can be inspected
            [src, ses] = testV2007Bridge.flown(tc.N); ev = ses.view().events; tc.assertNotEmpty(ev); id = ev(1).event_id;
            old = ses.inspect(id); ses.reset();
            tc.verifyError(@() ses.inspect(id), 'mgv2:EventNotFound');         % the new run has no such event yet
            ses.start(); testV2007Bridge.advance(ses, tc.N); ev2 = ses.view().events; tc.assertNotEmpty(ev2);
            again = ses.inspect(ev2(1).event_id); tc.verifyEqual(again.items(1).sample_checksum, old.items(1).sample_checksum);   % same seed
            ses.abortRun(); ses.reset(); ses.configure("Thermal dropout", 77);
            tc.verifyError(@() ses.inspect(id), 'mgv2:EventNotFound');
            ses.start(); testV2007Bridge.advance(ses, tc.N); ev3 = ses.view().events; tc.assertNotEmpty(ev3);
            ins = ses.inspect(ev3(1).event_id); tc.verifyEqual(ins.run_id, string(ses.MissionConfig.run_id));
            tc.verifyNotEqual(ins.run_id, old.run_id);
            L = ses.Sensors.Log; tc.verifyTrue(all(ismember([ins.items.frame_id], L.frame_id)));
            tc.verifyTrue(all(startsWith([ins.items.frame_id], ins.run_id) | contains([ins.items.frame_id], ins.run_id)));
            tc.verifyEqual(src.Stats.binds, 4);
        end

        function b30_missingAndTamperedLog(tc)                               % every failure raises; nothing is substituted
            [src, c, id] = testV2007Bridge.rig(); g = c('ctx'); ins = src.inspect(id); f = ins.items(1).frame_id; base = g.sensor_log; m = base.frame_id == f;
            L = base; L(m, :) = []; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');
            L = base; L.checksum(m) = "tampered"; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');
            L = base; L.tick_id(m) = L.tick_id(m) + 1; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');
            L = base; L.pose_id(m) = L.pose_id(m) + 1; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');
            L = base; L.t_s(m) = L.t_s(m) + 0.05; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');
            L = base; L.sensor_id(m) = "OTHER"; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');
            L = base; L.valid(m) = false; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');
            L = [base; base(m, :)]; tc.verifyError(@() testV2007Bridge.withLog(src, c, g, L, id), 'mgv2:EvidenceMismatch');   % a repeated frame
            c('ctx') = struct('run_id', g.run_id); tc.verifyError(@() src.inspect(id), 'mgv2:EvidenceLogUnavailable');
            c.remove('ctx'); tc.verifyError(@() src.inspect(id), 'mgv2:EvidenceLogUnavailable');   % the provider itself fails
            none = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(); none.bindRun(ses.World, ses.MissionConfig);
            tc.verifyError(@() none.inspect(id), 'mgv2:EvidenceLogUnavailable');   % no provider, no claim of verification
        end

        function b31_tamperedReferenceIsNotListed(tc)                        % listing requires what inspection requires
            d = tc.Src.Detector; E = d.events(); e = E(1);
            x = e; x.evidence_refs(1).t_s = x.evidence_refs(1).t_s + 0.05; [~, r] = mgv2.bridge.toUiEvents(x, d.RunId, d); tc.verifyEqual(r, e.event_id);
            x = e; x.evidence_refs(1).pose_id = x.evidence_refs(1).pose_id + 1; [~, r] = mgv2.bridge.toUiEvents(x, d.RunId, d); tc.verifyEqual(r, e.event_id);
            x = e; x.evidence_refs(1).sensor_id = "OTHER"; [~, r] = mgv2.bridge.toUiEvents(x, d.RunId, d); tc.verifyEqual(r, e.event_id);
            [ok, r] = mgv2.bridge.toUiEvents(e, d.RunId, d); tc.verifyEmpty(r); tc.verifyNumElements(ok, 1);
        end

        function b32_inspectNeverChangesTheRefreshSchedule(tc)               % a click cannot stall or alter a run
            [a, sa] = testV2007Bridge.flown(tc.N, RefreshTicks=20); [b, sb] = testV2007Bridge.flown(0, RefreshTicks=20);
            for k = 1:tc.N
                sb.step();
                if mod(k, 4) == 0
                    ev = sb.view().events;
                    if ~isempty(ev) && mod(k, 40) == 0
                        n = b.Stats.rebuilds; sb.inspect(ev(1).event_id); tc.verifyEqual(b.Stats.rebuilds, n);
                    end
                end
            end
            % The same read pattern without clicks, on the first session's clock
            [c, sc] = testV2007Bridge.flown(0, RefreshTicks=20);
            for k = 1:tc.N, sc.step(); if mod(k, 4) == 0, sc.view(); end, end
            tc.verifyEqual(b.Stats.rebuild_tick, c.Stats.rebuild_tick); tc.verifyEqual(sb.view().events, sc.view().events);
            tc.verifyEqual(a.Detector.events(), b.Detector.events()); tc.verifyEqual(sa.Sensors.Log.checksum, sb.Sensors.Log.checksum);
        end

        function b33_staleIndicatorAndOverdueRead(tc)                        % a slow UI still reads an exact age
            [src, ses] = testV2007Bridge.flown(40, RefreshTicks=20); v = ses.view(); a = src.sourceInfo().events_as_of_tick;
            testV2007Bridge.advance(ses, 19); ses.view(); i = src.sourceInfo();
            tc.verifyEqual(i.events_as_of_tick, a); tc.verifyEqual(i.stale_ticks, 19); tc.verifyEqual(v.overlay_key, a);
            testV2007Bridge.advance(ses, 1); w = ses.view(); i = src.sourceInfo();
            tc.verifyEqual(i.events_as_of_tick, a + 20); tc.verifyEqual(i.stale_ticks, 0); tc.verifyEqual(w.overlay_key, a + 20);
            n = src.Stats.rebuilds; src.suspectedEvents(); src.suspectedEvents(); tc.verifyEqual(src.Stats.rebuilds, n);
            testV2007Bridge.advance(ses, 3); src.suspectedEvents(); src.suspectedEvents();
            tc.verifyEqual(src.Stats.rebuilds, n);                             % repeated requests in flight do not spend the budget
            app = mgv2.ui.MissionControlApp(Visible="off", RealTime=0, MaxTicksPerRun=200, AnomalySource=mgv2.bridge.V2006AnomalySource(RefreshTicks=150));
            c = onCleanup(@() delete(app)); app.AfterRefreshFcn = []; app.command("start"); drawnow;
            tc.verifyEqual(app.Session.view(false).source.stale_ticks, 0);     % held by the budget, so the final read is current
            tc.verifyTrue(contains(string(app.Panels.events.StatusLabel.Text), "as of t=10.0 s"));
            tc.verifyTrue(contains(string(app.Panels.events.StatusLabel.Text), "age 0.0 s"));
        end

        function b34_defaultsAndIntervalsAgree(tc)                           % 20 by default; the interval changes age, never results
            tc.verifyEqual(mgv2.bridge.V2006AnomalySource().RefreshTicks, 100);
            [a, sa] = testV2007Bridge.flown(tc.N, RefreshTicks=20); [b, sb] = testV2007Bridge.flown(tc.N, RefreshTicks=100);
            sa.pauseRun(); sb.pauseRun(); tc.verifyEqual(sa.view().events, sb.view().events);
            tc.verifyEqual(a.Detector.Fingerprint, b.Detector.Fingerprint);
            tc.verifyEqual(sa.Sensors.Log.checksum, sb.Sensors.Log.checksum);
        end

        function b35_noDuplicateSubscriptionAcrossResets(tc)                 % exact counts after repeated rebinding
            [src, ses] = testV2007Bridge.flown(30);
            for k = 1:3, ses.reset(); ses.start(); testV2007Bridge.advance(ses, 30); end
            tc.verifyEqual(src.Stats.binds, 4); tc.verifyEqual(src.Stats.resets, 3);
            tc.verifyEqual(src.Detector.Log.frame_id, ses.Sensors.Log.frame_id);
            tc.verifyEqual(src.Map.Route.tick_id, (0:30)'); tc.verifyEqual(src.Stats.samples_refused, 0);
            tc.verifyEqual(src.Stats.samples, 4 * height(ses.Sensors.Log));
        end

        function b36_contextIsAReadOnlyCopy(tc)                              % public log only; changing a copy changes nothing
            [~, ses] = testV2007Bridge.flown(40); a = ses.evidenceContext(); before = ses.Sensors.Log;
            a.sensor_log.checksum(:) = "x"; a.run_id = "y"; a.generation = 99;
            b = ses.evidenceContext(); tc.verifyEqual(ses.Sensors.Log, before); tc.verifyEqual(b.sensor_log, before);
            tc.verifyEqual(b.run_id, string(ses.MissionConfig.run_id)); tc.verifyEqual(b.generation, 1);
            mgv2.sensors.assertPublic(b, "evidenceContext");
            tc.verifyEqual(sort(string(fieldnames(b)))', sort(["run_id","generation","state","tick","sensor_log"]));
            g = ses.Sensors.Log.Properties.VariableNames; tc.verifyEmpty(intersect(lower(string(g)), ["truth","target","image_rgb_uint8","temperature_k"]));
            ses.reset(); tc.verifyEqual(ses.evidenceContext().generation, 2); tc.verifyEqual(ses.evidenceContext().tick, 0);
        end
        function b37_heldRowWhoseRecordsWereReplaced(tc)                     % same id, current verified record, labelled
            [src, ses] = testV2007Bridge.flown(200, RefreshTicks=100000); ev = ses.view().events; tc.assertNotEmpty(ev); n = src.Stats.rebuilds;
            testV2007Bridge.advance(ses, 600);
            got = false;
            for e = reshape(ev, 1, [])
                try
                    ins = ses.inspect(e.event_id);
                catch err
                    tc.verifyEqual(string(err.identifier), "mgv2:EventNotFound"); continue   % merged away: said so, nothing shown
                end
                tc.verifyEqual(ins.event_id, e.event_id); tc.verifyTrue(all([ins.items.verified_against_sensor_log]));
                if ins.record_basis == "CURRENT"
                    got = true; tc.verifyEqual(ins.stale_ticks, 0); tc.verifyEqual(ins.events_as_of_tick, double(ses.Engine.TickId));
                else
                    tc.verifyEqual(ins.stale_ticks, 600);
                end
            end
            tc.verifyTrue(got); tc.verifyGreaterThan(src.Stats.inspect_current_reads, 0);
            tc.verifyEqual(src.Stats.rebuilds, n);                             % the schedule did not move
        end

        function b38_exactlyOneEvidenceInterface(tc)                         % a merge that keeps two seams fails here, by name
            ui = fileparts(which('mgv2.ui.MissionSession'));
            ses = fileread(fullfile(ui, 'MissionSession.m')); seam = fileread(fullfile(ui, 'AnomalySource.m'));
            tc.verifyNumElements(regexp(ses, 'function\s+\w+\s*=\s*evidenceContext\s*\('), 1);
            tc.verifyNumElements(regexp(seam, 'function\s+bindEvidence\s*\('), 1);
            tc.verifyEmpty(regexp([ses seam], 'bindSensorLog|readSensorLog', 'once'), 'the replaced seam must be gone');
            c = mgv2.ui.MissionSession().evidenceContext();
            tc.verifyEqual(sort(string(fieldnames(c))), sort(["run_id";"generation";"state";"tick";"sensor_log"]));
        end

        function b39_failedBindingAndEndedSession(tc)                        % nothing of a refused run stays; a deleted session frees the source
            base = mgv2.ui.MissionSession(); w = base.World; m = base.MissionConfig;
            ctx = struct('run_id', "OTHER-RUN", 'generation', 1, 'state', "READY", 'tick', 0, 'sensor_log', base.Sensors.Log);
            src = mgv2.bridge.V2006AnomalySource(); src.bindEvidence(@() ctx);
            tc.verifyError(@() src.bindRun(w, m), 'mgv2:BridgeRunMismatch');
            tc.verifyEmpty(src.Detector); tc.verifyEmpty(src.Map); tc.verifyFalse(src.sourceInfo().connected); tc.verifyEmpty(src.suspectedEvents());
            bad = mgv2.bridge.V2006AnomalySource(); bad.bindEvidence(@() struct());
            tc.verifyError(@() bad.bindRun(w, m), 'mgv2:EvidenceLogUnavailable'); tc.verifyEmpty(bad.Detector);
            one = mgv2.bridge.V2006AnomalySource(); a = mgv2.ui.MissionSession(AnomalySource=one);
            tc.verifyError(@() mgv2.ui.MissionSession(AnomalySource=one), 'mgv2:BridgeAlreadyBound');
            first = one.Detector; delete(a);
            tc.verifyError(@() one.inspect("SUS-00001"), 'mgv2:EvidenceLogUnavailable');   % never the old run's records
            b = mgv2.ui.MissionSession(AnomalySource=one);
            tc.verifyNotSameHandle(one.Detector, first); tc.verifyEqual(one.Detector.RunId, string(b.MissionConfig.run_id));
        end

        function b40_rgbAndThermalCropsAreExactlyTheirFrames(tc)             % both modalities, real detector, pixels from the referenced sample
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(AnomalySource=src);
            F = containers.Map('KeyType', 'char', 'ValueType', 'any');
            ses.Sensors.subscribe(@(s) testV2007Bridge.keepFrame(F, s));
            ses.start(); testV2007Bridge.advance(ses, 1000); ses.pauseRun(); ev = ses.view().events; tc.assertNotEmpty(ev);
            n = struct('RGB_NADIR', 0, 'THERMAL_LWIR', 0);
            for e = reshape(ev, 1, [])
                ins = ses.inspect(e.event_id);
                for it = reshape(ins.items, 1, [])
                    tc.assertTrue(isKey(F, char(it.frame_id))); s = F(char(it.frame_id)); o = it.crop_origin_px; [h, w, ~] = size(it.crop);
                    if it.sensor_id == "RGB_NADIR", I = s.image_rgb_uint8; tc.verifyClass(it.crop, 'uint8'); else, I = s.temperature_K; tc.verifyClass(it.crop, 'double'); end
                    tc.verifyEqual(it.crop, I(o(2):o(2)+h-1, o(1):o(1)+w-1, :), it.ref_id);
                    n.(char(it.sensor_id)) = n.(char(it.sensor_id)) + 1;
                end
            end
            tc.verifyGreaterThan(n.RGB_NADIR, 0, 'an RGB record was checked'); tc.verifyGreaterThan(n.THERMAL_LWIR, 0, 'a thermal record was checked');
        end

        function b41_cleanResources(tc)                                      % closing the app leaves no window or timer, and no usable evidence
            f0 = numel(findall(groot, 'Type', 'figure')); t0 = numel(timerfindall);
            src = mgv2.bridge.V2006AnomalySource();
            app = mgv2.ui.MissionControlApp(Visible="off", RealTime=0, MaxTicksPerRun=60, AnomalySource=src);
            app.command("start"); drawnow; ses = app.Session; delete(app); drawnow;
            tc.verifyNumElements(findall(groot, 'Type', 'figure'), f0); tc.verifyNumElements(timerfindall, t0);
            if isvalid(ses), delete(ses); end
            tc.verifyError(@() src.inspect("SUS-00001"), 'mgv2:EvidenceLogUnavailable');
        end

        function b42_sameSeedGivesIdenticalLayersAndAClosedAppFreesTheSource(tc)
            [src, ses] = testV2007Bridge.flown(120); ses.pauseRun(); a = ses.view();
            ses.reset(); ses.start(); testV2007Bridge.advance(ses, 120); ses.pauseRun(); b = ses.view();
            tc.verifyEqual(b.layers, a.layers); tc.verifyEqual(b.events, a.events); delete(ses);
            one = mgv2.bridge.V2006AnomalySource();
            app = mgv2.ui.MissionControlApp(Visible="off", RealTime=0, MaxTicksPerRun=10, AnomalySource=one); delete(app);
            app = mgv2.ui.MissionControlApp(Visible="off", RealTime=0, MaxTicksPerRun=10, AnomalySource=one); c = onCleanup(@() delete(app));
            tc.verifyEqual(one.Detector.RunId, string(app.Session.MissionConfig.run_id)); tc.verifyEqual(src.Stats.resets, 1);
        end

        function b20_validationMemoNeverChangesOutput(tc)                    % issue #76: skipped scan, same result
            d = tc.Src.Detector; E = d.events(); memo = containers.Map('KeyType', 'char', 'ValueType', 'any');
            [a, ra] = mgv2.bridge.toUiEvents(E, d.RunId, d);
            [b, rb] = mgv2.bridge.toUiEvents(E, d.RunId, d, memo);             % first pass fills the memo
            [c, rc] = mgv2.bridge.toUiEvents(E, d.RunId, d, memo);             % second pass uses it
            tc.verifyEqual(b, a); tc.verifyEqual(c, a); tc.verifyEqual(rb, ra); tc.verifyEqual(rc, ra);
            tc.verifyEqual(double(memo.Count), numel(E));
            x = E(1); x.status = "CONFIRMED"; [~, r1] = mgv2.bridge.toUiEvents(x, d.RunId, d, memo);
            tc.verifyEqual(r1, x.event_id);                                    % a changed event is validated again and refused
            y = E(1); y.label_text = "SAFE"; [~, r2] = mgv2.bridge.toUiEvents(y, d.RunId, d, memo);
            tc.verifyEqual(r2, y.event_id);
            [~, r3] = mgv2.bridge.toUiEvents(E(1), "OTHER-RUN", d, memo); tc.verifyEqual(r3, E(1).event_id);   % run check always applies
            z = E(1); z.evidence_refs(1).ref_id = "OBS-99999999"; [~, r4] = mgv2.bridge.toUiEvents(z, d.RunId, d, memo);
            tc.verifyEqual(r4, z.event_id);                                    % evidence check always applies
            q = E(1); q.quality_note = struct('TargetTruth', 1);
            tc.verifyError(@() mgv2.bridge.toUiEvents(q, d.RunId, d, memo), 'mgv2:TruthLeak');   % a leak still throws
        end
    end
end
