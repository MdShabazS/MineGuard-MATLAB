function out = runMG009Experiment(outFolder)
%RUNMG009EXPERIMENT Frozen-split synthetic evaluation of the five MG-009 detection methods.
%   out = runMG009Experiment(outFolder)
%   Order (enforced in code):
%     1. Build and validate the immutable split manifest
%        (train 12 / validation 4 / test 4 groups, plus 6 stress conditions x 2 groups).
%     2. Fit normalisers on TRAIN samples only.
%     3. Select thresholds on VALIDATION only (rule single_valid), then write the frozen model
%        and threshold JSON.
%     4. Re-read the frozen JSON and evaluate TEST once per method and rule, on a common
%        (matched) evaluable-cell mask.
%     5. Evaluate stress conditions with the same frozen model, under all three missing-modality rules.
%   Every number is a SYNTHETIC SIMULATION result under assumed sensor parameters (MG-007
%   fixture). It is NOT a mine-detection rate.
if ~exist(outFolder, 'dir'), mkdir(outFolder); end
P = declaredParameters();

% 1. Manifest (chosen before any data is generated; never changed after viewing results).
seeds = [1001:1012, 2001:2004, 3001:3004, 4001:4012];
split = [repmat("train", 1, 12), repmat("validation", 1, 4), repmat("test", 1, 4), repmat("stress", 1, 12)];
cond = [repmat("nominal", 1, 20), repelem(["altitude_1m","contrast_negative","noise_x3","dropout_0p3","em_rate_half","soil_shift"], 2)];
manifest = table("G" + string(seeds'), "MG009-" + string(seeds'), seeds', seeds' + 50000, split', cond', ...
    mod(seeds', 4), mod(seeds' * 7, 4), 'VariableNames', {'group_key','scenario_id','seed','noise_seed','split_id','condition','target_count','clutter_count'});
mineguard.evaluation.validateSplitManifest(manifest);

% Generate every trial (sensor data only; truth stays in bundle.private).
n = height(manifest);
bundles = cell(n, 1); configs = cell(n, 1);
for k = 1:n
    [configs{k}, opts] = trialConfig(manifest(k, :), P);
    bundles{k} = mineguard.evaluation.runTrial(configs{k}, opts);
end
manifest.config_checksum = string(cellfun(@(b) char(b.provenance.config_checksum), bundles, "UniformOutput", false));
manifest.thermal_seed = cellfun(@(b) b.provenance.thermal_seed, bundles);
manifest.em_seed = cellfun(@(b) b.provenance.em_seed, bundles);
manifest.navigation_seed = cellfun(@(b) b.provenance.navigation_seed, bundles);
manifest.altitude_m = cellfun(@(c) c.altitude_m, configs);
manifest.sensor_settings_version = string(cellfun(@(c) char(c.sensor_settings.version), configs, "UniformOutput", false));
writetable(manifest, fullfile(outFolder, 'MG-009-split-manifest.csv'));

% 2. TRAIN normalisers.
tr = find(manifest.split_id == "train");
trainSamples = vertcat(cellfun(@(b) b.public.samples, bundles(tr), 'UniformOutput', false));
trainSamples = vertcat(trainSamples{:});
model = mineguard.detection.fitNormalisers(trainSamples, struct('version', "mg009-baseline-1.0", ...
    'w_thermal', P.w_thermal, 'w_em', P.w_em, 'cluster_time_window_s', P.cluster_time_window_s, ...
    'cluster_radius_m', P.cluster_radius_m, 'train_scenario_ids', manifest.scenario_id(tr)));

% 3. VALIDATION threshold selection, then freeze.
va = find(manifest.split_id == "validation");
[model, thr, selection] = mineguard.evaluation.selectThresholds(bundles(va), configs(va), model, ...
    struct('rule', P.selection_rule, 'z_grid', P.z_grid, 'ratio_grid', P.ratio_grid, 'split_ids', manifest.split_id(va), ...
    'association_tolerance_s', P.association_tolerance_s, 'localization_match_radius_m', P.localization_match_radius_m));
writetable(selection, fullfile(outFolder, 'MG-009-validation-selection.csv'));
frozen = struct('model', model, 'method_thresholds', thr, 'declared', P);
fid = fopen(fullfile(outFolder, 'MG-009-frozen-model.json'), 'w'); fprintf(fid, '%s', jsonencode(frozen, 'PrettyPrint', true)); fclose(fid);

% 4. TEST evaluation using the re-read frozen artifact.
F = jsondecode(fileread(fullfile(outFolder, 'MG-009-frozen-model.json')));
fm = F.model; fm.version = string(fm.version);
fm.provenance.normaliser_split = string(fm.provenance.normaliser_split);
fm.provenance.threshold_split = string(fm.provenance.threshold_split);
meths = ["thermal_only","em_only","or","and","weighted"];
te = find(manifest.split_id == "test");
prov = provenanceRecord();
rows = {}; perScen = {};
for rule = ["single_valid","abstain","require_both"]
    masks = commonMasks(bundles(te), configs(te), meths, rule);
    for meth = meths
        o = struct('split_id', "test", 'association_tolerance_s', P.association_tolerance_s, ...
            'localization_match_radius_m', P.localization_match_radius_m, 'common_mask', {masks}, 'provenance', prov);
        [p, ps] = mineguard.evaluation.evaluateMethod(bundles(te), configs(te), fm, meth, rule, F.method_thresholds.(meth), o);
        rows{end+1, 1} = poolRow(p); %#ok<AGROW>
        if rule == "single_valid"
            ps.method = repmat(meth, height(ps), 1); perScen{end+1, 1} = ps; %#ok<AGROW>
        end
    end
end
testTable = vertcat(rows{:});
writetable(testTable, fullfile(outFolder, 'MG-009-test-comparison.csv'));
perScenario = vertcat(perScen{:});
writetable(perScenario, fullfile(outFolder, 'MG-009-test-per-scenario.csv'));

% 5. Stress conditions (frozen model, all three rules, common mask per rule). Kept separate from TEST.
srows = {};
for c = unique(manifest.condition(manifest.split_id == "stress"), 'stable')'
    idx = find(manifest.split_id == "stress" & manifest.condition == c);
    inv = cellfun(@(b) mean(~b.public.samples.valid), bundles(idx));
    for rule = ["single_valid","abstain","require_both"]
        masks = commonMasks(bundles(idx), configs(idx), meths, rule);
        for meth = meths
            o = struct('split_id', "stress", 'association_tolerance_s', P.association_tolerance_s, ...
                'localization_match_radius_m', P.localization_match_radius_m, 'common_mask', {masks}, 'provenance', prov);
            p = mineguard.evaluation.evaluateMethod(bundles(idx), configs(idx), fm, meth, rule, F.method_thresholds.(meth), o);
            r = poolRow(p); r.condition = c; r.invalid_sample_fraction = mean(inv);
            srows{end+1, 1} = r; %#ok<AGROW>
        end
    end
end
stressTable = vertcat(srows{:});
writetable(stressTable, fullfile(outFolder, 'MG-009-stress.csv'));

out = struct('manifest', manifest, 'model', fm, 'thresholds', F.method_thresholds, 'selection', selection, ...
    'test', testTable, 'per_scenario', perScenario, 'stress', stressTable, 'declared', P, 'provenance', prov);
end

function P = declaredParameters()
% Declared BEFORE any data was generated; not tuned on TEST. Values are illustrative.
P = struct('bounds_m', 10, 'grid_spacing_m', 0.5, 'altitude_m', 0.3, 'speed_mps', 2, 'dt_s', 0.1, ...
    'association_tolerance_s', 0.05, 'cluster_time_window_s', 1.0, 'cluster_radius_m', 0.75, ...
    'localization_match_radius_m', 0.75, 'w_thermal', 0.5, 'w_em', 0.5, 'selection_rule', "single_valid", ...
    'z_grid', 2:0.5:12, 'ratio_grid', 0.5:0.1:2, ...
    'target_materials', ["synthetic_metal_cased_surrogate","synthetic_cased_surrogate","synthetic_plastic_surrogate"], ...
    'clutter_materials', ["synthetic_metal_debris","synthetic_rock","synthetic_root"]);
end

function [c, opts] = trialConfig(row, P)
c = struct('schema_version', "mg-contract/1.0", 'scenario_id', row.scenario_id, 'seed', row.seed, ...
    'x_min_m', 0, 'x_max_m', P.bounds_m, 'y_min_m', 0, 'y_max_m', P.bounds_m, 'terrain_id', "flat-datum", ...
    'grid_spacing_m', P.grid_spacing_m, 'dt_s', P.dt_s, 'sampling_hz', 1 / P.dt_s, 'altitude_m', P.altitude_m, ...
    'speed_mps', P.speed_mps, 'noise_seed', row.noise_seed, 'target_count', row.target_count, ...
    'clutter_count', row.clutter_count, 'min_separation_m', 0.5, 'soil_class', "synthetic_loam", 'model_version', "mg009-0.1");
c.sensor_settings = mg007FixtureSettings();
opts = struct();
switch row.condition
    case "altitude_1m",       c.altitude_m = 1.0;
    case "contrast_negative", c.sensor_settings.thermal.contrast_amplitude_K = -2.0;
    case "noise_x3"
        c.sensor_settings.thermal.thermal_noise_sigma_K = 0.3; c.sensor_settings.em.em_noise_sigma_norm = 0.06;
    case "dropout_0p3"
        c.sensor_settings.thermal.dropout_probability = 0.3; c.sensor_settings.em.dropout_probability = 0.3;
    case "em_rate_half",      opts.em_pose_stride = 2;
    case "soil_shift"
        c.sensor_settings.thermal.background_temperature_K = 296.15; c.sensor_settings.em.em_background_norm = 0.10;
end
if row.condition ~= "nominal"
    c.sensor_settings.version = c.sensor_settings.version + "+" + row.condition;
end
% Experiment-level material assignment (seeded; positions/labels/depths untouched).
opts.truthTransform = @(t) assignMaterials(t, row.seed, P);
end

function t = assignMaterials(t, seed, P)
s = RandStream('mt19937ar', 'Seed', seed + 777);
for k = 1:height(t)
    if string(t.label(k)) == "target"
        t.material_type(k) = P.target_materials(randi(s, 3));
    else
        t.material_type(k) = P.clutter_materials(randi(s, 3));
    end
end
end

function masks = commonMasks(bundles, configs, meths, rule)
% Matched comparison population: a cell must be evaluable for ALL five methods under this rule.
masks = cell(numel(bundles), 1);
for k = 1:numel(bundles)
    b = bundles{k};
    g = struct('bounds_enu_m', b.public.geometry.bounds_enu_m, 'grid_spacing_m', configs{k}.grid_spacing_m, ...
        'exclusion_polygons_enu_m', {b.public.geometry.exclusion_polygons_enu_m});
    m = true;
    for meth = meths
        m = m & mineguard.evaluation.evaluableCellMask(g, b.public.poses, b.public.samples, meth, rule);
    end
    masks{k} = m;
end
end

function r = poolRow(p)
[rl, rh] = wilson(p.tp, p.tp + p.fn);
[fl, fh] = wilson(p.fp, p.fp + p.tn);
r = table(p.method, p.rule, p.threshold, p.tp, p.fp, p.tn, p.fn, p.precision, p.recall, rl, rh, p.f1, p.fpr, fl, fh, ...
    p.events, p.object_matches, p.unmatched_events, p.mean_loc_err_m, ...
    'VariableNames', {'method','rule','threshold','tp','fp','tn','fn','precision','recall','recall_wilson_lo','recall_wilson_hi', ...
    'f1','fpr','fpr_wilson_lo','fpr_wilson_hi','events','object_matches','unmatched_events','mean_loc_err_m'});
end

function [lo, hi] = wilson(k, n)
% 95 % Wilson score interval; NaN when n = 0. Cells are not fully independent, so treat as indicative.
if n == 0, lo = NaN; hi = NaN; return; end
z = 1.959963984540054; ph = k / n;
den = 1 + z^2 / n; ctr = (ph + z^2 / (2*n)) / den;
hw = z * sqrt(ph * (1 - ph) / n + z^2 / (4 * n^2)) / den;
lo = max(0, ctr - hw); hi = min(1, ctr + hw);
end

function prov = provenanceRecord()
[st, sha] = system('git rev-parse --short HEAD');
if st ~= 0, sha = "NOT_RECORDED"; end
v = ver;
prov = struct('git_sha', strtrim(string(sha)), 'matlab_release', string(version('-release')), ...
    'toolbox_manifest', strjoin(string({v.Name}) + " " + string({v.Version}), "; "));
end
