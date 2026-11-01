function G = scenarioGroups()
%SCENARIOGROUPS Frozen V2-006 scenario-group definitions (PRE-REGISTERED before any detector tuning).
%   G = mgv2.eval.scenarioGroups()      struct array, one entry per scenario GROUP (the split unit, V2-004 §3.1)
%   Each group owns its own terrain seed, object/feature layout seed, mission/sensor seed and environment,
%   so no scene, layout, seed or environment draw is shared between groups (and therefore between splits).
%   Fields: group_id, split (TRAIN | VAL | TEST), family, environment, scene_seed, layout_seed, mission_seed,
%           n_visible_targets, n_blind_targets, n_wet, n_soil, n_scrap, thermal_dropout_s ([t0 t1] or empty),
%           demo_fixture (false for every split group).
%   Families (V2-004 §3.2, §4): POS_MIXED (visible-disturbance and no-signature hidden targets + clutter),
%   N0_TARGET_FREE, N1_CLUTTER, N2_LOW_CONTRAST, N3_DROPOUT. TEST groups are RESERVED: V2-006 never runs them
%   (mgv2.eval.runScenario refuses); the one-time held-out evaluation belongs to V2-008 (EVAL-09).
%   The counts of hidden targets per group are evaluator-side scenario parameters; they are never passed to the
%   detector, map or UI (mgv2.eval.buildScenario returns them only inside the private TargetTruth output).
row = @(id, split, fam, env, s1, s2, s3, nv, nb, nw, ns, nx, drop) struct('group_id', id, 'split', split, 'family', fam, ...
    'environment', env, 'scene_seed', s1, 'layout_seed', s2, 'mission_seed', s3, 'n_visible_targets', nv, 'n_blind_targets', nb, ...
    'n_wet', nw, 'n_soil', ns, 'n_scrap', nx, 'thermal_dropout_s', drop, 'demo_fixture', false);
z = zeros(0, 2);
G = [ ...
    row("G01", "TRAIN", "POS_MIXED",       "DAY_CLEAR",    6101, 7101, 8101, 3, 1, 1, 2, 1, z)
    row("G02", "TRAIN", "POS_MIXED",       "OVERCAST",     6102, 7102, 8102, 3, 1, 2, 1, 1, z)
    row("G03", "TRAIN", "N1_CLUTTER",      "DAY_CLEAR",    6103, 7103, 8103, 0, 0, 2, 3, 1, z)
    row("G04", "TRAIN", "N0_TARGET_FREE",  "DAY_CLEAR",    6104, 7104, 8104, 0, 0, 0, 0, 0, z)
    row("G05", "TRAIN", "N2_LOW_CONTRAST", "LOW_CONTRAST", 6105, 7105, 8105, 3, 1, 1, 2, 0, z)
    row("G06", "TRAIN", "N3_DROPOUT",      "DAY_CLEAR",    6106, 7106, 8106, 3, 0, 1, 1, 1, [22 34])
    row("G07", "VAL",   "POS_MIXED",       "DAY_CLEAR",    6107, 7107, 8107, 3, 1, 1, 2, 1, z)
    row("G08", "VAL",   "N1_CLUTTER",      "OVERCAST",     6108, 7108, 8108, 0, 0, 2, 2, 1, z)
    row("G09", "TEST",  "POS_MIXED",       "LOW_CONTRAST", 6109, 7109, 8109, 3, 1, 1, 2, 1, z)
    row("G10", "TEST",  "N3_DROPOUT",      "OVERCAST",     6110, 7110, 8110, 2, 1, 2, 1, 0, [20 32])]';
end
