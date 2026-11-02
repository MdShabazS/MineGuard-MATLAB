function [pub, fwd, TargetTruth] = buildScenario(g)
%BUILDSCENARIO PRIVATE scenario builder: public inputs, private forward features and evaluator-only truth (V2-006).
%   [pub, fwd, TargetTruth] = mgv2.eval.buildScenario(g)     g: one entry of mgv2.eval.scenarioGroups
%                                                            (or mgv2.eval.demoFixtureGroup)
%   pub          PUBLIC, allowlisted: world (V2-003 scene: terrain, rocks, bushes, landmarks), mission (V2-002
%                MissionConfig), environment, sensor_config. No family name, no counts, no labels.
%   fwd          PRIVATE to the sensor forward models only: struct array of flat surface features
%                (mgv2.sensors.validateSurfaceFeatures) in a seeded random order with NO identity/class field;
%                target-related disturbances and clutter patches are indistinguishable by structure.
%   TargetTruth  EVALUATOR ONLY (V2-004 §3): hidden targets (x, y, surface signature, burial depth), the
%                scenario family and the demo-fixture flag. Its name is on the truth-firewall list, so
%                mgv2.sensors.assertPublic rejects it anywhere in a public record (tested).
%   Hidden targets are SYNTHETIC hypotheses. "VISIBLE_DISTURBANCE" targets add a flat disturbed-soil feature
%   whose colour/size/temperature distributions deliberately OVERLAP the bare-soil clutter patches (V2-004
%   §3.2: no perfectly label-correlated clue). "NONE" targets have no observable effect at all (blind spot:
%   they must be missed). Feature parameters are ASSUMED, documented magnitudes, not measured signatures.
rs = RandStream('mrg32k3a', 'Seed', g.layout_seed);
poly = [-20 -14; 20 -14; 20 14; -20 14]; home = [-30 -26];
lm = struct('id', {"LM-1","LM-2"}, 'xy', {[-12 + 4 * rand(rs), -6 + 4 * rand(rs)], [8 + 4 * rand(rs), 4 + 4 * rand(rs)]}, ...
    'radius_m', {0.6, 0.6}, 'color', {[0.95 0.10 0.85], [0.10 0.85 0.95]});
sc = mgv2.scene.defaultSceneConfig('scene_id', "V2-006-SCENE-" + g.group_id, 'seed', g.scene_seed, ...
    'extent_enu_m', [-40 40; -36 36], 'home_enu_m', home, 'survey_polygon_enu_m', poly, 'n_rocks', 30, 'n_bushes', 14, 'landmarks', lm);
world = mgv2.scene.buildWorld(sc);
mc = mgv2.mission.defaultConfig('run_id', "V2-006-RUN-" + g.group_id, 'scenario_id', "V2-006-" + g.group_id, ...
    'seed', g.mission_seed, 'bounds_enu_m', [-40 40; -36 36; -10 120], 'survey_polygon_enu_m', poly, 'home_enu_m', home, ...
    'line_spacing_m', 8);
env = mgv2.sensors.defaultEnvironment(g.environment);
scfg = mgv2.sensors.defaultSensorConfig();
if ~isempty(g.thermal_dropout_s), scfg.THERMAL_LWIR.dropout_model.intervals_s = g.thermal_dropout_s; end
scfg = mgv2.sensors.validateSensorConfig(scfg);
pub = struct('world', world, 'mission', mc, 'environment', env, 'sensor_config', scfg);

sf = env.irradiance_W_m2 / 850;                         % solar factor: features fade in low sun (N2)
dirt = [0.60 0.49 0.36];
kinds = [repmat("TGT_VISIBLE", 1, g.n_visible_targets), repmat("WET", 1, g.n_wet), repmat("SOIL", 1, g.n_soil), ...
    repmat("SCRAP", 1, g.n_scrap)];
if g.demo_fixture, kinds = "FIXTURE"; end
O = world.objects; taken = zeros(0, 3);                  % [x y keep-out radius]
taken = [taken; O.x_east_m O.y_north_m O.radius_m + 1.2; vertcat(lm.xy) [2.5; 2.5]];
F = mgv2.sensors.validateSurfaceFeatures([]); T = table('Size', [0 5], 'VariableTypes', ["string","double","double","string","double"], ...
    'VariableNames', ["target_id","x_east_m","y_north_m","surface_signature","burial_depth_m"]);
for k = 1:numel(kinds)
    if kinds(k) == "FIXTURE", p = [5.5 3.25];
    else
        for tries = 1:400
            p = [-17 + 34 * rand(rs), -11 + 22 * rand(rs)];
            if all(hypot(taken(:,1) - p(1), taken(:,2) - p(2)) > taken(:,3) + 1.0), break; end
        end
    end
    u = rand(rs, 1, 6); n1 = randn(rs);
    f = struct('center_enu_m', p, 'radius_m', 0, 'edge_m', 0.08, 'albedo_rgb', dirt, 'albedo_mix', 0, 'delta_T_K', 0, 'emissivity', NaN);
    switch kinds(k)
        case "TGT_VISIBLE"   % disturbed soil over a hypothetical shallow object
            f.albedo_rgb = min(dirt * (0.85 + 0.30 * u(1)), 1); f.albedo_mix = 0.35 + 0.45 * u(2); f.radius_m = 0.22 + 0.25 * u(3);
            f.delta_T_K = (0.4 + 1.6 * u(4)) * sf + 0.3 * n1;
        case "SOIL"          % bare/sun-warmed soil patch (clutter), overlapping distribution
            f.albedo_rgb = min(dirt * (0.85 + 0.30 * u(1)), 1); f.albedo_mix = 0.35 + 0.55 * u(2); f.radius_m = 0.25 + 0.50 * u(3);
            f.edge_m = 0.15; f.delta_T_K = (0.3 + 2.2 * u(4)) * sf + 0.3 * n1;
        case "WET"           % damp patch: darker, evaporatively cooler
            f.albedo_rgb = [0.30 0.30 0.22] * (0.8 + 0.4 * u(1)); f.albedo_mix = 0.30 + 0.50 * u(2); f.radius_m = 0.30 + 0.60 * u(3);
            f.edge_m = 0.20; f.delta_T_K = -(0.4 + 2.0 * u(4)) * (0.2 + sf);
        case "SCRAP"         % small bright low-emissivity scrap (appears cold in apparent temperature)
            f.albedo_rgb = [0.78 0.78 0.80]; f.albedo_mix = 0.7 + 0.3 * u(2); f.radius_m = 0.08 + 0.15 * u(3); f.edge_m = 0.03;
            f.delta_T_K = (0.5 + 2.0 * u(4)) * sf; f.emissivity = 0.25 + 0.35 * u(5);
        case "FIXTURE"       % DEMO FIXTURE: deliberately strong, excluded from every accuracy report
            f.albedo_rgb = [0.36 0.22 0.15]; f.albedo_mix = 0.9; f.radius_m = 0.40; f.delta_T_K = 3.0;
    end
    F(end+1, 1) = f; %#ok<AGROW>
    if kinds(k) == "TGT_VISIBLE" || kinds(k) == "FIXTURE"
        T(end+1, :) = {sprintf("%s-H%02d", g.group_id, height(T) + 1), p(1), p(2), "VISIBLE_DISTURBANCE", 0.05 + 0.15 * u(6)}; %#ok<AGROW>
    end
    taken(end+1, :) = [p 1.5 + f.radius_m]; %#ok<AGROW>
end
fwd = F(randperm(rs, numel(F)));                         % order carries no information
fwd = mgv2.sensors.validateSurfaceFeatures(fwd);
% no-signature hidden targets: own random stream, placed AFTER every observable feature, so their number and
% positions cannot change anything observable (counterfactual test SC-18 / EVAL-05 relies on this)
rb = RandStream('mrg32k3a', 'Seed', g.layout_seed); rb.Substream = 2;
for k = 1:g.n_blind_targets * ~g.demo_fixture
    for tries = 1:400
        p = [-17 + 34 * rand(rb), -11 + 22 * rand(rb)];
        if all(hypot(taken(:,1) - p(1), taken(:,2) - p(2)) > taken(:,3) + 1.0), break; end
    end
    T(end+1, :) = {sprintf("%s-H%02d", g.group_id, height(T) + 1), p(1), p(2), "NONE", 0.05 + 0.15 * rand(rb)}; %#ok<AGROW>
    taken(end+1, :) = [p 1.5]; %#ok<AGROW>
end
TargetTruth = struct('group_id', g.group_id, 'split', g.split, 'family', g.family, 'demo_fixture', g.demo_fixture, ...
    'targets', T, 'n_clutter_features', numel(F) - nnz(T.surface_signature == "VISIBLE_DISTURBANCE"), ...
    'builder_version', "scenario-builder-v1");
end
