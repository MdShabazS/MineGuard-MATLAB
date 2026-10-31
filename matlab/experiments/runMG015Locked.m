function out = runMG015Locked(stage, outFolder, runlockSha)
%RUNMG015LOCKED MG-014 locked evaluation for MG-015, in two strictly separated stages.
%   out = runMG015Locked("prepare", outFolder)
%       L-01 manifest checks. Generates the 18 TRAIN and 6 VALIDATION families only, fits the
%       normalisers on TRAIN and selects thresholds on VALIDATION (MG-009 functions, unmodified),
%       then writes the MG014-RUNLOCK-1 record (all parameters, hashes and 30 config digests).
%       TEST families are NOT generated; only their configs are digested.
%   out = runMG015Locked("heldout", outFolder, runlockSha)
%       Refuses to run unless the run-lock file's SHA-256 equals runlockSha (the reviewed value)
%       and the sealed manifest is unchanged. Only then does it generate GF-025..GF-030, evaluate the
%       five methods x three rules on a common cell mask, and run the preregistered stress
%       conditions. TEST is used ONCE; nothing is retuned.
%
%   MG-017 once-only protection (MG016-R02). All checks run BEFORE any folder is created, any file is
%   written or any scenario is generated:
%     "heldout" -> mineguard:TestConsumed if ANY of the following holds:
%        (1) outFolder already contains any TEST or stress output (comparison, per-group or stress CSV),
%            so partially populated result folders are never overwritten;
%        (2) the repository's authoritative consumption record exists: any of those outputs is committed
%            under <repo>/tasks/evidence/MG-015/ (checked independently of outFolder);
%        (3) the sealed manifest in this repository is the consumed MG-014 manifest (LF-normalised
%            SHA-256 fa5a3fa5...). This holds even for a copied run-lock in a new folder.
%        In this repository the MG-014 TEST is therefore permanently closed. This protection is
%        deliberately specific to this repository's archive, not a general access control. A new
%        study needs a separate preregistered driver and fresh held-out families.
%     "prepare" -> mineguard:RunLockExists if outFolder already contains a run-lock.
%   SIMULATION ONLY. Metrics are synthetic and model-dependent.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
mfile = fullfile(root, 'experiments', 'locked', 'mg014_scenario_manifest.json');
stage = string(stage); outFolder = string(outFolder);
if ~ismember(stage, ["prepare","heldout"])
    error('mineguard:InvalidExperimentConfig', 'stage must be "prepare" or "heldout".');
end
lockFile = fullfile(outFolder, 'MG014-RUNLOCK-1.json');
if stage == "heldout", assertTestNotConsumed(root, mfile, outFolder); end
if stage == "prepare" && isfile(lockFile)
    error('mineguard:RunLockExists', 'A run-lock already exists in %s; it is frozen and will not be overwritten.', outFolder);
end
if ~exist(outFolder, 'dir'), mkdir(outFolder); end   % only after every guard has passed
switch stage
    case "prepare", out = prepare(root, mfile, outFolder, lockFile);
    case "heldout", out = heldout(mfile, outFolder, lockFile, string(runlockSha));
end
end

function assertTestNotConsumed(root, mfile, outFolder)
% Read-only checks (no folder creation, no temp files). See the header for the three conditions.
outputs = ["MG-015-test-comparison.csv","MG-015-test-per-group.csv","MG-015-stress.csv"];
present = outputs(arrayfun(@(f) isfile(fullfile(outFolder, f)), outputs));
if ~isempty(present)
    error('mineguard:TestConsumed', ['Output folder %s already contains TEST/stress output (%s); ' ...
        'existing results are never overwritten.'], outFolder, strjoin(present, ', '));
end
evDir = fullfile(root, 'tasks', 'evidence', 'MG-015');
committed = outputs(arrayfun(@(f) isfile(fullfile(evDir, f)), outputs));
consumedManifestSha = "fa5a3fa5e4e35de44d4fba8bf26f5fe362f69d094746fd3a114c051279d19247";
if ~isempty(committed) || (isfile(mfile) && sha256lfInMemory(mfile) == consumedManifestSha)
    error('mineguard:TestConsumed', ['The MG-014 sealed TEST (GF-025..GF-030, MG014-RUNLOCK-1) is CONSUMED: it was ' ...
        'executed once on 2026-10-31 (repository record: tasks/evidence/MG-015/). It is not re-run from any ' ...
        'output folder or copied run-lock. A new study needs a separately preregistered driver and fresh holdout.']);
end
end

function h = sha256lfInMemory(f)
% LF-normalised SHA-256 (CR bytes removed), computed in memory: identical to sha256() below.
fid = fopen(f, 'r'); b = fread(fid, inf, '*uint8'); fclose(fid);
b(b == 13) = [];
md = java.security.MessageDigest.getInstance('SHA-256');
h = string(lower(reshape(dec2hex(typecast(md.digest(b), 'uint8'))', 1, [])));
end

function out = prepare(root, mfile, outFolder, lockFile)
M = jsondecode(fileread(mfile));
G = struct2table(M.groups);
G.split_id = string(G.split_id); G.profile_id = string(G.profile_id); G.group_id = string(G.group_id); G.scenario_id = string(G.scenario_id);
% L-01: allocation, uniqueness, balance, no family overlap.
man = table(G.group_id, G.scenario_id, G.seed, G.noise_seed, G.split_id, 'VariableNames', {'group_key','scenario_id','seed','noise_seed','split_id'});
mineguard.evaluation.validateSplitManifest(man);
alloc = [nnz(G.split_id == "train") nnz(G.split_id == "validation") nnz(G.split_id == "test")];
profs = unique(G.profile_id);
bal = zeros(numel(profs), 3);
for k = 1:numel(profs)
    bal(k, :) = [nnz(G.profile_id == profs(k) & G.split_id == "train") nnz(G.profile_id == profs(k) & G.split_id == "validation") nnz(G.profile_id == profs(k) & G.split_id == "test")];
end
L01 = struct('allocation', alloc, 'n_groups', height(G), 'unique_ids', numel(unique(G.group_id)) == 30 && numel(unique(G.scenario_id)) == 30, ...
    'unique_seeds', numel(unique(G.seed)) == 30 && numel(unique(G.noise_seed)) == 30 && isempty(intersect(G.seed, G.noise_seed)), ...
    'profiles', profs', 'profile_balance_train_val_test', bal, 'plan_status', string(M.plan_status), 'manifest_sha256', sha256(mfile));
assert(isequal(alloc, [18 6 6]) && L01.unique_ids && L01.unique_seeds && numel(profs) == 6 && all(bal(:,1) == 3) && all(bal(:,2:3) == 1, 'all'), ...
    'mineguard:SplitLeakage', 'L-01 manifest check failed.');

% Generate TRAIN + VALIDATION families only.
P = declared();
tr = find(G.split_id == "train"); va = find(G.split_id == "validation");
[Btr, ~] = gen(G.group_id(tr)); [Bva, Cva] = gen(G.group_id(va));
S = cellfun(@(b) b.public.samples, Btr, 'UniformOutput', false); S = vertcat(S{:});
model = mineguard.detection.fitNormalisers(S, struct('version', "mg015-gf-baseline-1.0", 'w_thermal', P.w_thermal, 'w_em', P.w_em, ...
    'cluster_time_window_s', P.cluster_time_window_s, 'cluster_radius_m', P.cluster_radius_m, 'train_scenario_ids', G.scenario_id(tr)));
[model, thr, sel] = mineguard.evaluation.selectThresholds(Bva, Cva, model, struct('rule', P.selection_rule, 'z_grid', P.z_grid, ...
    'ratio_grid', P.ratio_grid, 'split_ids', G.split_id(va), 'association_tolerance_s', P.association_tolerance_s, ...
    'localization_match_radius_m', P.localization_match_radius_m));
writetable(sel, fullfile(outFolder, 'MG-015-validation-selection.csv'));
% VALIDATION pooled results per method at the selected thresholds (pre-TEST, informational).
vrows = {};
for meth = ["thermal_only","em_only","or","and","weighted"]
    p = mineguard.evaluation.evaluateMethod(Bva, Cva, model, meth, P.selection_rule, thr.(meth), ...
        struct('split_id', "validation", 'association_tolerance_s', P.association_tolerance_s, 'localization_match_radius_m', P.localization_match_radius_m));
    vrows{end+1, 1} = struct2table(rmfield(p, {}), 'AsArray', true); %#ok<AGROW>
end
valTable = vertcat(vrows{:}); writetable(valTable, fullfile(outFolder, 'MG-015-validation-results.csv'));
trainStats = struct('n_samples', height(S), 'thermal_valid', nnz(S.valid & S.sensor_kind == "thermal"), 'em_valid', nnz(S.valid & S.sensor_kind == "em"));

% Config digests for ALL 30 families (TEST configs digested, not generated).
dig = strings(30, 1);
for k = 1:30, dig(k) = mineguard.evaluation.configChecksum(mg015GroupConfig(G.group_id(k))); end
[st, sha] = system(sprintf('git -C "%s" rev-parse HEAD', root)); if st ~= 0, sha = "NOT_RECORDED"; end
lock = struct('lock_id', "MG014-RUNLOCK-1", 'status', "PROPOSED_PENDING_REVIEW", 'created_utc', utc(), ...
    'software_git_sha', strtrim(string(sha)), 'matlab_release', string(version('-release')), ...
    'manifest_file', "experiments/locked/mg014_scenario_manifest.json", 'manifest_sha256', L01.manifest_sha256, ...
    'manifest_plan_status', L01.plan_status, 'generator', "MG-004 generateScenario (mg-contract/1.0)", ...
    'navigation', "MG-005 fixed serpentine grid, makeGridRoute/simulatePose/computeCoverage", ...
    'sensor_settings', mg007FixtureSettings(), 'detector_model', model, 'method_thresholds', thr, ...
    'association_tolerance_s', P.association_tolerance_s, 'cluster_time_window_s', P.cluster_time_window_s, ...
    'cluster_radius_m', P.cluster_radius_m, 'localization_match_radius_m', P.localization_match_radius_m, ...
    'fusion_weights', [P.w_thermal P.w_em], 'missing_modality_rules', ["abstain","single_valid","require_both"], ...
    'primary_method', "weighted", 'primary_rule', P.selection_rule, 'threshold_selection', "MG-009 selectThresholds: max pooled VALIDATION cell F1, NaN lowest, ties -> lowest threshold", ...
    'z_grid', P.z_grid, 'ratio_grid', P.ratio_grid, 'cell_rule', "MG-005 grid (2 m, half-open, last cell closed), legal = centre outside exclusions; evaluable = >=1 pose with required valid modality (MG-009 evaluableCellMask); common mask across 5 methods per rule", ...
    'stress_design', P.stress, 'config_digests', table2struct(table(G.group_id, G.split_id, dig, 'VariableNames', {'group_id','split_id','config_checksum'})), ...
    'train_samples', trainStats, 'note', "SIMULATION ONLY. TEST families GF-025..030 not generated before review of this record.");
fid = fopen(lockFile, 'w'); fprintf(fid, '%s', jsonencode(lock, 'PrettyPrint', true)); fclose(fid);
out = struct('L01', L01, 'lock_sha256', sha256(lockFile), 'thresholds', thr, 'model', model, 'validation', valTable, 'selection', sel);
end

function out = heldout(mfile, outFolder, lockFile, expectSha)
if sha256(lockFile) ~= expectSha
    error('mineguard:RunLockMismatch', 'Run-lock SHA-256 does not match the reviewed value; TEST not opened.');
end
L = jsondecode(fileread(lockFile));
if sha256(mfile) ~= string(L.manifest_sha256)
    error('mineguard:RunLockMismatch', 'Sealed manifest changed since the run-lock; TEST not opened.');
end
M = jsondecode(fileread(mfile)); G = struct2table(M.groups); G.split_id = string(G.split_id); G.group_id = string(G.group_id);
te = find(G.split_id == "test");
for k = te', assert(mineguard.evaluation.configChecksum(mg015GroupConfig(G.group_id(k))) == string(L.config_digests(k).config_checksum), ...
        'mineguard:RunLockMismatch', 'TEST config digest changed for %s.', G.group_id(k)); end
model = L.detector_model; model.version = string(model.version);
model.provenance.normaliser_split = string(model.provenance.normaliser_split); model.provenance.threshold_split = string(model.provenance.threshold_split);
thr = L.method_thresholds; P = declared();
[Bte, Cte] = gen(G.group_id(te));
meths = ["thermal_only","em_only","or","and","weighted"];
rows = {}; per = {};
for rule = ["single_valid","abstain","require_both"]
    masks = commonMasks(Bte, Cte, meths, rule);
    for meth = meths
        o = struct('split_id', "test", 'association_tolerance_s', L.association_tolerance_s, 'localization_match_radius_m', L.localization_match_radius_m, 'common_mask', {masks});
        [p, ps] = mineguard.evaluation.evaluateMethod(Bte, Cte, model, meth, rule, thr.(meth), o);
        rows{end+1, 1} = struct2table(p, 'AsArray', true); %#ok<AGROW>
        ps.method = repmat(meth, height(ps), 1); ps.rule = repmat(rule, height(ps), 1); per{end+1, 1} = ps; %#ok<AGROW>
    end
end
testTable = vertcat(rows{:}); perTable = vertcat(per{:});
writetable(testTable, fullfile(outFolder, 'MG-015-test-comparison.csv')); writetable(perTable, fullfile(outFolder, 'MG-015-test-per-group.csv'));
% Preregistered stress conditions on the same frozen TEST families (separate report).
srows = {};
for s = 1:numel(P.stress)
    cond = P.stress(s);
    [Bs, Cs] = gen(G.group_id(te), cond);
    masks = commonMasks(Bs, Cs, meths, "single_valid");
    inv = mean(cellfun(@(b) mean(~b.public.samples.valid), Bs));
    for meth = meths
        o = struct('split_id', "stress", 'association_tolerance_s', L.association_tolerance_s, 'localization_match_radius_m', L.localization_match_radius_m, 'common_mask', {masks});
        p = mineguard.evaluation.evaluateMethod(Bs, Cs, model, meth, "single_valid", thr.(meth), o);
        t = struct2table(p, 'AsArray', true); t.condition = string(cond.name); t.invalid_sample_fraction = inv; srows{end+1, 1} = t; %#ok<AGROW>
    end
end
stressTable = vertcat(srows{:}); writetable(stressTable, fullfile(outFolder, 'MG-015-stress.csv'));
out = struct('test', testTable, 'per_group', perTable, 'stress', stressTable);
end

function [B, C] = gen(ids, cond)
B = cell(numel(ids), 1); C = cell(numel(ids), 1); opts = struct();
for k = 1:numel(ids)
    C{k} = mg015GroupConfig(ids(k));
    if nargin > 1
        [C{k}, opts] = applyStress(C{k}, cond);
    end
    B{k} = mineguard.evaluation.runTrial(C{k}, opts);
end
end

function [c, opts] = applyStress(c, cond)
opts = struct();
switch string(cond.name)
    case "noise_x3", c.sensor_settings.thermal.thermal_noise_sigma_K = 3 * c.sensor_settings.thermal.thermal_noise_sigma_K; c.sensor_settings.em.em_noise_sigma_norm = 3 * c.sensor_settings.em.em_noise_sigma_norm;
    case "dropout_0p3", c.sensor_settings.thermal.dropout_probability = 0.3; c.sensor_settings.em.dropout_probability = 0.3;
    case "negative_contrast", c.sensor_settings.thermal.contrast_amplitude_K = -abs(c.sensor_settings.thermal.contrast_amplitude_K);
    case "soil_shift", c.sensor_settings.thermal.background_temperature_K = c.sensor_settings.thermal.background_temperature_K + 3; c.sensor_settings.em.em_background_norm = c.sensor_settings.em.em_background_norm + 0.05;
    case "em_rate_half", opts.em_pose_stride = 2;
end
c.sensor_settings.version = c.sensor_settings.version + "+" + string(cond.name);
c.run_options.split_id = "stress";
end

function masks = commonMasks(B, C, meths, rule)
masks = cell(numel(B), 1);
for k = 1:numel(B)
    g = struct('bounds_enu_m', B{k}.public.geometry.bounds_enu_m, 'grid_spacing_m', C{k}.grid_spacing_m, 'exclusion_polygons_enu_m', {B{k}.public.geometry.exclusion_polygons_enu_m});
    m = true;
    for meth = meths, m = m & mineguard.evaluation.evaluableCellMask(g, B{k}.public.poses, B{k}.public.samples, meth, rule); end
    masks{k} = m;
end
end

function P = declared()
% Predeclared (MG-009 reviewer-approved baseline choices); thresholds come from VALIDATION.
P = struct('association_tolerance_s', 0.05, 'cluster_time_window_s', 1.0, 'cluster_radius_m', 0.75, ...
    'localization_match_radius_m', 0.75, 'w_thermal', 0.5, 'w_em', 0.5, 'selection_rule', "single_valid", ...
    'z_grid', 2:0.5:12, 'ratio_grid', 0.5:0.1:2, ...
    'stress', struct('name', {"noise_x3","dropout_0p3","negative_contrast","soil_shift","em_rate_half"}));
end

function s = utc()
s = string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
end

function h = sha256(f)
% SHA-256 of the LF-normalised text (CR bytes removed), so the hash does not depend on git
% autocrlf / OS line endings at checkout. Same value on Windows, macOS and Linux.
raw = fileread(f); tmp = [tempname '.lf'];
fid = fopen(tmp, 'w'); fwrite(fid, unicode2native(strrep(raw, char(13), ''), 'UTF-8')); fclose(fid);
c = onCleanup(@() delete(tmp));
[st, out] = system(sprintf('certutil -hashfile "%s" SHA256', tmp));
lines = splitlines(string(out));
if st ~= 0 || numel(lines) < 2, h = "NOT_RECORDED"; return; end
h = lower(erase(strtrim(lines(2)), " "));
end
