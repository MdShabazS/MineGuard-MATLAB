function model = fitNormalisers(trainSamples, opts)
%FITNORMALISERS Fit TRAIN-only feature normalisers for the MG-009 detector model.
%   model = mineguard.detection.fitNormalisers(trainSamples, opts)
%   trainSamples - a vertcat of SensorSample tables from TRAIN-split scenarios only (no truth)
%   opts         - struct with version, w_thermal, w_em, cluster_time_window_s, cluster_radius_m,
%                  train_scenario_ids (string array)
%   Background is the median and scale is 1.4826*MAD of the valid samples per channel, which
%   is robust to the few object-affected samples. Zero scale is rejected rather than divided by.
%   Thresholds are left NaN, to be selected later on VALIDATION (selectThresholds).
v = trainSamples(trainSamples.valid, :);
tK = v.temperature_K(v.sensor_kind == "thermal");
eN = v.response_norm(v.sensor_kind == "em");
if numel(tK) < 10 || numel(eN) < 10
    error('mineguard:InvalidDetectorModel', 'MineGuard detection: need at least 10 valid TRAIN samples per channel.');
end
tScale = 1.4826 * median(abs(tK - median(tK)));
eScale = 1.4826 * median(abs(eN - median(eN)));
if ~(tScale > 0) || ~(eScale > 0)
    error('mineguard:InvalidDetectorModel', 'MineGuard detection: zero TRAIN scale (MAD = 0); cannot normalise. Add noise or more data.');
end
model = struct( ...
    'version', string(opts.version), ...
    'thermal_background_K', median(tK), 'thermal_scale_K', tScale, ...
    'em_background_norm', median(eN), 'em_scale_norm', eScale, ...
    'thermal_z_threshold', NaN, 'em_z_threshold', NaN, ...
    'w_thermal', opts.w_thermal, 'w_em', opts.w_em, ...
    'cluster_time_window_s', opts.cluster_time_window_s, 'cluster_radius_m', opts.cluster_radius_m, ...
    'provenance', struct('normaliser_split', "train", 'threshold_split', "validation", ...
        'train_scenario_ids', string(opts.train_scenario_ids), 'n_train_thermal', numel(tK), 'n_train_em', numel(eN), ...
        'normaliser_method', "median / 1.4826*MAD over valid TRAIN samples"));
end
