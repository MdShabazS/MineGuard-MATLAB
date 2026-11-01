function env = defaultEnvironment(mode)
%DEFAULTENVIRONMENT Synthetic environment for the V2-005 forward models (ASSUMED values, not measured).
%   env = mgv2.sensors.defaultEnvironment()            "DAY_CLEAR"
%   env = mgv2.sensors.defaultEnvironment("LOW_CONTRAST")   dawn: weak sun, small surface contrast (N2)
%   env = mgv2.sensors.defaultEnvironment("OVERCAST")
%   Fields: mode, ambient_K, sky_K (effective clear-sky radiant temperature), reflected_K, atm_K,
%   sun_azimuth_deg (from North, clockwise), sun_elevation_deg, irradiance_W_m2 (normal-incidence
%   solar), wind_mps, extinction_per_m (path transmittance tau = exp(-k r)), moisture_amp_K,
%   moisture_seed. All values are documented engineering assumptions for a synthetic scene.
if nargin < 1, mode = "DAY_CLEAR"; end
env = struct('mode', string(mode), 'ambient_K', 295.15, 'sky_K', 265.0, 'reflected_K', 280.0, 'atm_K', 295.15, ...
    'sun_azimuth_deg', 135, 'sun_elevation_deg', 50, 'irradiance_W_m2', 850, 'wind_mps', 2.0, ...
    'extinction_per_m', 0.0013, 'moisture_amp_K', 1.5, 'moisture_seed', 5005);
switch string(mode)
    case "DAY_CLEAR"
    case "LOW_CONTRAST"
        env.ambient_K = 286.15; env.sky_K = 278.0; env.reflected_K = 284.0; env.atm_K = 286.15;
        env.sun_elevation_deg = 4; env.irradiance_W_m2 = 60; env.moisture_amp_K = 0.3;
    case "OVERCAST"
        env.sky_K = 285.0; env.reflected_K = 290.0; env.irradiance_W_m2 = 150; env.sun_elevation_deg = 40;
    otherwise
        error('mgv2:InvalidSensorConfig', 'Unknown environment mode "%s".', string(mode));
end
end
