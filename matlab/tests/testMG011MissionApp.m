classdef testMG011MissionApp < matlab.uitest.TestCase
    %TESTMG011MISSIONAPP MG-010 acceptance tests UI-01..UI-20 for the MG-011 mission-replay dashboard.
    %   Requires an interactive MATLAB desktop session with a display (the uifigure is really
    %   rendered, and gesture tests use matlab.uitest press()). Run from repo root:
    %     addpath('matlab'); runtests('matlab/tests/testMG011MissionApp.m')
    %   The data come from a REAL MG-004/005/007/009 run (makeMG011DemoBundle). SIMULATION ONLY.

    properties
        RB
        Ctx
    end

    methods (TestClassSetup)
        function setup(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'experiments')));
            [tc.RB, tc.Ctx] = makeMG011DemoBundle();
        end
    end

    methods
        function app = open(tc, rb)
            if nargin < 2, rb = tc.RB; end
            app = mineguard.app.openMissionApp(rb);
            tc.addTeardown(@() app.close());
            drawnow;
        end
        function waitState(tc, app, st, maxS)
            t0 = tic;
            while app.State ~= st && toc(t0) < maxS, pause(0.05); end
            tc.verifyEqual(app.State, st, "timed out waiting for " + st);
        end
        function tf = claims(tc, app)
            % True if any visible text makes a forbidden status claim. Uses whole-word matching, so
            % the disclaimer "not ... field safety" or "clearance" is allowed.
            t = lower(strjoin(tc.allText(app), " "));
            tf = ~isempty(regexp(t, '\<(safe|cleared|all clear|confirmed mine|mine found)\>', 'once'));
        end
        function txt = allText(~, app)
            f = app.figureHandle();
            o = [findall(f, 'Type', 'uilabel'); findall(f, 'Type', 'uitextarea'); findall(f, 'Type', 'uibutton')];
            txt = strings(0, 1);
            for k = 1:numel(o)
                if isprop(o(k), 'Text'), txt = [txt; string(o(k).Text)]; else, txt = [txt; string(o(k).Value)]; end %#ok<AGROW>
            end
            h = app.uiHandles();
            if ~isempty(h.events.Data), c = table2cell(h.events.Data); txt = [txt; reshape(cellfun(@string, c), [], 1)]; end
        end
    end

    methods (Test)
        function ui01_launchRealBundle(tc)
            app = tc.open();
            tc.verifyTrue(isvalid(app.figureHandle())); tc.verifyEqual(string(app.figureHandle().Visible), "on");
            v = app.viewState();
            tc.verifyEqual(v.banner, "SIMULATION — synthetic data; not validated for real landmine detection or clearance.");
            tc.verifyEqual(v.state, "READY"); tc.verifyEqual(v.cursor, 1);
            tc.verifySubstring(string(app.uiHandles().header.Text), "MG009-3001");
            tc.verifyTrue(any(contains(v.provenance_text, "seed: 3001")));
            tc.verifyGreaterThan(height(tc.RB.poses), 500);
        end

        function ui02_strictSchemaAndIdentity(tc)
            id = 'mineguard:InvalidRunBundle'; rb = tc.RB;
            nFig = numel(findall(groot, 'Type', 'figure'));
            bad = {};
            b = rb; b.schema_version = "mg-contract/0.9"; bad{end+1} = b;
            b = rmfield(rb, 'scenario_id'); bad{end+1} = b;
            b = rb; b.poses.pose_sample_id(2) = b.poses.pose_sample_id(1); bad{end+1} = b;
            b = rb; b.poses.t_s(5) = -1; bad{end+1} = b;
            b = rb; b.thermal_samples.pose_sample_id(3) = "P-999999"; bad{end+1} = b;
            b = rb; b.em_samples.t_s(4) = b.em_samples.t_s(4) + 0.5; bad{end+1} = b;
            b = rb; b.provenance.scenario_id = "OTHER"; bad{end+1} = b;
            b = rb; b.geometry.scenario_id = "OTHER"; bad{end+1} = b;
            b = rb; b.thermal_samples.temperature_K(1) = NaN; b.thermal_samples.valid(1) = true; bad{end+1} = b;
            if height(rb.events) > 0
                b = rb; b.events.status(1) = "CONFIRMED MINE"; bad{end+1} = b;
                b = rb; b.events.em_sample_id(1) = "EM-999999"; bad{end+1} = b;
            end
            for k = 1:numel(bad)
                tc.verifyError(@() mineguard.app.openMissionApp(bad{k}), id, sprintf('case %d', k));
            end
            try
                mineguard.app.openMissionApp(bad{1});
            catch e
                tc.verifySubstring(e.message, 'Invalid run bundle');
            end
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), nFig, 'no UI is created for invalid input');
        end

        function ui03_privacyFirewall(tc)
            id = 'mineguard:InvalidRunBundle'; rb = tc.RB;
            truthT = table("OBJ-0001", 1, 1, 0.1, "synthetic_metal_cased_surrogate", categorical("target"), ...
                'VariableNames', {'target_id','x_east_m','y_north_m','burial_depth_m','material_type','label'});
            b = rb; b.hidden_truth = truthT;                                      tc.verifyError(@() mineguard.app.openMissionApp(b), id);
            b = rb; b.provenance.extra = struct('label', "target");               tc.verifyError(@() mineguard.app.openMissionApp(b), id);
            b = rb; b.geometry.terrain_model.meta = {struct('burial_depth_m', 0.1)}; tc.verifyError(@() mineguard.app.openMissionApp(b), id);
            b = rb; b.result_report.pairs = truthT;                               tc.verifyError(@() mineguard.app.openMissionApp(b), id);
            b = rb; b.display_settings.t = {truthT};                              tc.verifyError(@() mineguard.app.openMissionApp(b), id);
            b = rb; b.poses.label = repmat("target", height(b.poses), 1);         tc.verifyError(@() mineguard.app.openMissionApp(b), id);
            b = rb; b.events = truthT;                                            tc.verifyError(@() mineguard.app.openMissionApp(b), id);
            tc.verifyError(@() mineguard.app.makeRunBundle(struct('scenario_id', "X", 'private', struct()), rb.events, struct('provenance', rb.provenance)), id);
            tc.verifyFalse(isfield(rb, 'result_report') && isfield(rb.result_report, 'match_pairs_event_target_dist'), 'evaluator match pairs dropped');
            files = dir(fullfile(fileparts(which('mineguard.app.openMissionApp')), '*.m'));
            for k = 1:numel(files)
                code = strjoin(regexprep(splitlines(string(fileread(fullfile(files(k).folder, files(k).name)))), '%.*$', ''), newline);
                tc.verifyFalse(contains(code, ["hidden_truth","TargetTruth","burial_depth_m","scoreDetections","generateScenario","detectAnomalies"]), files(k).name);
            end
            txt = jsonencode(struct('p', rb.poses, 't', rb.thermal_samples, 'e', rb.em_samples, 'v', rb.events, 'g', rb.geometry, 'pr', rb.provenance));
            tc.verifyFalse(contains(txt, ["OBJ-","synthetic_metal","synthetic_plastic","""label"""]), 'no truth in any bundle stream');
        end

        function ui04_replayStateMachineGestures(tc)
            app = tc.open(); h = app.uiHandles();
            tc.verifyEqual([string(h.play.Enable) string(h.pause.Enable)], ["on" "off"]);
            tc.press(h.play);   tc.verifyEqual(app.State, "RUNNING"); tc.verifyEqual(string(h.pause.Enable), "on");
            pause(0.6);
            tc.press(h.pause);  tc.verifyEqual(app.State, "PAUSED");
            c1 = app.Cursor; tc.verifyGreaterThan(c1, 1);
            pause(0.4); tc.verifyEqual(app.Cursor, c1, 'paused cursor must not drift');
            tc.press(h.play); pause(0.3); tc.press(h.pause); tc.verifyGreaterThanOrEqual(app.Cursor, c1, 'resume from saved cursor');
            c2 = app.Cursor;
            tc.press(h.step);   tc.verifyEqual(app.Cursor, c2 + 1); tc.verifyEqual(app.State, "PAUSED");
            tc.press(h.reset);  tc.verifyEqual(app.State, "READY"); tc.verifyEqual(app.Cursor, 1);
            app.setSpeed(20); app.play(); tc.waitState(app, "COMPLETE", 90);
            tc.verifyEqual(app.Cursor, height(tc.RB.poses));
            tc.verifyEqual(string(h.play.Enable), "off"); tc.verifyEqual(string(h.step.Enable), "off");
            app.reset(); tc.verifyEqual(app.State, "READY");
        end

        function ui05_backwardSeekDeterministic(tc)
            app = tc.open(); T = tc.RB.poses.t_s;
            app.seek(T(end)); vEnd = app.viewState();
            tmid = T(round(numel(T) / 2)); app.seek(tmid); vMid = app.viewState();
            E = tc.RB.events;
            tc.verifyEqual(sort(vMid.visible_event_ids(:)), sort(E.event_id(E.t_s <= tmid)));
            tc.verifyEqual(vMid.trace_points, find(T <= tmid, 1, 'last'));
            tc.verifyLessThanOrEqual(max([app.uiHandles().thLine.XData NaN]), tmid);
            app.seek(T(end)); vEnd2 = app.viewState();
            tc.verifyEqual(rmfield(vEnd2, 'status'), rmfield(vEnd, 'status'));
            app.seek(NaN); tc.verifyEqual(app.Cursor, numel(T), 'invalid seek ignored');
        end

        function ui06_mapAndCoverage(tc)
            app = tc.open(); h = app.uiHandles(); rb = tc.RB;
            tc.verifyEqual(string(h.map.XLabel.String), "x east [m]"); tc.verifyEqual(string(h.map.YLabel.String), "y north [m]");
            tc.verifyEqual(h.map.DataAspectRatio, [1 1 1]);
            app.seek(rb.poses.t_s(end));
            tc.verifyEqual(h.trace.XData(:), rb.poses.x_east_m); tc.verifyEqual(h.trace.YData(:), rb.poses.y_north_m);
            tc.verifyEqual(numel(findobj(h.map, 'Type', 'patch')), numel(rb.geometry.exclusion_polygons_enu_m));
            rl = findobj(h.map, 'DisplayName', 'planned waypoints');
            tc.verifyEqual([rl.XData(:) rl.YData(:)], rb.route_enu_m(:, 1:2));
            v = app.viewState();
            tc.verifyEqual(v.visited_cells, rb.coverage.visited_valid_cells, 'visited cells = MG-005 computeCoverage');
            tc.verifyTrue(any(contains(v.telemetry, sprintf('%.3f', rb.coverage.coverage_fraction))));
            tc.verifyTrue(any(contains(v.telemetry, "z_up (datum)")));
        end

        function ui07_virtualGps(tc)
            app = tc.open();
            tc.verifyTrue(any(contains(app.viewState().telemetry, "Virtual GPS unavailable")));
            nav1 = mineguard.navigation.navigationConfigFromExperiment(tc.Ctx.config, 'virtual_origin_lat_deg', 12.97, 'virtual_origin_lon_deg', 77.59);
            p1 = mineguard.navigation.simulatePose(nav1, tc.Ctx.geometry, tc.Ctx.route);
            rb = tc.RB; tc.assertEqual(p1.pose_sample_id, rb.poses.pose_sample_id); tc.assertEqual(p1.t_s, rb.poses.t_s);
            rb.poses.virtual_lat_deg = p1.virtual_lat_deg; rb.poses.virtual_lon_deg = p1.virtual_lon_deg; rb.poses.gps_sigma_m = p1.gps_sigma_m;
            app2 = tc.open(rb);
            tel = app2.viewState().telemetry;
            tc.verifyTrue(any(contains(tel, "VIRTUAL geotag")) && any(contains(tel, "(synthetic)")));
            tc.verifyFalse(any(contains(lower(tel), "gps fix")));
        end

        function ui08_sensorUnits(tc)
            app = tc.open(); app.seek(tc.RB.poses.t_s(end)); h = app.uiHandles(); v = app.viewState();
            tc.verifySubstring(v.thermal_ylabel, "[K]"); tc.verifySubstring(v.em_ylabel, "normalized");
            tc.verifyNotSameHandle(h.thLine.Parent, h.emLine.Parent);
            tc.verifyGreaterThan(min(h.thLine.YData), 250); tc.verifyLessThan(max(h.emLine.YData), 5);
            tc.verifyFalse(any(contains(tc.allText(app), ["°C","degC"])));
        end

        function ui09_invalidReadingsShownAsGaps(tc)
            rb = makeMG011DemoBundle(struct('seed', 3002, 'x_max_m', 4, 'y_max_m', 4, 'dropout_probability', 0.3));
            app = tc.open(rb); app.seek(rb.poses.t_s(end)); h = app.uiHandles();
            bad = ~rb.thermal_samples.valid; tc.assertGreaterThan(nnz(bad), 0);
            tc.verifyTrue(all(isnan(h.thLine.YData(bad))), 'invalid -> NaN gap'); tc.verifyFalse(any(h.thLine.YData(bad) == 0));
            tc.verifyEqual(numel(h.thBad.XData), nnz(bad));
            tc.verifySubstring(string(h.axT.Subtitle.String), "DROPPED_SAMPLE");
            rb2 = makeMG011DemoBundle(struct('seed', 3002, 'x_max_m', 4, 'y_max_m', 4, 'altitude_m', 5));
            app2 = tc.open(rb2); app2.seek(rb2.poses.t_s(end)); h2 = app2.uiHandles();
            tc.verifyTrue(all(isnan(h2.emLine.YData))); tc.verifySubstring(string(h2.axE.Subtitle.String), "MODEL_OUT_OF_DOMAIN");
        end

        function ui10_suspectedEventsOnly(tc)
            rb = tc.RB; tc.assumeGreaterThan(height(rb.events), 0, 'fixture must contain events');
            app = tc.open(); app.seek(rb.poses.t_s(end)); h = app.uiHandles();
            tc.verifyEqual(sort(h.ev.XData(:)), sort(rb.events.x_est_m)); tc.verifyEqual(sort(h.ev.YData(:)), sort(rb.events.y_est_m));
            d = h.events.Data; tc.verifyEqual(height(d), height(rb.events));
            tc.verifyTrue(all(string(d{:, 5}) == "SUSPECTED"));
            tc.verifyFalse(tc.claims(app), 'no SAFE / CLEARED / CONFIRMED MINE claims');
        end

        function ui11_emptyEventsAndEmptyRun(tc)
            rb = tc.RB; rb.events = rb.events([], :);
            app = tc.open(rb); app.seek(rb.poses.t_s(end));
            tc.verifyEqual(app.viewState().events_text, "No suspected events in this simulated run.");
            tc.verifyEqual(height(app.uiHandles().events.Data), 0);
            tc.verifyFalse(tc.claims(app), 'no "safe"/"cleared"/"all clear" wording for an empty event list');
            e = tc.RB; e.poses = e.poses([], :); e.thermal_samples = e.thermal_samples([], :); e.em_samples = e.em_samples([], :); e.events = e.events([], :);
            e = rmfield(e, {'result','result_report','coverage'});
            app2 = tc.open(e); v = app2.viewState();
            tc.verifyEqual(v.state, "READY"); tc.verifySubstring(v.status, "EMPTY");
            tc.verifyEqual([v.play_enabled v.step_enabled v.seek_enabled], ["off" "off" "off"]);
            app2.play(); tc.verifyEqual(app2.State, "READY");
        end

        function ui12_missingAndUndefinedMetrics(tc)
            rb = rmfield(tc.RB, {'result','result_report'});
            app = tc.open(rb); ev = string(app.uiHandles().eval.Value);
            tc.verifyTrue(any(contains(ev, "Evaluation: NOT RUN")));
            rb2 = tc.RB; rb2.result.precision = NaN; rb2.result.f1 = NaN; rb2.result.false_alarm_rate = NaN;
            app2 = tc.open(rb2); ev2 = string(app2.uiHandles().eval.Value);
            tc.verifyTrue(any(contains(ev2, "precision: Undefined (zero denominator)")));
            tc.verifyTrue(any(contains(ev2, "Localization (separate")));
            tc.verifyTrue(any(contains(ev2, "cell-level")));
        end

        function ui13_scoreNotProbability(tc)
            rb = tc.RB; tc.assumeGreaterThan(height(rb.events), 0);
            app = tc.open(); app.seek(rb.poses.t_s(end));
            tc.verifyTrue(all(string(app.uiHandles().events.Data{:, 6}) == "Uncalibrated / unavailable"));
            rb.events.confidence_0_1(1) = 0.7;
            app2 = tc.open(rb); app2.seek(rb.poses.t_s(end)); d = string(app2.uiHandles().events.Data{:, 6});
            tc.verifyTrue(any(d == "Model score 0.700")); tc.verifyFalse(any(contains(lower(tc.allText(app2)), "probability")));
        end

        function ui14_comparisonFeatureGate(tc)
            app = tc.open(); ev = string(app.uiHandles().eval.Value);
            tc.verifyTrue(any(contains(ev, "PPO comparison: NOT RUN"))); tc.verifyTrue(any(contains(ev, "Method comparison: NOT RUN.")));
            tc.verifyTrue(any(contains(string(app.uiHandles().meta.Value), "3-D view: NOT AVAILABLE")));
        end

        function ui15_exportReadBack(tc)
            app = tc.open(); app.seek(tc.RB.poses.t_s(round(end / 2)));
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            tc.verifyTrue(app.exportRun(d)); X = app.LastExport;
            tc.verifyEqual(numel(dir(fullfile(X.folder, '*.*'))) - 2, 7);
            rb = tc.RB; nm = ["poses","thermal_samples","em_samples","events"];
            for k = 1:4
                T = readtable(fullfile(X.folder, nm(k) + ".csv"), 'TextType', 'string');
                if height(rb.(nm(k))) > 0, tc.verifyEqual(height(T), height(rb.(nm(k)))); end
                tc.verifyEqual(string(T.Properties.VariableNames), string(rb.(nm(k)).Properties.VariableNames));
            end
            m = load(fullfile(X.folder, 'run_bundle_redacted.mat')); tc.verifyTrue(isequaln(m.runBundle, rb));
            js = jsondecode(fileread(fullfile(X.folder, 'summary.json')));
            tc.verifyEqual(string(js.provenance.git_sha), string(rb.provenance.git_sha)); tc.verifyEqual(js.provenance.seed, 3001);
            tc.verifySubstring(string(js.banner), "SIMULATION"); tc.verifySubstring(string(js.export_created_utc), "Z");
            img = imread(fullfile(X.folder, 'snapshot.png')); tc.verifyGreaterThan(size(img, 1), 300);
            allTxt = strjoin(arrayfun(@(f) string(fileread(fullfile(X.folder, f.name))), dir(fullfile(X.folder, '*.csv')))', newline) + fileread(fullfile(X.folder, 'summary.json'));
            tc.verifyFalse(contains(allTxt, ["OBJ-","synthetic_metal","synthetic_plastic","burial_depth"]), 'no truth in export');
        end

        function ui16_exportFailureAndCancel(tc)
            app = tc.open();
            nope = fullfile(tempdir, "does_not_exist_" + string(randi(1e9)));
            tc.verifyFalse(app.exportRun(nope)); tc.verifySubstring(app.StatusText, "FAILED"); tc.verifyFalse(isfolder(nope));
            tc.verifyEmpty(dir(fullfile(tempdir, 'MG011-export-*-partial')), 'no partial temp export left');
            tc.verifyFalse(app.exportRun(0)); tc.verifySubstring(app.StatusText, "cancelled");
            tc.verifyFalse(app.exportRun("")); tc.verifySubstring(app.StatusText, "cancelled");
            app.step(); tc.verifyEqual(app.Cursor, 2, 'app remains interactive');
        end

        function ui17_longReplayResponsiveness(tc)
            rb = makeMG011DemoBundle(struct('seed', 3003, 'x_max_m', 20, 'y_max_m', 20));
            n = height(rb.poses); tc.log(1, sprintf('UI-17 long replay rows: %d poses, %d thermal, %d em, %d events', ...
                n, height(rb.thermal_samples), height(rb.em_samples), height(rb.events)));
            app = tc.open(rb); app.setSpeed(20); t0 = tic; app.play(); pause(1.5);
            tp = tic; app.pause(); pauseLatency = toc(tp);
            tc.verifyEqual(app.State, "PAUSED"); c = app.Cursor; pause(0.3); tc.verifyEqual(app.Cursor, c);
            app.play(); tc.waitState(app, "COMPLETE", 300); wall = toc(t0);
            td = app.TickDurations;
            tc.log(1, sprintf('UI-17 ticks %d, render median %.4f s, p95 %.4f s, max %.4f s; pause latency %.4f s; wall %.1f s', ...
                numel(td), median(td), prctile(td, 95), max(td), pauseLatency, wall));
            v = app.viewState();
            tc.verifyEqual(v.trace_points, n); tc.verifyEqual(v.visible_thermal, nnz(rb.thermal_samples.valid));
            tc.verifyEqual(v.visible_em, nnz(rb.em_samples.valid)); tc.verifyEqual(numel(v.visible_event_ids), height(rb.events));
            tc.verifyLessThan(pauseLatency, 1.0); tc.verifyLessThan(median(td), 0.5);
            assignin('base', 'MG011_UI17', struct('rows', n, 'ticks', numel(td), 'median', median(td), 'p95', prctile(td, 95), ...
                'max', max(td), 'pause_latency', pauseLatency, 'wall', wall));
        end

        function ui18_lifecycle(tc)
            before = numel(timerfindall('Tag', 'MineGuardMissionAppTimer'));
            app = mineguard.app.openMissionApp(tc.RB); app.play(); pause(0.3);
            f = app.figureHandle(); close(f);                      % user closes the window
            tc.verifyEqual(app.State, "CLOSED"); tc.verifyFalse(isvalid(f));
            tc.verifyEqual(numel(timerfindall('Tag', 'MineGuardMissionAppTimer')), before, 'no residual timer');
            app.play(); tc.verifyEqual(app.State, "CLOSED", 'no callbacks after close');
            app2 = mineguard.app.openMissionApp(tc.RB); app2.play(); pause(0.2); app2.reset(); app2.close();
            tc.verifyEqual(numel(timerfindall('Tag', 'MineGuardMissionAppTimer')), before);
            tc.log(1, sprintf('UI-18 platform: %s, MATLAB %s (macOS NOT TESTED)', computer, version('-release')));
        end

        function ui19_simulatedOnlyControls(tc)
            app = tc.open(); h = app.uiHandles();
            tc.verifyEqual(string(h.play.Text), "Play Simulation");
            tc.verifyEmpty(regexp(lower(strjoin(tc.allText(app), " ")), '\<(arm|disarm|takeoff|take off|start mission|rc link)\>', 'once'));
            files = dir(fullfile(fileparts(which('mineguard.app.openMissionApp')), '*.m'));
            code = strjoin(arrayfun(@(f) string(fileread(fullfile(f.folder, f.name))), files)', newline);
            tc.verifyFalse(contains(code, ["serialport","udpport","tcpclient","tcpserver","webread","webwrite","websave", ...
                "mavlink","arduino","rosinit","ros2node","bluetooth"]), 'no hardware / telemetry / network I/O');
        end

        function ui20_deterministicReplayAndProvenance(tc)
            a1 = tc.open(); a2 = tc.open(); t = tc.RB.poses.t_s(round(end * 0.7));
            a1.seek(t); a2.seek(t);
            tc.verifyEqual(a1.viewState(), a2.viewState());
            pt = a1.viewState().provenance_text;
            tc.verifyTrue(any(contains(pt, string(tc.RB.provenance.git_sha)))); tc.verifyTrue(any(contains(pt, "split: test")));
            rb = tc.RB; p = rmfield(rb.provenance, 'run_id');
            pub = struct('scenario_id', rb.scenario_id, 'geometry', rb.geometry, 'poses', rb.poses, 'samples', [rb.thermal_samples; rb.em_samples]);
            rb2 = mineguard.app.makeRunBundle(pub, rb.events, struct('provenance', p));
            tc.verifyEqual(rb2.provenance.run_id, "NOT_RECORDED");
            a3 = tc.open(rb2); tc.verifyTrue(any(contains(a3.viewState().provenance_text, "run_id: NOT_RECORDED")));
        end
    end
end
