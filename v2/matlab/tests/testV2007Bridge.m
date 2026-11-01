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
            ses = mgv2.ui.MissionSession(AnomalySource=src); src.bindSession(ses); ses.start();
            testV2007Bridge.advance(ses, n);
        end
        function advance(ses, n)
            for k = 1:n, if ~ses.step(), break; end, end
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
            tc.verifyEqual(src.Stats.pose_subscriptions, 1);
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
            tc.verifyEqual(src.Stats.pose_subscriptions, 2);                  % one per engine, none duplicated
            tc.verifyEqual(numel(src.Map.Route.t_s), 201);                    % poses of the new run only
            [src3, ~] = testV2007Bridge.flown(200); tc.verifyEqual(src3.Detector.events(), E1);
        end

        function b08_bindingRules(tc)
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(AnomalySource=src);
            other = mgv2.bridge.V2006AnomalySource();
            tc.verifyError(@() other.bindSession(ses), 'mgv2:BridgeWrongSession');
            src.bindSession(ses);
            tc.verifyError(@() src.bindSession(ses), 'mgv2:BridgeAlreadyBound');
            late = mgv2.bridge.V2006AnomalySource(); s2 = mgv2.ui.MissionSession(AnomalySource=late); s2.start(); s2.step();
            tc.verifyError(@() late.bindSession(s2), 'mgv2:BridgeLateBind');
            tc.verifyEqual(src.Map.Route.x(1), ses.Engine.snapshot().position_enu_m(1));   % the session's own engine
            tc.verifyEqual(src.Detector.RunId, string(ses.MissionConfig.run_id));
            tc.verifyEqual(height(src.Detector.Log), height(ses.Sensors.Log));   % held tick-0 samples were replayed
        end

        function b09_unboundFailsClosed(tc)                                  % never invents output
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(AnomalySource=src);
            v = ses.view();
            tc.verifyFalse(v.source.connected); tc.verifyEmpty(v.events); tc.verifyEmpty(v.layers);
            tc.verifyEqual(v.source.status_text, "DETECTOR BRIDGE NOT BOUND");
            tc.verifyError(@() src.inspect("SUS-00001"), 'mgv2:BridgeNotBound');
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
            src = mgv2.bridge.V2006AnomalySource(); ses = mgv2.ui.MissionSession(SensorConfig=cfg, AnomalySource=src); src.bindSession(ses); ses.start();
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
            tc.verifyError(@() tc.Src.inspect(e.event_id, SensorLog=Lb), 'mgv2:EvidenceMismatch');
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
            c = onCleanup(@() delete(app)); src.bindSession(app.Session);
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
    end
end
