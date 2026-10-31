function c = mg013ScenarioConfig(seed, scenarioId)
%MG013SCENARIOCONFIG ExperimentConfig for one MG-013 PPO coverage scenario (geometry only).
%   10x10 m flat field, 2 m cells (5x5 = 25 cells), 2 m/s, altitude 2 m, dt 0.1 s.
%   0, 1 or 2 rectangular no-fly zones (1.2-3.0 m sides), drawn from a local RandStream(seed).
%   Every zone has x_min >= 2 and y_min >= 2, so the shared SW start cell is never excluded.
%   target_count = clutter_count = 0: the PPO coverage task uses NO objects or truth at all.
s = RandStream('mt19937ar', 'Seed', seed);
n = randi(s, [0 2]);
polys = cell(1, n);
for k = 1:n
    w = 1.2 + 1.8 * rand(s); h = 1.2 + 1.8 * rand(s);
    x0 = 2 + (8 - w) * rand(s); y0 = 2 + (8 - h) * rand(s);
    polys{k} = [x0 y0; x0 + w y0; x0 + w y0 + h; x0 y0 + h];
end
c = struct('schema_version', "mg-contract/1.0", 'scenario_id', string(scenarioId), 'seed', seed, ...
    'x_min_m', 0, 'x_max_m', 10, 'y_min_m', 0, 'y_max_m', 10, 'terrain_id', "flat-datum", 'grid_spacing_m', 2, ...
    'dt_s', 0.1, 'sampling_hz', 10, 'altitude_m', 2, 'speed_mps', 2, 'noise_seed', seed + 50000, ...
    'target_count', 0, 'clutter_count', 0, 'min_separation_m', 0.5, 'soil_class', "synthetic_loam", ...
    'model_version', "mg013-scenario-1.0", 'exclusion_polygons_enu_m', {polys});
end
