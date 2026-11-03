classdef testV2008ExportReplay < matlab.uitest.TestCase
    %TESTV2008EXPORTREPLAY Run package export, verification, replay, reproduction and fault cases (V2-008). SIMULATED.
    %   From the repository root:  addpath('v2/matlab'); runtests('v2/matlab/tests/testV2008ExportReplay.m')
    %   The class flies one full nominal mission with the real V2-006 bridge and exports it once; most tests read that
    %   package or a tampered copy. The last tests open the real dashboard and press its buttons (needs a desktop).

    properties (SetAccess = private)
        Root            % class-wide temporary export folder
        Folder          % the nominal package
        Ses             % the session that produced it
    end
    properties
        App
    end

    methods (TestClassSetup)
        function exportNominal(tc)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(here)));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(here));
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); tc.Root = string(f.Folder);
            ses = mgv2.ui.MissionSession(AnomalySource=mgv2.bridge.V2006AnomalySource());
            ses.start(); while ses.step(), end
            tc.assertEqual(ses.Engine.Phase, "COMPLETE");
            tc.Folder = ses.exportRun(tc.Root); tc.Ses = ses;
        end
    end

    methods (TestMethodTeardown)
        function closeApp(tc)
            if ~isempty(tc.App) && isvalid(tc.App), delete(tc.App); end
            tc.App = [];
        end
    end

    methods (Access = private)
        function d = copyPackage(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            [~, n] = fileparts(tc.Folder); d = string(fullfile(f.Folder, n)); copyfile(tc.Folder, d);
        end
        function resum(~, d)
            files = mgv2.run.listFiles(d); lines = strings(numel(files), 1);
            for k = 1:numel(files), lines(k) = mgv2.run.fileSha256(fullfile(d, files(k))) + "  " + files(k); end
            fid = fopen(fullfile(d, "files.sha256"), 'w'); fwrite(fid, char(strjoin(lines, newline) + newline)); fclose(fid);
        end
        function ses = flyHeadless(~, scenario, maxTicks)
            ses = mgv2.ui.MissionSession(); if scenario ~= "As launched", ses.configure(scenario, ses.MissionConfig.seed); end
            ses.start(); n = 0; while n < maxTicks && ses.step(), n = n + 1; end
        end
    end

    methods (Test)
        function exportReadsBackIdentically(tc)
            pkg = mgv2.run.verifyPackage(tc.Folder); s = tc.Ses;
            tc.verifyTrue(isequaln(pkg.poses, s.Engine.poseLog()), 'every pose row');
            for id = mgv2.sensors.SensorSystem.Order
                live = s.Recorder.samples(id); got = pkg.samples.(id);
                tc.verifyEqual(numel(got), numel(live), char(id));
                tc.verifyTrue(isequaln(got, live), char(id) + " samples read back bit for bit");
            end
            tc.verifyTrue(isequaln(pkg.event_list, s.view().events), 'events');
            tc.verifyGreaterThan(numel(pkg.event_list), 0, 'the nominal run lists SUSPECTED events');
            m = pkg.manifest;
            tc.verifyTrue(m.simulation_only); tc.verifyEqual(m.synthetic_targets_in_scene, 0);
            tc.verifySubstring(string(m.notice), "SUSPECTED"); tc.verifyEqual(string(m.end_state.phase), "COMPLETE");
            tc.verifyEqual(m.counts.poses, height(s.Engine.poseLog()));
            tc.verifyEqual(numel(pkg.evidence), numel(pkg.event_list), 'one evidence entry per event');
            tc.verifyTrue(all(cellfun(@(e) strlength(e.error) == 0, pkg.evidence)), 'every listed event has verified evidence');
            tc.verifyEqual(string(m.world_digest), mgv2.run.digest(mgv2.scene.buildWorld()));
        end

        function packageHoldsNoTruthOrPrivateScene(tc)
            pkg = mgv2.run.verifyPackage(tc.Folder);
            mgv2.sensors.assertPublic(pkg, "package");
            txt = lower(string(fileread(fullfile(tc.Folder, "manifest.json"))) + string(fileread(fullfile(tc.Folder, "events", "events.json"))) ...
                + string(fileread(fullfile(tc.Folder, "config", "run_config.json"))));
            for bad = mgv2.sensors.contract().forbidden, tc.verifyFalse(contains(txt, """" + bad + """"), bad); end
            tc.verifyFalse(contains(txt, "radiometry") || contains(txt, "surface_features"));
        end

        function reproductionMatchesBitForBit(tc)
            r = mgv2.run.reproduce(mgv2.run.verifyPackage(tc.Folder));
            tc.verifyTrue(r.world_equal); tc.verifyTrue(r.poses_equal); tc.verifyTrue(r.end_equal);
            tc.verifyEqual(r.samples_equal, r.samples_compared, "first mismatch " + r.first_mismatch);
            tc.verifyTrue(r.match);
        end

        function replayShowsTheRecordingWithoutSimulating(tc)
            ses = mgv2.ui.MissionSession(AnomalySource=mgv2.bridge.V2006AnomalySource());
            ses.loadReplay(tc.Folder);
            tc.verifyEqual(ses.Mode, "REPLAY"); tc.verifyClass(ses.Engine, 'mgv2.replay.PlaybackEngine');
            tc.verifyClass(ses.Sensors, 'mgv2.replay.PlaybackSensors'); tc.verifyEmpty(ses.Recorder);
            tc.verifyEqual(ses.view().mode, "REPLAY");
            ses.start(); while ses.step(), end
            tc.verifyEqual(ses.state(), "ENDED"); tc.verifyEqual(ses.Engine.Phase, "COMPLETE");
            P = tc.Ses.Engine.poseLog(); tc.verifyTrue(isequaln(ses.Engine.poseLog(), P), 'same poses');
            tc.verifyEqual(ses.Sensors.Log.frame_id, tc.Ses.Sensors.Log.frame_id, 'same samples, same order');
            tc.verifyEqual(ses.Sensors.Log.checksum, tc.Ses.Sensors.Log.checksum);
            tc.verifyEqual(ses.Sensors.Log.t_s, tc.Ses.Sensors.Log.t_s);
            r = ses.replayCheck(); tc.verifyTrue(r.done); tc.verifyTrue(r.match, r.detail);
            ev = ses.view().events; ins = ses.inspectCurrentRun(ev(1).event_id);
            tc.verifyNotEmpty(ins.items, 'evidence is inspectable in the replay');
            tc.verifyError(@() ses.exportRun(tc.Root), 'mgv2:ExportFailed');
        end

        function replayPauseResumeAndAbortControlTheReplayOnly(tc)
            ses = mgv2.ui.MissionSession(); ses.loadReplay(tc.Folder); ses.start();
            for k = 1:50, ses.step(); end
            ses.pauseRun(); tc.verifyFalse(ses.step()); tc.verifyEqual(ses.Engine.TickId, 50);
            ses.resumeRun(); tc.verifyTrue(ses.step()); tc.verifyEqual(ses.Engine.TickId, 51);
            ses.abortRun(); tc.verifyEqual(ses.state(), "ENDED"); tc.verifyEqual(ses.Engine.Phase, "ABORTED");
            ses.reset(); tc.verifyEqual(ses.state(), "READY"); tc.verifyEqual(ses.Mode, "REPLAY"); tc.verifyEqual(ses.Engine.TickId, 0);
            mgv2.run.verifyPackage(tc.Folder);              % the recording is unchanged
            ses.configure("As launched", ses.MissionConfig.seed); tc.verifyEqual(ses.Mode, "LIVE");
            tc.verifyClass(ses.Engine, 'mgv2.engine.MissionEngine');
        end

        function changedFileIsRefused(tc)
            d = tc.copyPackage(); f = fullfile(d, "samples", "RGB_NADIR.mat");
            b = fileread(f); fid = fopen(f, 'r+'); fseek(fid, 2000, 'bof'); x = fread(fid, 1, '*uint8'); fseek(fid, 2000, 'bof');
            fwrite(fid, bitxor(x, uint8(1))); fclose(fid); tc.assumeNotEmpty(b);
            tc.verifyError(@() mgv2.run.verifyPackage(d), 'mgv2:PackageTampered');
        end

        function missingAndExtraFilesAreRefused(tc)
            d = tc.copyPackage(); delete(fullfile(d, "telemetry", "phases.csv"));
            tc.verifyError(@() mgv2.run.verifyPackage(d), 'mgv2:PackageTampered');
            d = tc.copyPackage(); fid = fopen(fullfile(d, "events", "extra.json"), 'w'); fwrite(fid, '{}'); fclose(fid);
            tc.verifyError(@() mgv2.run.verifyPackage(d), 'mgv2:PackageTampered');
            d = tc.copyPackage(); delete(fullfile(d, "files.sha256"));
            tc.verifyError(@() mgv2.run.verifyPackage(d), 'mgv2:PackageTampered');
        end

        function editedSampleWithRecomputedFileHashesIsStillRefused(tc)
            d = tc.copyPackage(); f = fullfile(d, "samples", "THERMAL_LWIR.mat"); S = load(f);
            k = find(cellfun(@(s) s.valid, S.samples), 1); S.samples{k}.temperature_K(1) = S.samples{k}.temperature_K(1) + 0.5;
            save(f, '-struct', 'S'); tc.resum(d);
            tc.verifyError(@() mgv2.run.verifyPackage(d), 'mgv2:PackageTampered');
        end

        function editedManifestCountsAreRefused(tc)
            d = tc.copyPackage(); f = fullfile(d, "manifest.json"); m = jsondecode(fileread(f)); m.counts.poses = m.counts.poses + 1;
            fid = fopen(f, 'w'); fwrite(fid, jsonencode(m)); fclose(fid); tc.resum(d);
            tc.verifyError(@() mgv2.run.verifyPackage(d), 'mgv2:PackageInvalid');
        end

        function injectedTruthIsRefused(tc)
            d = tc.copyPackage(); f = fullfile(d, "events", "evidence.mat"); V = load(f);
            V.evidence{1}.target_id = 7; save(f, '-struct', 'V'); tc.resum(d);
            tc.verifyError(@() mgv2.run.verifyPackage(d), 'mgv2:TruthLeak');
        end

        function aRefusedReplayLeavesTheSessionAsItWas(tc)
            d = tc.copyPackage(); delete(fullfile(d, "telemetry", "poses.mat"));
            ses = mgv2.ui.MissionSession(); ses.start(); for k = 1:30, ses.step(); end; ses.pauseRun();
            before = ses.Engine.TickId; eng = ses.Engine;
            tc.verifyError(@() ses.loadReplay(d), 'mgv2:PackageTampered');
            tc.verifyEqual(ses.Mode, "LIVE"); tc.verifySameHandle(ses.Engine, eng); tc.verifyEqual(ses.Engine.TickId, before);
            ses.resumeRun(); tc.verifyError(@() ses.loadReplay(tc.Folder), 'mgv2:InvalidCommand', 'no replay while a run is active');
        end

        function exportIsRefusedUntilTheRunEnds(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            ses = tc.flyHeadless("As launched", 40); ses.pauseRun();
            tc.verifyError(@() ses.exportRun(f.Folder), 'mgv2:ExportFailed');
            tc.verifyEmpty(dir(fullfile(f.Folder, '*_g*')), 'nothing written');
        end

        function aFailedExportLeavesNoPartialPackage(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            ses = tc.flyHeadless("As launched", 40); ses.abortRun(); in = ses.packageInputs();
            in.samples.LIDAR_TERRAIN(end) = [];            % one logged sample missing from the recording
            tc.verifyError(@() mgv2.run.exportRun(in, f.Folder), 'mgv2:ExportFailed');
            d = dir(f.Folder); tc.verifyEqual(sort(string({d.name})), [".", ".."], 'no package and no partial folder');
        end

        function anExistingPackageIsNeverOverwritten(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            ses = tc.flyHeadless("As launched", 40); ses.abortRun(); in = ses.packageInputs();
            t = datetime('now', 'TimeZone', 'UTC');
            for s = 0:3                                    % occupy this and the next seconds' names
                n = sprintf('%s_g%d_%s', in.mission.run_id, in.generation, char(t + seconds(s), 'yyyyMMdd''T''HHmmss''Z'''));
                mkdir(fullfile(f.Folder, n)); fid = fopen(fullfile(f.Folder, n, 'keep.txt'), 'w'); fwrite(fid, 'x'); fclose(fid);
            end
            tc.verifyError(@() mgv2.run.exportRun(in, f.Folder), 'mgv2:ExportFailed');
            tc.verifyEqual(numel(dir(fullfile(f.Folder, '*', 'keep.txt'))), 4, 'existing folders untouched');
        end

        function abortedRunExportsReplaysAndReproduces(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            ses = tc.flyHeadless("As launched", 300); ses.abortRun(); folder = ses.exportRun(f.Folder);
            pkg = mgv2.run.verifyPackage(folder); tc.verifyEqual(string(pkg.manifest.end_state.fault_code), "ABORTED_BY_OPERATOR");
            tc.verifyTrue(mgv2.run.reproduce(pkg).match);
            r = mgv2.ui.MissionSession(); r.loadReplay(folder); r.start(); while r.step(), end
            tc.verifyEqual(r.Engine.Phase, "ABORTED"); tc.verifyEqual(r.Engine.TickId, 300);
            tc.verifyEqual(r.pose().fault_code, "ABORTED_BY_OPERATOR");
        end

        function missionFaultIsReportedAndReplayed(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            ses = tc.flyHeadless("Mission fault (timeout)", inf);
            tc.verifyEqual(ses.Engine.Phase, "FAILED"); tc.verifyEqual(ses.Engine.FaultCode, "TIMEOUT");
            tc.verifyGreaterThan(ses.Engine.TickId, 100, 'the fault happens in flight, not at preflight');
            tc.verifyNotEqual(ses.Engine.PhaseLog.phase(end - 1), "LANDING", 'it did not finish');
            tc.verifyEqual(ses.view().pose.fault_code, "TIMEOUT");
            folder = ses.exportRun(f.Folder); pkg = mgv2.run.verifyPackage(folder);
            tc.verifyEqual(string(pkg.manifest.end_state.fault_code), "TIMEOUT"); tc.verifyEqual(string(pkg.manifest.scenario), "Mission fault (timeout)");
            r = mgv2.ui.MissionSession(); r.loadReplay(folder); r.start(); while r.step(), end
            tc.verifyEqual(r.Engine.Phase, "FAILED"); tc.verifyEqual(r.pose().fault_code, "TIMEOUT");
            tc.verifyTrue(mgv2.run.reproduce(pkg).match);
        end

        function invalidRaysAreMarkedNotZeroed(tc)
            ses = tc.flyHeadless("Invalid rays", 900); L = ses.Recorder.samples("LIDAR_TERRAIN"); C = ses.Recorder.samples("RGB_NADIR");
            q = cellfun(@(s) s.quality, L);
            tc.verifyGreaterThan(sum([q.out_of_range_rays]), 0); tc.verifyGreaterThan(sum([q.dropout_rays]), 0);
            for s = L, x = s{1}; tc.verifyTrue(all(isnan(x.ranges_m(x.ray_invalid_code > 0)))); end
            f = cellfun(@(s) s.quality.valid_pixel_fraction, C);
            tc.verifyTrue(any(f > 0 & f < 1), 'off-nadir camera pixels beyond 16 m are invalid while the centre is valid');
            n = mgv2.ui.MissionSession(); n.start(); for k = 1:900, n.step(); end
            q0 = cellfun(@(s) s.quality, n.Recorder.samples("LIDAR_TERRAIN"));
            tc.verifyGreaterThan(sum([q.dropout_rays]), 2 * sum([q0.dropout_rays]), 'far more dropout than the nominal model');
            tc.verifyGreaterThan(sum([q.out_of_range_rays]), sum([q0.out_of_range_rays]), 'more rays beyond range than nominal');
        end

        function thermalDropoutIsMarkedInvalid(tc)
            ses = tc.flyHeadless("Thermal dropout", 900); T = ses.Recorder.samples("THERMAL_LWIR");
            t = cellfun(@(s) s.t_s, T); bad = cellfun(@(s) ~s.valid && s.invalid_reason == "SENSOR_DROPOUT", T);
            tc.verifyEqual(bad, t >= 10 & t <= 40);
            for s = T(bad), tc.verifyTrue(all(isnan(s{1}.temperature_K(:)))); end
        end

        function resetDuringAMissionDiscardsItsRecording(tc)
            ses = tc.flyHeadless("As launched", 200); ses.pauseRun(); g = ses.evidenceContext().generation;
            ses.reset();
            tc.verifyEqual(ses.state(), "READY"); tc.verifyEqual(ses.evidenceContext().generation, g + 1);
            tc.verifyEqual(ses.Recorder.Count, height(ses.Sensors.Log), 'only the new run''s tick-0 samples');
            tc.verifyError(@() ses.exportRun(tempdir), 'mgv2:ExportFailed');
        end

        function dashboardExportsAndReplaysThroughItsButtons(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            app = mgv2MissionControl('RealTime', 0, 'MaxTicksPerRun', 200, 'ExportRoot', f.Folder); tc.App = app; B = app.Controls.Buttons;
            tc.verifyEqual(string(B.export.Enable), "off");
            tc.press(B.start); drawnow; tc.press(B.abort); drawnow;
            tc.verifyEqual(string(B.export.Enable), "on");
            tc.press(B.export); drawnow;
            tc.verifyTrue(isfolder(app.LastExport)); tc.verifySubstring(string(app.Controls.Notice.Text), "Exported");
            tc.verifyEqual(string(B.export.Enable), "off", 'exported once');
            tc.press(B.replay); drawnow;
            tc.verifyEqual(app.Session.Mode, "REPLAY"); tc.verifySubstring(string(app.Controls.Readout.Text), "REPLAY");
            tc.press(B.start); drawnow;
            tc.verifyEqual(app.Session.state(), "ENDED"); tc.verifyEqual(app.Session.Engine.TickId, 200);
            tc.verifyTrue(app.LastReplay.match, app.LastReplay.detail);
            tc.verifySubstring(string(app.Controls.Notice.Text), "Replay ended");
            tc.verifyEqual(string(B.export.Enable), "off", 'a replay is not exported');
            tc.verifyEqual(string(B.resume.Enable), "off");
            tc.press(B.reset); drawnow; tc.verifyEqual(string(app.Controls.Notice.Text), "", 'RESET clears the old notice');
            app.configure("Overcast", 7); tc.verifyEqual(app.Session.Mode, "LIVE"); tc.verifyEqual(string(app.Controls.Notice.Text), "");
        end

        function dashboardShowsARefusedReplay(tc)
            d = tc.copyPackage(); delete(fullfile(d, "events", "events.mat"));
            app = mgv2MissionControl('RealTime', 0, 'MaxTicksPerRun', 10); tc.App = app;
            app.replay(d); drawnow;
            tc.verifyEqual(app.Session.Mode, "LIVE");
            tc.verifySubstring(string(app.Controls.Notice.Text), "REPLAY REFUSED");
            tc.verifyEqual(app.Controls.Notice.FontColor, mgv2.ui.theme().invalid);
        end
    end
end
