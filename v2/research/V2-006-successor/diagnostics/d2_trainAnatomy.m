function S = d2_trainAnatomy(dataDir)
%D2_TRAINANATOMY Itemises FUSED events from the committed TRAIN track tables. Reads TRAIN only; no mission is flown.
%   TRAIN truth is used only by the evaluator step, after each exploratory filter. Filters below are descriptive
%   counterfactuals on consumed TRAIN data: not selection, not tuning, and not an accuracy estimate.
cfg = mgv2.detect.defaultDetectorConfig(); thr = cfg.event.score_threshold.FUSED; G = mgv2.eval.scenarioGroups(); G = G([G.split] == "TRAIN");
filters = ["NONE","INSIDE_BOUNDARY","INSIDE_BOUNDARY_1M","NOT_PROTRUDING","NOT_NEAR_OBJECT","SURVEY_PHASE","BOTH_MODALITIES"]; R = zeros(numel(filters), 3); A = []; nnAll = []; tpScore = []; fpScore = []; targetsIn = 0; targets = 0; rows = {};
for g = reshape(G, 1, [])
    T = readtable(fullfile(dataDir, "train_tracks_" + g.group_id + ".csv"), 'TextType', 'string');
    if ~ismember('known_landmark', T.Properties.VariableNames), T.known_landmark = strings(height(T), 1); end
    T.known_landmark(ismissing(T.known_landmark)) = "";
    [keep, score] = mgv2.detect.selectEvents(T, "FUSED", thr, cfg); E = T(keep, :); sc = score(keep);
    [pub, ~, TT] = mgv2.eval.buildScenario(g); P = pub.mission.survey_polygon_enu_m; w = pub.world;
    in0 = inpolygon(E.x_m, E.y_m, P(:,1), P(:,2)); dB = distToPoly(E.x_m, E.y_m, P); in1 = in0 | dB <= 1;
    O = w.objects; dO = inf(height(E), 1);
    for q = 1:height(O), dO = min(dO, hypot(E.x_m - O.x_east_m(q), E.y_m - O.y_north_m(q)) - O.radius_m(q)); end
    near = dO <= 1; prot = E.lidar_height_m > cfg.lidar.protrusion_m;
    eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(w)); eng.run(); L = eng.poseLog(); ph = string(L.phase);
    sv = find(ph == "SURVEY"); t1 = L.tick_id(sv(1)); t2 = L.tick_id(sv(end)); survey = E.last_tick >= t1 & E.first_tick <= t2;
    both = E.n_obs_rgb > 0 & E.n_obs_thermal > 0; tx = [TT.targets.x_east_m TT.targets.y_north_m];
    targetsIn = targetsIn + nnz(inpolygon(tx(:,1), tx(:,2), P(:,1), P(:,2))); targets = targets + size(tx, 1);
    m = {true(height(E), 1), in0, in1, ~prot, ~near, survey, both};
    for f = 1:numel(filters), r = mgv2.eval.evaluateEvents([E.x_m(m{f}) E.y_m(m{f})], TT, 1); R(f, :) = R(f, :) + [r.TP r.FP r.FN]; end
    r = mgv2.eval.evaluateEvents([E.x_m E.y_m], TT, 1); isTP = false(height(E), 1);
    for t = 1:size(tx, 1), [dm, b] = min(hypot(E.x_m - tx(t,1), E.y_m - tx(t,2))); if dm <= 1, isTP(b) = true; end, end
    tpScore = [tpScore; sc(isTP)]; fpScore = [fpScore; sc(~isTP)]; %#ok<AGROW>
    D = hypot(E.x_m - E.x_m', E.y_m - E.y_m'); D(1:size(D, 1) + 1:end) = inf; nn = min(D, [], 2); nnAll = [nnAll; nn]; %#ok<AGROW>
    rows(end+1, :) = {g.group_id, g.family, g.environment, height(E), nnz(~in0), nnz(in0), median(dB(~in0)), nnz(near), nnz(prot), nnz(~survey), nnz(~both), nnz(sc >= 0.999), r.TP, r.FP}; %#ok<AGROW>
    A = [A; E.looks_thermal == 0 | E.looks_rgb == 0]; %#ok<AGROW>
end
S.groups = cell2table(rows, 'VariableNames', ["group","family","env","events","outside","inside","median_m_outside","near_object_1m","lidar_protruding","no_survey_overlap","single_modality","score_1","TP","FP"]);
S.filters = array2table(R, 'VariableNames', ["TP","FP","FN"], 'RowNames', filters); S.targets_inside = [targetsIn targets];
S.nn = nnAll; S.tp_scores = tpScore; S.fp_scores = fpScore; S.missing_mode = nnz(A);
disp(S.groups); disp(S.filters);
fprintf('targets inside polygon by construction: %d of %d\n', targetsIn, targets);
fprintf('event nearest-neighbour distance: <1 m %d, <2 m %d, <4 m %d of %d (median %.2f m)\n', nnz(nnAll < 1), nnz(nnAll < 2), nnz(nnAll < 4), numel(nnAll), median(nnAll));
fprintf('scores: TP %s; FP median %.3f p90 %.3f max %.3f; share of FP scoring at least the best TP %.3f; events with a modality never looking %d\n', mat2str(tpScore', 3), median(fpScore), prctile(fpScore, 90), max(fpScore), mean(fpScore >= max(tpScore)), S.missing_mode);
end

function d = distToPoly(x, y, P)
Q = [P; P(1, :)]; d = inf(size(x));
for k = 1:size(P, 1)
    a = Q(k, :); b = Q(k + 1, :); ab = b - a; t = max(0, min(1, ((x - a(1)) * ab(1) + (y - a(2)) * ab(2)) / sum(ab .^ 2)));
    d = min(d, hypot(x - a(1) - t * ab(1), y - a(2) - t * ab(2)));
end
end
