function [ch, ctx] = prepareSensorRun(config, scenario, poses, channel)
%PREPARESENSORRUN Shared input validation for the MG-007 forward sensor models.
%   [ch, ctx] = prepareSensorRun(config, scenario, poses, channel), with channel
%   "thermal" or "em".
%   ch  - config.sensor_settings.(channel), or [] when the channel is not configured
%         (every row is then marked UNCONFIGURED_SENSOR; no parameter is invented).
%   ctx - truth objects, ground datum, pose validity mask, channel seed and run metadata.
%   Structural input errors throw mineguard:InvalidSensorInput. The inputs are never modified.
inErr = 'mineguard:InvalidSensorInput';
if ~isstruct(config) || ~isscalar(config) || ~isfield(config, 'schema_version') || string(config.schema_version) ~= "mg-contract/1.0"
    error(inErr, 'MineGuard sensors: config must be an mg-contract/1.0 ExperimentConfig struct.');
end
need = ["geometry","hidden_truth","environment"];
if ~isstruct(scenario) || ~isscalar(scenario) || ~all(isfield(scenario, need))
    error(inErr, 'MineGuard sensors: scenario must be the restricted Scenario struct with fields %s.', strjoin(need, ', '));
end
truth = scenario.hidden_truth;
if ~istable(truth) || ~all(ismember({'x_east_m','y_north_m','burial_depth_m','material_type'}, truth.Properties.VariableNames))
    error(inErr, 'MineGuard sensors: scenario.hidden_truth must be a TargetTruth table.');
end
if any(~isfinite([truth.x_east_m; truth.y_north_m; truth.burial_depth_m])) || any(truth.burial_depth_m < 0)
    error(inErr, 'MineGuard sensors: hidden truth coordinates must be finite with burial_depth_m >= 0.');
end
g = scenario.geometry;
if ~isstruct(g) || ~isfield(g, 'bounds_enu_m') || ~isfield(g, 'terrain_model') || ~isfield(g, 'exclusion_polygons_enu_m')
    error(inErr, 'MineGuard sensors: scenario.geometry must be a ScenarioGeometry.');
end
tm = g.terrain_model;
if ~isstruct(tm) || ~isfield(tm, 'type') || string(tm.type) ~= "flat" || ~isfield(tm, 'datum_height_m') || ~isfinite(tm.datum_height_m)
    error(inErr, 'MineGuard sensors: only the flat terrain model (MG-004 S0) is supported by this MG-007 baseline.');
end

% PoseSample checks: unique IDs, finite nondecreasing time.
reqPose = {'pose_sample_id','t_s','x_east_m','y_north_m','z_up_m'};
if ~istable(poses) || ~all(ismember(reqPose, poses.Properties.VariableNames))
    error(inErr, 'MineGuard sensors: poses must be a PoseSample table with %s.', strjoin(reqPose, ', '));
end
ids = string(poses.pose_sample_id);
if any(ismissing(ids)) || any(strlength(ids) == 0) || numel(unique(ids)) ~= numel(ids)
    error(inErr, 'MineGuard sensors: pose_sample_id values must be unique nonempty strings.');
end
t = poses.t_s;
if ~isa(t, 'double') || any(~isfinite(t)) || any(diff(t) < 0)
    error(inErr, 'MineGuard sensors: pose t_s must be finite and nondecreasing.');
end

% Channel seed from the MG-004 environment (no global RNG is used).
env = scenario.environment;
seedName = channel + "_seed";
if ~isstruct(env) || ~isfield(env, 'rng') || ~isfield(env.rng, seedName)
    error(inErr, 'MineGuard sensors: scenario.environment.rng.%s is required (MG-004 derived seed).', seedName);
end
seed = env.rng.(seedName);
if ~(isnumeric(seed) && isscalar(seed) && isfinite(seed) && seed >= 0 && seed == fix(seed) && seed <= 2^32-1)
    error(inErr, 'MineGuard sensors: environment.rng.%s must be an integer in [0, 2^32-1].', seedName);
end

% Channel settings: absent means UNCONFIGURED. Present means validated by the model.
ch = [];
if isfield(config, 'sensor_settings')
    ss = config.sensor_settings;
    if ~isstruct(ss) || ~isscalar(ss) || ~isfield(ss, 'version') || strlength(string(ss.version)) == 0
        error('mineguard:InvalidSensorConfig', 'MineGuard sensors: config.sensor_settings must be a struct with a nonempty version.');
    end
    if isfield(ss, channel)
        ch = ss.(channel);
        if ~isstruct(ch) || ~isscalar(ch)
            error('mineguard:InvalidSensorConfig', 'MineGuard sensors: config.sensor_settings.%s must be a scalar struct.', channel);
        end
    end
end

% Pose validity: finite position, inside bounds, outside exclusions, nonnegative clearance.
b = double(g.bounds_enu_m);
x = poses.x_east_m; y = poses.y_north_m; z = poses.z_up_m;
standoff = z - tm.datum_height_m;
poseOk = isfinite(x) & isfinite(y) & isfinite(z) & x >= b(1) & x <= b(2) & y >= b(3) & y <= b(4) & standoff >= 0;
polys = g.exclusion_polygons_enu_m;
for k = 1:numel(polys)
    poseOk = poseOk & ~inpolygon(x, y, polys{k}(:,1), polys{k}(:,2));
end

ctx = struct('truth', truth, 'standoff', standoff, 'poseOk', poseOk, 'seed', double(seed), ...
    'ids', ids, 't', t, 'x', x, 'y', y, 'n', height(poses));
end
