function [events, diagnostics] = detectAnomalies(detectorConfig, poses, samples, model)
%DETECTANOMALIES Observation-only anomaly detection and sensor fusion (mg-contract/1.0, MG-009).
%   events = mineguard.detection.detectAnomalies(detectorConfig, poses, samples, model)
%   [events, diagnostics] = ...   (optional second output: raw exceedance/abstention counts)
%
%   Inputs carry NO truth. detectorConfig is whitelisted (see validateDetectorConfig), poses is
%   PoseSample, samples is a vertical concatenation of thermal and EM SensorSample tables, and
%   model is the frozen artifact (TRAIN normalisers and VALIDATION thresholds).
%
%   Features (dimensionless, normalised with TRAIN statistics):
%     zT = (temperature_K - thermal_background_K) / thermal_scale_K;  thermal score = |zT|
%          (signed contrast magnitude, so cool anomalies count too)
%     zE = (response_norm - em_background_norm) / em_scale_norm;      EM score = zE (one-sided)
%   Decision score compared with detectorConfig.threshold:
%     thermal_only |zT|          em_only zE
%     or  max(|zT|/thermal_z_threshold, zE/em_z_threshold)
%     and min(|zT|/thermal_z_threshold, zE/em_z_threshold)   (needs both, under every rule)
%     weighted  w_thermal*|zT| + w_em*zE   (single_valid uses model.weighted_fallback:
%               a positive needs |zT| >= fallback thermal_z_threshold, or zE >= em_z_threshold)
%   Association: each valid thermal sample (by t_s, then sample_id) takes the closest unused
%   valid EM sample with |dt| <= association_tolerance_s. Ties go to the earlier t_s, then the
%   lexicographically smaller sample_id. Each sample joins at most one candidate. Unpaired valid
%   samples are single-modality candidates. Invalid samples never enter a decision, and NaN
%   never passes a threshold.
%   Event clustering: exceedances sorted by time are merged while dt <= cluster_time_window_s and
%   the distance to the running cluster centroid is <= cluster_radius_m. The event position is
%   the member centroid (ENU from poses), t_s and sample IDs come from the peak-score member,
%   confidence_0_1 = NaN (uncalibrated), and uncertainty_m = the declared gps_sigma_m of the peak
%   pose when the pose table provides one, else NaN.
%   Every event is status "SUSPECTED". SIMULATION ONLY; this is not mine detection.
dc = validateDetectorConfig(detectorConfig);
m = validateModel(model, dc);
[P, S] = validateObservations(poses, samples, dc.association_tolerance_s);
tol = dc.association_tolerance_s;

T = sortrows(S(S.kind_is_thermal & S.valid, :), {'t_s','sample_id'});
M = sortrows(S(~S.kind_is_thermal & S.valid, :), {'t_s','sample_id'});

% Deterministic one-to-one time association.
usedE = false(height(M), 1);
pairE = zeros(height(T), 1);
tE = M.t_s;
for i = 1:height(T)
    dt = abs(tE - T.t_s(i));
    dt(usedE) = Inf;
    mn = min(dt);
    if isempty(mn) || mn > tol, continue; end
    cand = find(dt == mn);                       % tie-break: earlier t_s, then sample_id
    cand = cand(tE(cand) == min(tE(cand)));
    if numel(cand) > 1
        [~, o] = sort(M.sample_id(cand)); cand = cand(o(1));
    end
    usedE(cand) = true;
    pairE(i) = cand;
end
nC = height(T) + nnz(~usedE);
cT = [(1:height(T))'; zeros(nnz(~usedE), 1)];
cE = [pairE; find(~usedE)];
hasT = cT > 0; hasE = cE > 0;

zT = NaN(nC, 1); zE = NaN(nC, 1); t = NaN(nC, 1);
xT = NaN(nC, 1); yT = NaN(nC, 1); xE = NaN(nC, 1); yE = NaN(nC, 1);
idT = strings(nC, 1); idE = strings(nC, 1); sig = NaN(nC, 1);
zT(hasT) = (T.temperature_K(cT(hasT)) - m.thermal_background_K) / m.thermal_scale_K;
zE(hasE) = (M.response_norm(cE(hasE)) - m.em_background_norm) / m.em_scale_norm;
idT(hasT) = T.sample_id(cT(hasT)); idE(hasE) = M.sample_id(cE(hasE));
rT = T.pose_row(cT(hasT)); rE = M.pose_row(cE(hasE));
xT(hasT) = P.x_east_m(rT); yT(hasT) = P.y_north_m(rT);
xE(hasE) = P.x_east_m(rE); yE(hasE) = P.y_north_m(rE);
t(hasE) = M.t_s(cE(hasE)); t(hasT) = T.t_s(cT(hasT));     % thermal time wins when paired
x = mean([xT xE], 2, 'omitnan'); y = mean([yT yE], 2, 'omitnan');
if ismember('gps_sigma_m', P.Properties.VariableNames)
    sig(hasE) = P.gps_sigma_m(rE); sig(hasT) = P.gps_sigma_m(rT);
end
qT = abs(zT) / m.thermal_z_threshold;
qE = zE / m.em_z_threshold;
score = NaN(nC, 1); pos = false(nC, 1);
rule = dc.missing_modality_rule;
both = hasT & hasE;
switch dc.method_name
    case "thermal_only"
        ok = hasT & (rule ~= "require_both" | hasE);
        score(ok) = abs(zT(ok)); pos(ok) = score(ok) >= dc.threshold;
    case "em_only"
        ok = hasE & (rule ~= "require_both" | hasT);
        score(ok) = zE(ok); pos(ok) = score(ok) >= dc.threshold;
    case "or"
        score(both) = max(qT(both), qE(both));
        if rule == "single_valid"
            score(hasT & ~hasE) = qT(hasT & ~hasE);
            score(hasE & ~hasT) = qE(hasE & ~hasT);
        end
        ok = ~isnan(score); pos(ok) = score(ok) >= dc.threshold;
    case "and"   % never decided on a single modality, under any rule
        score(both) = min(qT(both), qE(both));
        ok = both; pos(ok) = score(ok) >= dc.threshold;
    case "weighted"
        score(both) = m.w_thermal * abs(zT(both)) + m.w_em * zE(both);
        pos(both) = score(both) >= dc.threshold;
        if rule == "single_valid"
            fb = m.weighted_fallback;
            oT = hasT & ~hasE; oE = hasE & ~hasT;
            score(oT) = abs(zT(oT)) / fb.thermal_z_threshold; pos(oT) = score(oT) >= 1;
            score(oE) = zE(oE) / fb.em_z_threshold;           pos(oE) = score(oE) >= 1;
        end
        ok = ~isnan(score);
end
pos = pos & ~isnan(score);

% Clustering of exceedances into events (truth is never consulted).
ex = find(pos);
[~, o] = sort(t(ex)); ex = ex(o);
clusters = {};
for k = 1:numel(ex)
    c = ex(k);
    joined = false;
    if ~isempty(clusters)
        last = clusters{end};
        cx = mean(x(last)); cy = mean(y(last));
        if t(c) - t(last(end)) <= m.cluster_time_window_s && hypot(x(c) - cx, y(c) - cy) <= m.cluster_radius_m
            clusters{end}(end+1) = c; joined = true;
        end
    end
    if ~joined
        clusters{end+1} = c; %#ok<AGROW>
    end
end
events = eventTable(numel(clusters));
for k = 1:numel(clusters)
    mem = clusters{k};
    [~, b] = max(score(mem)); pk = mem(b);
    events.event_id(k) = sprintf("EV-%05d", k);
    events.t_s(k) = t(pk);
    events.x_est_m(k) = mean(x(mem));
    events.y_est_m(k) = mean(y(mem));
    events.uncertainty_m(k) = sig(pk);
    events.thermal_sample_id(k) = idT(pk);
    events.em_sample_id(k) = idE(pk);
end
events.method_name(:) = dc.method_name;
events.threshold(:) = dc.threshold;

diagnostics = struct('candidates', nC, 'paired_candidates', nnz(both), ...
    'thermal_only_candidates', nnz(hasT & ~hasE), 'em_only_candidates', nnz(hasE & ~hasT), ...
    'decided_candidates', nnz(ok), 'abstained_candidates', nC - nnz(ok), ...
    'raw_exceedances', numel(ex), 'events', height(events), ...
    'invalid_thermal_samples', nnz(S.kind_is_thermal & ~S.valid), 'invalid_em_samples', nnz(~S.kind_is_thermal & ~S.valid));
end
