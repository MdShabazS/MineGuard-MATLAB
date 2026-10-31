function navConfig = navigationConfigFromExperiment(config, varargin)
%NAVIGATIONCONFIGFROMEXPERIMENT Orchestrator projection: ExperimentConfig -> NavigationConfig.
%   navConfig = mineguard.navigation.navigationConfigFromExperiment(config)
%   navConfig = ...(config, 'virtual_origin_lat_deg', lat0, 'virtual_origin_lon_deg', lon0, 'gps_sigma_m', s)
%
%   Copies ONLY the whitelisted navigation fields (mg-contract/1.0 Section 2).
%   Counts, soil, generator settings and truth are never copied. The navigation seed is
%   derived from noise_seed with the same rule MG-004 records in environment.rng.navigation_seed.
keep = ["schema_version","scenario_id","grid_spacing_m","dt_s","altitude_m","speed_mps"];
if ~isstruct(config) || ~isscalar(config) || ~all(isfield(config, [keep "noise_seed"]))
    error('mineguard:InvalidNavigationConfig', ...
        'MineGuard navigation: config must be an ExperimentConfig with %s and noise_seed.', strjoin(keep, ', '));
end
navConfig = struct();
for f = keep
    navConfig.(f) = config.(f);
end
navConfig.seed = mod(double(config.noise_seed) + 3 * 1000003, 2^32);
optional = ["virtual_origin_lat_deg","virtual_origin_lon_deg","gps_sigma_m"];
if mod(numel(varargin), 2) ~= 0
    error('mineguard:InvalidNavigationConfig', 'MineGuard navigation: optional arguments must be name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = string(varargin{k});
    if ~ismember(name, optional)
        error('mineguard:InvalidNavigationConfig', 'MineGuard navigation: unknown option "%s".', name);
    end
    navConfig.(name) = varargin{k+1};
end
navConfig = validateNavConfig(navConfig);
end
