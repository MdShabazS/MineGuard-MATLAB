function out = mgv2DetectorStudy(stage)
%MGV2DETECTORSTUDY Pre-registered V2-006 TRAIN tuning / VAL evaluation of the interpretable detector. SIMULATED.
%   mgv2DetectorStudy("MANIFEST")  write v2/data/V2-006/split_manifest.json (frozen BEFORE any tuning)
%   mgv2DetectorStudy("TRAIN")     run every TRAIN group once with the public pipeline, store track tables,
%                                  then (evaluator step) sweep the event score threshold per score mode
%                                  (FUSED, RGB_ONLY, THERMAL_ONLY) and select max-F1 (ties -> higher threshold)
%                                  -> tuning_log.csv, train_selection.csv
%   mgv2DetectorStudy("FREEZE")    check that mgv2.detect.defaultDetectorConfig holds the TRAIN-selected
%                                  thresholds and lock its fingerprint -> detector_frozen.json
%   mgv2DetectorStudy("VAL")       refuse unless the current config fingerprint equals the frozen one; run
%                                  every VAL group once; evaluate RGB-only, thermal-only and fused baselines
%                                  -> val_results.csv, val_events_<group>.csv
%   TEST groups are never run (mgv2.eval.runScenario throws mgv2:TestSealed). Truth is used ONLY by the
%   evaluator step after the detector output of a group is complete (frozen track table / events).
%   Event-level unit, r_match_m from the frozen manifest. Raw TP/FP/FN are reported; TN is undefined.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
dd = fullfile(root, 'v2', 'data', 'V2-006'); if ~isfolder(dd), mkdir(dd); end
G = mgv2.eval.scenarioGroups(); M = mgv2.eval.splitManifest(); modes = ["FUSED","RGB_ONLY","THERMAL_ONLY"];
switch upper(string(stage))
    case "MANIFEST"
        writeJson(fullfile(dd, 'split_manifest.json'), M); out = M;
        fprintf('manifest %s written (%d TRAIN, %d VAL, %d TEST reserved)\n', M.manifest_sha256, M.counts.TRAIN, M.counts.VAL, M.counts.TEST);
    case "TRAIN"
        checkManifest(dd, M);
        cfg = mgv2.detect.defaultDetectorConfig(); grid = 0.05:0.05:0.95;
        rows = {}; trk = cell(0, 1); tr = G([G.split] == "TRAIN");
        for g = tr
            o = mgv2.eval.runScenario(g, DetectorConfig=cfg); T = o.track_table; trk{end+1} = T; %#ok<AGROW>
            writetable(T, fullfile(dd, "train_tracks_" + g.group_id + ".csv"));
            fprintf('%s %s: %s, sim %.1f s, wall %.1f s, tracks %d\n', g.group_id, g.family, o.engine.Phase, o.sim_s, o.wall_s, height(T));
        end
        for i = 1:numel(tr)                                   % evaluator step (detector output already complete)
            [~, ~, TT] = mgv2.eval.buildScenario(tr(i)); T = trk{i};
            for mode = modes
                for thr = grid
                    keep = mgv2.detect.selectEvents(T, mode, thr, cfg);
                    R = mgv2.eval.evaluateEvents([T.x_m(keep) T.y_m(keep)], TT, M.r_match_m);
                    rows(end+1, :) = {tr(i).group_id, tr(i).family, mode, thr, R.n_events, R.TP, R.FP, R.FN, R.FN_no_signature}; %#ok<AGROW>
                end
            end
        end
        P = cell2table(rows, 'VariableNames', ["group_id","family","score_mode","threshold","n_events","TP","FP","FN","FN_no_signature"]);
        writetable(P, fullfile(dd, 'tuning_log.csv'));
        A = groupsummary(P, ["score_mode","threshold"], 'sum', ["TP","FP","FN"]);
        A.F1 = 2 * A.sum_TP ./ (2 * A.sum_TP + A.sum_FP + A.sum_FN);
        sel = table('Size', [0 6], 'VariableTypes', ["string","double","double","double","double","double"], ...
            'VariableNames', ["score_mode","threshold","TP","FP","FN","F1"]);
        for mode = modes
            a = A(A.score_mode == mode, :); best = max(a.F1); j = find(a.F1 == best, 1, 'last');
            sel(end+1, :) = {mode, a.threshold(j), a.sum_TP(j), a.sum_FP(j), a.sum_FN(j), a.F1(j)}; %#ok<AGROW>
        end
        writetable(sel, fullfile(dd, 'train_selection.csv')); disp(sel); out = sel;
    case "FREEZE"
        checkManifest(dd, M); cfg = mgv2.detect.defaultDetectorConfig();
        sel = readtable(fullfile(dd, 'train_selection.csv'), 'TextType', 'string');
        for k = 1:height(sel)
            if abs(cfg.event.score_threshold.(char(sel.score_mode(k))) - sel.threshold(k)) > 1e-12
                error('mgv2:NotFrozen', 'defaultDetectorConfig threshold for %s differs from the TRAIN selection.', sel.score_mode(k));
            end
        end
        F = struct('task', "V2-006", 'frozen_on', "2026-11-01", 'detector_id', cfg.detector_id, 'detector_version', cfg.detector_version, ...
            'detector_fingerprint', cfg.parameter_hash, 'score_thresholds', cfg.event.score_threshold, ...
            'selected_on', "TRAIN groups only (max F1 per score mode, ties to the higher threshold)", ...
            'split_manifest_sha256', M.manifest_sha256, 'val_policy', "VAL evaluated once with this fingerprint; TEST not run");
        writeJson(fullfile(dd, 'detector_frozen.json'), F); out = F; disp(F)
    case "VAL"
        checkManifest(dd, M); cfg = mgv2.detect.defaultDetectorConfig();
        F = jsondecode(fileread(fullfile(dd, 'detector_frozen.json')));
        if string(F.detector_fingerprint) ~= cfg.parameter_hash
            error('mgv2:NotFrozen', 'Detector fingerprint %s differs from the frozen %s.', cfg.parameter_hash, F.detector_fingerprint);
        end
        rows = {}; va = G([G.split] == "VAL");
        for g = va
            o = mgv2.eval.runScenario(g, DetectorConfig=cfg); T = o.track_table;
            writetable(T, fullfile(dd, "val_tracks_" + g.group_id + ".csv"));
            fprintf('%s %s: %s, sim %.1f s, wall %.1f s, tracks %d\n', g.group_id, g.family, o.engine.Phase, o.sim_s, o.wall_s, height(T));
            preds = cell(1, numel(modes));
            for q = 1:numel(modes)
                E = o.detector.events(ScoreMode=modes(q)); preds{q} = E;
                ev = table(repmat(modes(q), numel(E), 1), [E.event_id]', [E.x_est_m]', [E.y_est_m]', [E.uncertainty_m]', [E.model_score]', ...
                    [E.detection_basis]', 'VariableNames', ["score_mode","event_id","x_est_m","y_est_m","uncertainty_m","model_score","detection_basis"]);
                if q == 1, EV = ev; else, EV = [EV; ev]; end %#ok<AGROW>
            end
            writetable(EV, fullfile(dd, "val_events_" + g.group_id + ".csv"));
            [~, ~, TT] = mgv2.eval.buildScenario(g);             % evaluator step, after predictions are frozen
            for q = 1:numel(modes)
                R = mgv2.eval.evaluateEvents(preds{q}, TT, M.r_match_m);
                rows(end+1, :) = {g.group_id, g.family, modes(q), cfg.event.score_threshold.(char(modes(q))), R.n_events, R.n_targets, ...
                    R.TP, R.FP, R.FN, R.FN_no_signature, R.precision, R.recall, median(R.match_error_m)}; %#ok<AGROW>
            end
        end
        V = cell2table(rows, 'VariableNames', ["group_id","family","score_mode","threshold","n_events","n_targets","TP","FP","FN", ...
            "FN_no_signature","precision","recall","median_match_error_m"]);
        writetable(V, fullfile(dd, 'val_results.csv')); disp(V); out = V;
    otherwise
        error('Unknown stage %s.', stage);
end
end

function checkManifest(dd, M)
f = fullfile(dd, 'split_manifest.json');
if ~isfile(f), error('mgv2:NotFrozen', 'Write and commit the split manifest first (stage MANIFEST).'); end
J = jsondecode(fileread(f));
if string(J.manifest_sha256) ~= M.manifest_sha256, error('mgv2:NotFrozen', 'Scenario groups changed after the manifest was frozen.'); end
end

function writeJson(f, x)
fid = fopen(f, 'w'); fprintf(fid, '%s\n', jsonencode(x, 'PrettyPrint', true)); fclose(fid);
end
