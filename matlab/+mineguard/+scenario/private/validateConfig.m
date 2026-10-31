function config = validateConfig(config)
%VALIDATECONFIG Check an ExperimentConfig (mg-contract/1.0) and normalise text fields to string.
%   Invalid input throws mineguard:InvalidScenario. Nothing is clipped silently.
if ~isstruct(config) || ~isscalar(config)
    invalidScenario('config must be a scalar ExperimentConfig struct.');
end
required = ["schema_version","scenario_id","seed","x_min_m","x_max_m","y_min_m","y_max_m", ...
    "terrain_id","grid_spacing_m","dt_s","sampling_hz","altitude_m","speed_mps","noise_seed", ...
    "target_count","clutter_count","min_separation_m","soil_class","model_version"];
missing = required(~isfield(config, required));
if ~isempty(missing)
    invalidScenario('config is missing required field(s): %s.', strjoin(missing, ', '));
end

textFields = ["schema_version","scenario_id","terrain_id","soil_class","model_version"];
for f = textFields
    v = config.(f);
    if ~((ischar(v) && (isrow(v) || isempty(v))) || (isstring(v) && isscalar(v))) || ismissing(string(v)) || strlength(strtrim(string(v))) == 0
        invalidScenario('config.%s must be a nonempty text scalar.', f);
    end
    config.(f) = string(v);
end
if config.schema_version ~= "mg-contract/1.0"
    invalidScenario('config.schema_version must be "mg-contract/1.0" (got "%s").', config.schema_version);
end

numFields = setdiff(required, textFields, 'stable');
for f = numFields
    v = config.(f);
    if ~(isnumeric(v) && isreal(v) && isscalar(v)) || ~isfinite(v)
        invalidScenario('config.%s must be a finite real numeric scalar (NaN/Inf rejected).', f);
    end
    config.(f) = double(v);
end

% RandStream (mt19937ar) accepts seeds in [0, 2^32-1].
if config.seed < 0 || config.seed ~= fix(config.seed) || config.seed > 2^32-1
    invalidScenario('config.seed must be an integer in [0, 2^32-1] (got %g).', config.seed);
end
if config.noise_seed ~= fix(config.noise_seed)
    invalidScenario('config.noise_seed must be an integer (got %g).', config.noise_seed);
end
if ~(config.x_min_m < config.x_max_m)
    invalidScenario('config.x_min_m (%g) must be strictly less than config.x_max_m (%g).', config.x_min_m, config.x_max_m);
end
if ~(config.y_min_m < config.y_max_m)
    invalidScenario('config.y_min_m (%g) must be strictly less than config.y_max_m (%g).', config.y_min_m, config.y_max_m);
end
for f = ["grid_spacing_m","dt_s","sampling_hz","speed_mps"]
    if config.(f) <= 0
        invalidScenario('config.%s must be positive (got %g).', f, config.(f));
    end
end
for f = ["altitude_m","min_separation_m"]
    if config.(f) < 0
        invalidScenario('config.%s must be nonnegative (got %g).', f, config.(f));
    end
end
for f = ["target_count","clutter_count"]
    if config.(f) < 0 || config.(f) ~= fix(config.(f))
        invalidScenario('config.%s must be a nonnegative integer (got %g).', f, config.(f));
    end
end

% Optional extension (not in the frozen required list): exclusion polygons.
if isfield(config, 'exclusion_polygons_enu_m')
    bounds = [config.x_min_m config.x_max_m config.y_min_m config.y_max_m];
    checkExclusions(config.exclusion_polygons_enu_m, bounds, 'config.exclusion_polygons_enu_m');
end
end
