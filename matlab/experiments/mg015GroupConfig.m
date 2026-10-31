function [c, row] = mg015GroupConfig(groupId, detectorSettings)
%MG015GROUPCONFIG Build the ExperimentConfig for one MG-014 locked scenario family (GF-001..GF-030).
%   [c, row] = mg015GroupConfig(groupId)
%   [c, row] = mg015GroupConfig(groupId, detectorSettings)
%   Applies base_experiment_config plus the named profile to the EXACT manifest row in
%   experiments/locked/mg014_scenario_manifest.json (MG-014 §2, protocol 1). Seeds, IDs and
%   profiles are read, never changed. Sensor settings are the documented MG-007 fixture
%   (mg007FixtureSettings). The manifest file is read-only here.
%   The profile and the target/clutter counts reach only the GENERATOR (MG-004 config); runExperiment
%   never passes them to navigation, detection or the dashboard.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
M = jsondecode(fileread(fullfile(root, 'experiments', 'locked', 'mg014_scenario_manifest.json')));
g = M.groups(strcmp({M.groups.group_id}, char(groupId)));
if numel(g) ~= 1
    error('mineguard:InvalidExperimentConfig', 'Unknown MG-014 group "%s".', groupId);
end
pr = M.profile_definitions(strcmp({M.profile_definitions.id}, g.profile_id));
b = M.base_experiment_config;
c = struct('schema_version', string(b.schema_version), 'scenario_id', string(g.scenario_id), 'seed', g.seed, ...
    'x_min_m', b.x_min_m, 'x_max_m', b.x_max_m, 'y_min_m', b.y_min_m, 'y_max_m', b.y_max_m, ...
    'terrain_id', string(b.terrain_id), 'grid_spacing_m', b.grid_spacing_m, 'dt_s', b.dt_s, 'sampling_hz', b.sampling_hz, ...
    'altitude_m', pr.altitude_m, 'speed_mps', b.speed_mps, 'noise_seed', g.noise_seed, ...
    'target_count', pr.target_count, 'clutter_count', pr.clutter_count, 'min_separation_m', b.min_separation_m, ...
    'soil_class', string(b.soil_class), 'model_version', string(b.model_version));
c.sensor_settings = mg007FixtureSettings();
if nargin > 1
    c.detector_settings = detectorSettings;
end
c.run_options = struct('split_id', string(g.split_id), 'group_id', string(g.group_id), 'evaluate', true);
row = g;
end
