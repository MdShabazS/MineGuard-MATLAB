function poses = simulatePose(navConfig, geometry, route)
%SIMULATEPOSE Kinematic virtual telemetry along a route (mg-contract/1.0, MG-005).
%   poses = mineguard.navigation.simulatePose(navConfig, geometry, route)
%
%   Returns a typed PoseSample table. Kinematic assumptions (documented baseline, not a
%   flight-dynamics model):
%     - point mass at constant speed navConfig.speed_mps along straight legs
%     - instantaneous turns at waypoints, constant altitude, roll = pitch = 0
%     - yaw_rad is the ENU heading, measured counter-clockwise from east
%     - samples every dt_s from t_s = 0, plus a final sample at route end
%   Virtual geotags (when a virtual origin is configured) use a flat-earth projection
%   with radius 6378137 m. Optional Gaussian noise gps_sigma_m is drawn from a local
%   RandStream(navConfig.seed). They are SYNTHETIC coordinates, never real GNSS.
navConfig = validateNavConfig(navConfig);
[bounds, polys] = validateGeometry(geometry);
id = 'mineguard:InvalidNavigationInput';
if ~(isnumeric(route) && isreal(route) && ismatrix(route) && size(route,2) == 3 && size(route,1) >= 1) || any(~isfinite(route(:)))
    error(id, 'MineGuard navigation: route must be a finite Nx3 [x_east_m y_north_m z_up_m] array.');
end
route = double(route);
tol = 1e-9;
if any(route(:,1) < bounds(1)-tol | route(:,1) > bounds(2)+tol | route(:,2) < bounds(3)-tol | route(:,2) > bounds(4)+tol)
    error(id, 'MineGuard navigation: route has waypoints outside geometry.bounds_enu_m.');
end
if any(route(:,3) < 0)
    error(id, 'MineGuard navigation: route z_up_m must be nonnegative.');
end
if any(insidePolys(route(:,1), route(:,2), polys))
    error(id, 'MineGuard navigation: route has waypoints inside an exclusion polygon.');
end
legs = diff(route, 1, 1);
legLen = sqrt(sum(legs.^2, 2));
if any(legLen == 0)
    error(id, 'MineGuard navigation: route has consecutive duplicate waypoints.');
end

v = navConfig.speed_mps;
dt = navConfig.dt_s;
cumDist = [0; cumsum(legLen)];
total = cumDist(end);
tEnd = total / v;
maxSamples = 2e6;
if tEnd / dt + 2 > maxSamples
    error(id, 'MineGuard navigation: route needs more than %d samples; increase dt_s or reduce the area.', maxSamples);
end
t = (0:floor(tEnd / dt + 1e-9))' * dt;
if t(end) < tEnd - 1e-9
    t(end+1) = tEnd;
end
n = numel(t);
d = min(v * t, total);

% Leg index for each sample: leg k spans cumDist(k)..cumDist(k+1).
nLegs = size(legs, 1);
if nLegs == 0
    xyz = repmat(route, n, 1); yaw = zeros(n,1); wp = ones(n,1);
else
    leg = discretize(d, cumDist);
    leg(isnan(leg)) = nLegs;
    leg = min(leg, nLegs);
    frac = (d - cumDist(leg)) ./ legLen(leg);
    xyz = route(leg,:) + frac .* legs(leg,:);
    yaw = atan2(legs(leg,2), legs(leg,1));
    wp = leg + 1;   % waypoint currently being flown to
end

state = repmat("SURVEY", n, 1);
state(1) = "INIT";
state(end) = "COMPLETE";

if isfield(navConfig, 'virtual_origin_lat_deg')
    sigma = 0;
    if isfield(navConfig, 'gps_sigma_m')
        sigma = navConfig.gps_sigma_m;
    end
    stream = RandStream('mt19937ar', 'Seed', navConfig.seed);
    noise = sigma * randn(stream, n, 2);
    R = 6378137;
    lat0 = navConfig.virtual_origin_lat_deg;
    lon0 = navConfig.virtual_origin_lon_deg;
    vlat = lat0 + rad2deg((xyz(:,2) + noise(:,2)) / R);
    vlon = lon0 + rad2deg((xyz(:,1) + noise(:,1)) / (R * cosd(lat0)));
    gpsSigma = repmat(sigma, n, 1);
else
    vlat = NaN(n,1); vlon = NaN(n,1); gpsSigma = NaN(n,1);
end

poses = table( ...
    compose("P-%06d", (1:n)'), t, xyz(:,1), xyz(:,2), xyz(:,3), zeros(n,1), zeros(n,1), yaw, ...
    vlat, vlon, gpsSigma, compose("WP-%04d", wp), state, ...
    'VariableNames', {'pose_sample_id','t_s','x_east_m','y_north_m','z_up_m','roll_rad','pitch_rad', ...
    'yaw_rad','virtual_lat_deg','virtual_lon_deg','gps_sigma_m','waypoint_id','mission_state'});
end
