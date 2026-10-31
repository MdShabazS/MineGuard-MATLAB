classdef testMG017Release < matlab.uitest.TestCase
    %TESTMG017RELEASE MG-017 release-candidate validation (MG016-R01..R08). SIMULATION ONLY.
    %   Needs an interactive MATLAB desktop (renders the real dashboard). Run from the repo root:
    %     addpath('matlab'); runtests('matlab/tests/testMG017Release.m')
    %   The consumed MG-014 sealed TEST is NEVER re-run here: its committed CSVs are only read and
    %   hashed, and the once-only guards are checked to refuse before any scenario is generated.

    properties (Constant)
        Root = fileparts(fileparts(fileparts(mfilename('fullpath'))))
        % LF-normalised SHA-256 (CR bytes removed) of the frozen scientific artifacts; the checkpoint is raw bytes.
        Frozen = [ ...
            "experiments/locked/mg014_scenario_manifest.json", "fa5a3fa5e4e35de44d4fba8bf26f5fe362f69d094746fd3a114c051279d19247"; ...   % manifest
            "tasks/evidence/MG-015/MG014-RUNLOCK-1.json", "5e9f85334062d68b338c71c53592a0c04e2859adbe0da59452521a21a724a07a"; ...   % runlock
            "tasks/evidence/MG-015/MG014-RUNLOCK-1-detector-model.json", "cb110fcedc79228758a9d71262cd9b801d1ceee249ffe5e53a4df046fc2838b1"; ...   % detector
            "tasks/evidence/MG-015/MG-015-test-comparison.csv", "a4a256c3fbb674b6c7ec1c29d0a333922bd96a75c966b64522a13c027292ccf2"; ...   % test
            "tasks/evidence/MG-015/MG-015-test-per-group.csv", "3420b2257c5dc652475eebf722414586c66dc50d20ba2aae19dcf5db195e7acb"; ...   % testgroups
            "tasks/evidence/MG-015/MG-015-stress.csv", "fc80033e94585e156d3977ef9308415279d53b421a631ef96ab53c236367d11c"; ...   % stress
            "experiments/mg019/mg019_scenario_manifest.json", "dda848a1324a63abc45c1443cf095a000d12d605d36e4dae9924573bb1d29bd5"; ...   % mg019man
            "tasks/evidence/MG-019/MG-019-paired-missions.csv", "571cdd0a8accaa7de558602d3dcea61d86999af35ba6b844209613c452db2193"; ...   % mg019csv
            "tasks/evidence/MG-019/MG-019-summary.json", "b571f1ceaf9e918816540c586bcde4957391e0e89c2b6f7c60e4d2330878ecdb"; ...   % mg019json
            ]
        Checkpoint = "5a0da1715a1c2f7044a3b954d8cdf5e6d234731a2f4619d82cb3ea87e875b8ad"
        TruthNames = ["target_id","burial_depth_m","material_type","label","surface_exposed","truth","hidden_truth", ...
                      "target_count","clutter_count","targets","clutter"]
        ExportFiles = ["em_samples.csv","events.csv","poses.csv","run_bundle_redacted.mat","snapshot.png","summary.json","thermal_samples.csv"]
        Notes = "docs/RELEASE_NOTES_v1.0.0-rc.1.md"
    end
    properties
        App; Bundle; Console; ExportDir; Truth
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(tc.Root, 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(tc.Root, 'matlab', 'experiments')));
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            [tc.Console, tc.App, tc.Bundle] = testMG017Release.runDemo(d);
            tc.addTeardown(@() delete(tc.App));
            e = dir(fullfile(d, 'MG011-export-*')); tc.assertNumElements(e, 1, 'exactly one export folder');
            tc.ExportDir = fullfile(d, e.name);
            [~, tc.Truth] = mineguard.scenario.generateScenario(mg015DemoConfig("S0"));
        end
    end

    methods (Static)
        function [out, app, rb] = runDemo(d) %#ok<STOUT,INUSD> outputs and d are used inside evalc
            out = evalc('[app, rb] = mineguardDemo("S0", ''ExportTo'', d);');
        end
        function h = sha(f, lf)
            fid = fopen(f, 'r'); b = fread(fid, inf, '*uint8'); fclose(fid);
            if lf, b(b == 13) = []; end
            md = java.security.MessageDigest.getInstance('SHA-256');
            h = string(lower(reshape(dec2hex(typecast(md.digest(b), 'uint8'))', 1, [])));
        end
        function h = frozenHashes(tc)
            h = arrayfun(@(k) testMG017Release.sha(fullfile(tc.Root, tc.Frozen(k, 1)), true), (1:size(tc.Frozen, 1))');
            h(end+1) = testMG017Release.sha(fullfile(tc.Root, 'results', 'approved', 'mg013_ppo_checkpoint.mat'), false);
        end
        function verifyGuardError(tc, fh, id, msgPart)
            % The error must come from the read-only guard (assertTestNotConsumed), which runs before
            % any folder creation, file write or TEST-family generation, and must be fast (no simulation).
            t0 = tic;
            try
                fh(); tc.verifyFail("expected " + id);
            catch err
                tc.verifyEqual(string(err.identifier), string(id));
                tc.verifySubstring(err.message, char(msgPart));
                tc.verifyEqual(string(err.stack(1).name), "assertTestNotConsumed", 'raised by the pre-execution guard');
                [~, fn] = fileparts(err.stack(1).file); tc.verifyEqual(string(fn), "runMG015Locked", 'guard is the local function of runMG015Locked');
            end
            tc.verifyLessThan(toc(t0), 5, 'guard refused without running any scenario');
        end
        function [names, strs, nums] = walk(x)
            % Recursively collect field/variable names, text values and numeric values.
            names = strings(0, 1); strs = strings(0, 1); nums = zeros(0, 1);
            if istable(x)
                names = string(x.Properties.VariableNames(:));
                for v = x.Properties.VariableNames
                    [n, s, m] = testMG017Release.walk(x.(v{1})); names = [names; n]; strs = [strs; s]; nums = [nums; m]; %#ok<AGROW>
                end
            elseif isstruct(x)
                names = string(fieldnames(x));
                for k = 1:numel(x)
                    for f = fieldnames(x)'
                        [n, s, m] = testMG017Release.walk(x(k).(f{1})); names = [names; n]; strs = [strs; s]; nums = [nums; m]; %#ok<AGROW>
                    end
                end
            elseif iscell(x)
                for k = 1:numel(x)
                    [n, s, m] = testMG017Release.walk(x{k}); names = [names; n]; strs = [strs; s]; nums = [nums; m]; %#ok<AGROW>
                end
            elseif isstring(x) || ischar(x) || iscategorical(x)
                strs = string(x(:));
            elseif isnumeric(x) || islogical(x)
                nums = double(x(:));
            end
        end
    end

    methods (Test)
        % ---------- R01: negative held-out result is prominent and exact ----------
        function r01_releaseInfoMatchesCommittedResults(tc)
            rel = mineguard.releaseInfo();
            tc.verifyMatches(rel.version, "^\d+\.\d+\.\d+-rc\.\d+$"); tc.verifyEqual(rel.tag, "v" + rel.version);
            T = readtable(fullfile(tc.Root, rel.heldout.source), 'TextType', 'string');
            row = T(T.method == rel.heldout.method & T.rule == rel.heldout.rule, :);
            tc.assertEqual(height(row), 1);
            tc.verifyEqual([row.tp row.fp row.tn row.fn], [rel.heldout.tp rel.heldout.fp rel.heldout.tn rel.heldout.fn]);
            tc.verifyEqual([row.tp row.fp row.tn row.fn], [0 26 470 4], 'frozen held-out result must stay TP 0 FP 26 TN 470 FN 4');
            S = jsondecode(fileread(fullfile(tc.Root, rel.ppo.source)));
            tc.verifyEqual([S.evaluation.n_grid_feasible S.evaluation.feasible_ppo_wins], [rel.ppo.feasible_pairs rel.ppo.ppo_wins]);
            tc.verifyEqual(rel.default_planner, "grid"); tc.verifyEqual(rel.ppo_status, "EXPERIMENTAL");
        end

        function r01_demoAndDashboardShowNegativeResult(tc)
            tc.verifySubstring(tc.Console, "1.0.0-rc.1");
            tc.verifySubstring(tc.Console, "S0 is a DISPLAY FIXTURE");
            tc.verifySubstring(tc.Console, "TP 0 FP 26 TN 470 FN 4");
            tc.verifySubstring(tc.Console, "SIMULATION ONLY");
            ev = string(tc.App.uiHandles().eval.Value);
            tc.verifyTrue(any(contains(ev, "DISPLAY FIXTURE")) && any(contains(ev, "NOT held-out")));
            tc.verifyTrue(any(contains(ev, "TP 0 FP 26 TN 470 FN 4 - NEGATIVE")));
            tc.verifyTrue(any(contains(ev, "Not evidence of real mine detection")));
            txt = lower(strjoin([ev; string(tc.App.uiHandles().meta.Value); string(tc.App.figureHandle().Name)], " "));
            tc.verifyEmpty(regexp(txt, '\<(safe|cleared|all clear|confirmed mine|mine found)\>', 'once'), 'no forbidden status claim');
            tc.verifyTrue(all(tc.Bundle.events.status == "SUSPECTED"));
        end

        % ---------- R02: frozen evidence intact; TEST cannot be re-opened ----------
        function r02_frozenArtifactsUnchanged(tc)
            for k = 1:size(tc.Frozen, 1)
                tc.verifyEqual(testMG017Release.sha(fullfile(tc.Root, tc.Frozen(k, 1)), true), tc.Frozen(k, 2), tc.Frozen(k, 1));
            end
            tc.verifyEqual(testMG017Release.sha(fullfile(tc.Root, 'results', 'approved', 'mg013_ppo_checkpoint.mat'), false), tc.Checkpoint);
        end

        function r02_onceOnlyGuards(tc)
            % Original evidence folder: TEST refused, run-lock not overwritten, nothing written.
            ev = fullfile(tc.Root, 'tasks', 'evidence', 'MG-015');
            before = testMG017Release.frozenHashes(tc);
            testMG017Release.verifyGuardError(tc, @() runMG015Locked("heldout", ev, tc.Frozen(2, 2)), 'mineguard:TestConsumed', "already contains");
            tc.verifyError(@() runMG015Locked("prepare", ev), 'mineguard:RunLockExists');
            tc.verifyError(@() mg015DemoConfig("GF-025"), 'mineguard:SealedTest');
            tc.verifyEqual(testMG017Release.frozenHashes(tc), before, 'guards changed no frozen file');
        end

        function r02_alternateFolderWithCopiedLockRefused(tc)
            % PR #44 review: a NEW folder holding a copy of the approved run-lock, called with the
            % approved SHA, must be refused by the repository consumption record (not by folder contents).
            before = testMG017Release.frozenHashes(tc);
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            copyfile(fullfile(tc.Root, tc.Frozen(2, 1)), fullfile(d, 'MG014-RUNLOCK-1.json'));
            tc.assertEqual(testMG017Release.sha(fullfile(d, 'MG014-RUNLOCK-1.json'), true), tc.Frozen(2, 2), 'copied lock is the approved lock');
            listing = sort(string({dir(d).name}));
            testMG017Release.verifyGuardError(tc, @() runMG015Locked("heldout", d, tc.Frozen(2, 2)), 'mineguard:TestConsumed', "CONSUMED");
            tc.verifyEqual(sort(string({dir(d).name})), listing, 'nothing written into the alternate folder');
            % A not-yet-existing folder: refused before mkdir (no folder created).
            n = tempname;
            testMG017Release.verifyGuardError(tc, @() runMG015Locked("heldout", n, tc.Frozen(2, 2)), 'mineguard:TestConsumed', "CONSUMED");
            tc.verifyFalse(isfolder(n), 'guard must fail before creating the output folder');
            tc.verifyEqual(testMG017Release.frozenHashes(tc), before, 'frozen files unchanged');
        end

        function r02_partialOutputsProtected(tc)
            % Any single existing TEST or stress output blocks the run (no partial overwrite).
            for f = ["MG-015-test-comparison.csv","MG-015-test-per-group.csv","MG-015-stress.csv"]
                d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
                fid = fopen(fullfile(d, f), 'w'); fprintf(fid, 'sentinel'); fclose(fid);
                testMG017Release.verifyGuardError(tc, @() runMG015Locked("heldout", d, tc.Frozen(2, 2)), 'mineguard:TestConsumed', f);
                tc.verifyEqual(string(fileread(fullfile(d, f))), "sentinel", f + " not overwritten");
                tc.verifyEqual(numel(dir(d)) - 2, 1, 'no other file written');
            end
        end

        % ---------- R03: MG-015 documentation clarified ----------
        function r03_mg015StageTwoCommentClarified(tc)
            s = fileread(fullfile(tc.Root, 'tasks', 'evidence', 'MG-015.md'));
            tc.verifyEmpty(strfind(s, '% Locked evaluation, stage 2 (NOT RUN; only after the run-lock is approved):'));
            tc.verifySubstring(s, 'stage 2 (HISTORICAL');
        end

        % ---------- R04: one-command demo, real controls, verified export readback ----------
        function r04_dashboardControls(tc)
            app = tc.App; h = app.uiHandles();
            tc.press(h.reset);  tc.verifyEqual(app.State, "READY"); tc.verifyEqual(app.Cursor, 1);
            tc.press(h.play);   tc.verifyEqual(app.State, "RUNNING"); pause(0.4);
            tc.press(h.pause);  tc.verifyEqual(app.State, "PAUSED"); c = app.Cursor; tc.verifyGreaterThan(c, 1, 'replay advanced');
            tc.press(h.step);   tc.verifyEqual(app.Cursor, c + 1);
            app.seek(50); T = tc.Bundle.poses.t_s; tc.verifyEqual(app.Cursor, find(T <= 50, 1, 'last')); tc.verifyEqual(app.State, "PAUSED");
            app.seek(NaN); tc.verifySubstring(char(app.StatusText), 'Seek ignored');
            app.seek(1e9); tc.verifyEqual(app.Cursor, height(tc.Bundle.poses));
            tc.press(h.reset);  tc.verifyEqual(app.State, "READY"); tc.verifyEqual(app.Cursor, 1);
            tc.verifySubstring(tc.Console, "Export verified: 7 files");
        end

        function r04_exportReadback(tc)
            d = tc.ExportDir; rb = tc.Bundle;
            f = dir(d); f = sort(string({f(~[f.isdir]).name})); tc.verifyEqual(f, sort(tc.ExportFiles), 'exact export file set');
            for n = ["poses","thermal_samples","em_samples","events"]
                R = readtable(fullfile(d, n + ".csv"), 'TextType', 'string', 'Delimiter', ',');
                tc.verifyEqual(string(R.Properties.VariableNames), string(rb.(n).Properties.VariableNames), n);
                tc.verifyEqual(height(R), height(rb.(n)), n);
            end
            R = readtable(fullfile(d, 'poses.csv')); tc.verifyEqual(R.x_east_m, rb.poses.x_east_m, 'AbsTol', 1e-9);
            m = load(fullfile(d, 'run_bundle_redacted.mat')); tc.verifyTrue(isequaln(m.runBundle, rb), 'MAT round-trip');
            js = jsondecode(fileread(fullfile(d, 'summary.json')));
            tc.verifyEqual(string(js.scenario_id), rb.scenario_id); tc.verifyEqual(js.rows.events, height(rb.events));
            tc.verifyEqual(string(js.provenance.git_sha), rb.provenance.git_sha);
            tc.verifyMatches(string(js.provenance.git_sha), "^[0-9a-f]{7,40}(\+uncommitted)?$");
            tc.verifyEqual(string(js.provenance.matlab_release), string(version('-release')));
            tc.verifySubstring(char(js.banner), 'SIMULATION');
            img = imread(fullfile(d, 'snapshot.png')); tc.verifyGreaterThan(size(img, 1), 300); tc.verifyEqual(size(img, 3), 3);
        end

        % ---------- R05: public export privacy and explicit invalid readings ----------
        function r05_exportHasNoHiddenTruth(tc)
            d = tc.ExportDir; truth = tc.Truth;
            tc.verifyMatches(string(d), "MG011-export-MG015-DEMO-S0-\d{8}T\d{6}Z$");
            names = strings(0, 1); strs = strings(0, 1); nums = zeros(0, 1);
            for n = ["poses","thermal_samples","em_samples","events"]
                [a, b, c] = testMG017Release.walk(readtable(fullfile(d, n + ".csv"), 'TextType', 'string', 'Delimiter', ','));
                names = [names; a]; strs = [strs; b]; nums = [nums; c]; %#ok<AGROW>
            end
            [a, b, c] = testMG017Release.walk(jsondecode(fileread(fullfile(d, 'summary.json')))); names = [names; a]; strs = [strs; b]; nums = [nums; c];
            [a, b, c] = testMG017Release.walk(load(fullfile(d, 'run_bundle_redacted.mat'))); names = [names; a]; strs = [strs; b]; nums = [nums; c];
            tc.verifyEmpty(intersect(lower(names), tc.TruthNames), 'no hidden-truth field/column names');
            raw = lower(strjoin([strs; string(fileread(fullfile(d, 'summary.json')))], " "));
            for s = [string(truth.target_id); unique(string(truth.material_type))]'
                tc.verifyEmpty(strfind(raw, lower(s)), "hidden truth value leaked: " + s);
            end
            hidden = [truth.x_east_m; truth.y_north_m; truth.burial_depth_m];
            tc.verifyFalse(any(abs(nums(:) - hidden') < 1e-12, 'all'), 'no exact hidden coordinate/depth value');
            tc.verifyEmpty(regexp(raw, '\<(cleared|all clear|confirmed mine|mine found)\>', 'once'));
            E = readtable(fullfile(d, 'events.csv'), 'TextType', 'string'); tc.verifyTrue(all(E.status == "SUSPECTED"));
        end

        function r05_invalidReadingsExplicitInExport(tc)
            % GF-006 is a TRAIN/VALIDATION weak-standoff family: every EM reading is MODEL_OUT_OF_DOMAIN.
            rb = mineguard.runExperiment(mg015DemoConfig("GF-006"));
            em = rb.em_samples; bad = ~em.valid;
            tc.assertTrue(any(bad), 'fixture must contain invalid EM readings');
            tc.verifyTrue(all(isnan(em.response_norm(bad)))); tc.verifyTrue(all(strlength(string(em.invalid_reason(bad))) > 0));
            app = mineguard.app.openMissionApp(rb); tc.addTeardown(@() delete(app));
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            tc.verifyTrue(app.exportRun(d));
            e = dir(fullfile(d, 'MG011-export-*'));
            R = readtable(fullfile(d, e.name, 'em_samples.csv'), 'TextType', 'string');
            tc.verifyTrue(all(isnan(R.response_norm(~R.valid))), 'invalid readings stay NaN, never 0');
            tc.verifyEqual(string(R.invalid_reason(~R.valid)), string(em.invalid_reason(bad)));
        end

        function r05_exportFailureClaimsNothing(tc)
            f = [tempname '.txt']; fid = fopen(f, 'w'); fclose(fid); tc.addTeardown(@() delete(f));
            tc.verifyFalse(tc.App.exportRun(f), 'export into a file path must fail');
            tc.verifySubstring(char(tc.App.StatusText), 'Export FAILED');
        end

        % ---------- R06: unsupported features stay gated ----------
        function r06_unsupportedFeaturesGated(tc)
            meta = strjoin(string(tc.App.uiHandles().meta.Value), " ");
            tc.verifySubstring(meta, "3-D view: NOT AVAILABLE"); tc.verifySubstring(meta, "Hardware/telemetry link: NONE");
            s = fileread(fullfile(tc.Root, tc.Notes));
            for k = ["macOS", "NOT TESTED", "3-D", "NOT IMPLEMENTED", "Raspberry Pi", "flight controller", "GNSS"]
                tc.verifySubstring(s, k);
            end
        end

        % ---------- R07: PPO experimental, fixed grid default, negative paths ----------
        function r07_ppoExperimentalAndNegativePaths(tc)
            for f = ["matlab/mineguardDemo.m", "matlab/+mineguard/runExperiment.m"]
                s = fileread(fullfile(tc.Root, f));
                tc.verifyEmpty(regexp(s, 'loadPPOCheckpoint|runSurveyMission|rlPPOAgent', 'once'), f + " must not use PPO");
            end
            tc.verifyError(@() mineguard.integration.loadPPOCheckpoint("", repmat('0', 1, 64)), 'mineguard:CheckpointMismatch');
            pol = mineguard.integration.loadPPOCheckpoint(); tc.verifyEqual(pol.checksum, tc.Checkpoint);
            tc.verifyError(@() mineguard.integration.runSurveyMission(mg015GroupConfig("GF-001", mg015DetectorSettings("RUNLOCK")), ...
                "ppo", struct('policy', pol)), 'mineguard:IncompatiblePolicy');
            c = mg019ScenarioConfig(7301);
            [~, g] = mineguard.integration.runSurveyMission(c, "grid");
            tc.verifyFalse(g.executed); tc.verifyTrue(isnan(g.coverage_fraction), 'infeasible grid is NaN, not 0');
            [~, p] = mineguard.integration.runSurveyMission(c, "ppo", struct('policy', pol));
            T = mineguard.integration.comparisonTable({g, p});     % valid (PR #42 allowlist)
            T.label = zeros(2, 1);
            tc.verifyError(@() mineguard.app.validateComparisonTable(T), 'mineguard:InvalidComparison');
        end

        % ---------- R08: release documents keep audit/CI boundaries ----------
        function r08_releaseNotesBoundaries(tc)
            s = fileread(fullfile(tc.Root, tc.Notes));
            for k = ["v1.0.0-rc.1", "TP 0", "FP 26", "TN 470", "FN 4", "SIMULATION ONLY", "EXPERIMENTAL", ...
                     "does not run MATLAB", "MG016-R01", "MG016-R08", "addpath('matlab'); mineguardDemo", "mineguardPPODemo"]
                tc.verifySubstring(s, k);
            end
            r = fileread(fullfile(tc.Root, 'README.md'));
            tc.verifySubstring(r, "RELEASE_NOTES_v1.0.0-rc.1.md"); tc.verifySubstring(r, "TP 0, FP 26, TN 470, FN 4");
        end
    end
end
