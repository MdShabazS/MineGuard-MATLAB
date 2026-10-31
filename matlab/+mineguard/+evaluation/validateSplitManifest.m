function validateSplitManifest(manifest)
%VALIDATESPLITMANIFEST Enforce scenario-group splits (MG-008 Section 4).
%   mineguard.evaluation.validateSplitManifest(manifest)
%   manifest - table with at least: group_key, scenario_id, seed, noise_seed, split_id
%   Rules:
%     split_id is one of train | validation | test | stress
%     scenario_id is unique
%     each group_key (base layout family) belongs to exactly one split
%     a scenario seed or a noise seed may not appear in more than one split, so no shared
%       layout or noise family crosses the train/validation/test boundary
%     train, validation and test are all nonempty
%   Throws mineguard:SplitLeakage on any violation.
id = 'mineguard:SplitLeakage';
need = {'group_key','scenario_id','seed','noise_seed','split_id'};
if ~istable(manifest) || ~all(ismember(need, manifest.Properties.VariableNames))
    error(id, 'MineGuard splits: manifest needs columns %s.', strjoin(need, ', '));
end
sp = string(manifest.split_id);
if ~all(ismember(sp, ["train","validation","test","stress"]))
    error(id, 'MineGuard splits: unknown split_id.');
end
if ~all(ismember(["train","validation","test"], sp))
    error(id, 'MineGuard splits: train, validation and test must all be present.');
end
if numel(unique(string(manifest.scenario_id))) ~= height(manifest)
    error(id, 'MineGuard splits: duplicate scenario_id.');
end
checkFamily(string(manifest.group_key), sp, 'group_key', id);
checkFamily(string(manifest.seed), sp, 'scenario seed', id);
checkFamily(string(manifest.noise_seed), sp, 'noise seed', id);
end

function checkFamily(key, sp, what, id)
u = unique(key);
for k = 1:numel(u)
    s = unique(sp(key == u(k)));
    if numel(s) > 1
        error(id, 'MineGuard splits: %s "%s" appears in multiple splits (%s); this would leak across splits.', what, u(k), strjoin(s, ', '));
    end
end
end
