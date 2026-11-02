function M = splitManifest()
%SPLITMANIFEST Canonical TRAIN/VAL/TEST manifest of the frozen scenario groups, with SHA-256 hashes (EVAL-01).
%   M = mgv2.eval.splitManifest()
%   M.groups(k).definition_sha256 = SHA-256 of the canonical JSON of group k (jsonencode of the struct, fields
%   in definition order); M.manifest_sha256 = SHA-256 of the concatenated "group_id:split:hash" lines in group
%   order. The frozen copy is committed at v2/data/V2-006/split_manifest.json and must reproduce exactly
%   (tested); r_match_m and the analysis unit are declared here BEFORE any detector output is evaluated.
G = mgv2.eval.scenarioGroups(); lines = strings(numel(G), 1);
for k = 1:numel(G)
    h = mgv2.eval.sha256(jsonencode(G(k)));
    groups(k) = struct('group_id', G(k).group_id, 'split', G(k).split, 'family', G(k).family, 'definition_sha256', h); %#ok<AGROW>
    lines(k) = G(k).group_id + ":" + G(k).split + ":" + h;
end
M = struct('schema', "mg-v2-split/1.0", 'task', "V2-006", 'frozen_on', "2026-11-01", ...
    'split_unit', "scenario group (terrain seed + layout seed + mission/sensor seed + environment)", ...
    'analysis_unit', "event-level, one-to-one greedy nearest match", 'r_match_m', 1.0, ...
    'scenario_builder', "mgv2.eval.buildScenario scenario-builder-v1", ...
    'counts', struct('TRAIN', nnz([G.split] == "TRAIN"), 'VAL', nnz([G.split] == "VAL"), 'TEST', nnz([G.split] == "TEST")), ...
    'test_policy', "TEST groups RESERVED and NOT RUN in V2-006; one-time use in V2-008 (EVAL-09) only", ...
    'groups', groups, 'manifest_sha256', mgv2.eval.sha256(strjoin(lines, newline)));
end
