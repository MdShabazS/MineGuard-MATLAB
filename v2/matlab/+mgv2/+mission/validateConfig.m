function cfg = validateConfig(cfg)
%VALIDATECONFIG Validate a V2 MissionConfig; throws mgv2:InvalidMissionConfig with a specific reason.
%   cfg = mgv2.mission.validateConfig(cfg)
%   Exact field allowlist (truth firewall, ADR-08): any field not listed, e.g. targets, truth or labels,
%   is rejected, so hidden scenario truth cannot reach navigation through the configuration.
id = 'mgv2:InvalidMissionConfig';
allowed = ["schema_version","run_id","scenario_id","seed","dt_s","bounds_enu_m","survey_polygon_enu_m", ...
    "home_enu_m","virtual_wgs84_origin","alt_agl_setpoint_m","takeoff_agl_m","speed_mps","line_spacing_m", ...
    "survey_heading_deg","preflight_s","constraints","wind","feature_flags"];
if ~isstruct(cfg) || ~isscalar(cfg), error(id, 'MissionConfig must be a scalar struct.'); end
f = string(fieldnames(cfg))';
extra = setdiff(f, allowed); missing = setdiff(allowed, f);
if ~isempty(extra), error(id, 'MissionConfig has unexpected field(s): %s (truth/target data is never accepted).', strjoin(extra, ', ')); end
if ~isempty(missing), error(id, 'MissionConfig is missing field(s): %s.', strjoin(missing, ', ')); end
if string(cfg.schema_version) ~= "mg-v2-contract/1.0", error(id, 'schema_version must be "mg-v2-contract/1.0".'); end
for s = ["run_id","scenario_id"]
    if ~(isstring(cfg.(s)) || ischar(cfg.(s))) || strlength(string(cfg.(s))) == 0, error(id, '%s must be a non-empty string.', s); end
end
pos = @(v) isnumeric(v) && isscalar(v) && isfinite(v) && v > 0;
if ~(isnumeric(cfg.seed) && isscalar(cfg.seed) && cfg.seed >= 0 && cfg.seed == round(cfg.seed) && cfg.seed < 2^32), error(id, 'seed must be an integer in [0, 2^32).'); end
if ~pos(cfg.dt_s) || cfg.dt_s > 0.2, error(id, 'dt_s must be in (0, 0.2] s for stable integration.'); end
for s = ["alt_agl_setpoint_m","takeoff_agl_m","speed_mps","line_spacing_m","preflight_s"]
    if ~pos(cfg.(s)), error(id, '%s must be a positive finite scalar.', s); end
end
b = cfg.bounds_enu_m;
if ~(isnumeric(b) && isequal(size(b), [3 2]) && all(isfinite(b), 'all') && all(b(:,2) > b(:,1))), error(id, 'bounds_enu_m must be 3x2 [min max] with max > min.'); end
P = cfg.survey_polygon_enu_m;
if ~(isnumeric(P) && size(P, 2) == 2 && size(P, 1) >= 3 && all(isfinite(P), 'all')), error(id, 'survey_polygon_enu_m must be N-by-2 (N >= 3) finite.'); end
a = polyAreaSigned(P);
if a <= 0, error(id, 'survey_polygon_enu_m must be counter-clockwise with positive area.'); end
if ~isConvex(P), error(id, 'survey_polygon_enu_m must be convex (non-convex fields need decomposition, not supported).'); end
if any(P(:,1) < b(1,1) | P(:,1) > b(1,2) | P(:,2) < b(2,1) | P(:,2) > b(2,2)), error(id, 'survey polygon lies outside the geofence bounds.'); end
h = cfg.home_enu_m;
if ~(isnumeric(h) && isequal(size(h), [1 2]) && all(isfinite(h))), error(id, 'home_enu_m must be [x_east y_north].'); end
if h(1) < b(1,1) || h(1) > b(1,2) || h(2) < b(2,1) || h(2) > b(2,2), error(id, 'home lies outside the geofence bounds.'); end
o = cfg.virtual_wgs84_origin;
if ~(isnumeric(o) && numel(o) == 3 && abs(o(1)) <= 90 && abs(o(2)) <= 180), error(id, 'virtual_wgs84_origin must be [lat lon alt].'); end
c = cfg.constraints;
need = ["max_speed_mps","max_climb_mps","max_descent_mps","max_accel_mps2","max_vert_accel_mps2","max_tilt_deg", ...
    "max_yaw_rate_dps","min_clearance_m","corridor_halfwidth_m","landing_tolerance_m","touchdown_speed_mps","arrive_tolerance_m","timeout_s"];
if ~isstruct(c) || ~isempty(setxor(string(fieldnames(c))', need)), error(id, 'constraints must have exactly: %s.', strjoin(need, ', ')); end
for s = need
    if ~pos(c.(s)), error(id, 'constraints.%s must be a positive finite scalar.', s); end
end
if cfg.speed_mps > c.max_speed_mps, error(id, 'speed_mps exceeds constraints.max_speed_mps.'); end
if c.max_tilt_deg >= 60, error(id, 'max_tilt_deg must be < 60 deg.'); end
if c.max_accel_mps2 > 9.80665 * tand(c.max_tilt_deg), error(id, 'max_accel_mps2 is not reachable within max_tilt_deg.'); end
if cfg.alt_agl_setpoint_m <= c.min_clearance_m, error(id, 'alt_agl_setpoint_m must exceed constraints.min_clearance_m.'); end
if cfg.takeoff_agl_m >= cfg.alt_agl_setpoint_m, error(id, 'takeoff_agl_m must be below alt_agl_setpoint_m.'); end
w = cfg.wind;
if ~isstruct(w) || ~isempty(setxor(string(fieldnames(w))', ["enabled","mean_enu_mps","gust_sigma_mps","gust_tau_s"])), error(id, 'wind must have enabled, mean_enu_mps, gust_sigma_mps, gust_tau_s.'); end
if ~(islogical(w.enabled) || ismember(w.enabled, [0 1])) || ~(isnumeric(w.mean_enu_mps) && numel(w.mean_enu_mps) == 3 && all(isfinite(w.mean_enu_mps))) ...
        || ~(isscalar(w.gust_sigma_mps) && w.gust_sigma_mps >= 0) || ~pos(w.gust_tau_s)
    error(id, 'wind fields are invalid.');
end
if norm(w.mean_enu_mps(1:2)) + 3*w.gust_sigma_mps >= c.max_speed_mps, error(id, 'wind is too strong for the speed limit (mission unreachable).'); end
if ~isstruct(cfg.feature_flags), error(id, 'feature_flags must be a struct.'); end
cfg.run_id = string(cfg.run_id); cfg.scenario_id = string(cfg.scenario_id); cfg.wind.enabled = logical(cfg.wind.enabled);
end

function a = polyAreaSigned(P)
x = P(:,1); y = P(:,2);
a = 0.5 * sum(x .* circshift(y, -1) - circshift(x, -1) .* y);
end

function tf = isConvex(P)
n = size(P, 1); s = zeros(n, 1);
for k = 1:n
    a = P(k,:); b = P(mod(k, n)+1, :); c = P(mod(k+1, n)+1, :);
    s(k) = (b(1)-a(1))*(c(2)-b(2)) - (b(2)-a(2))*(c(1)-b(1));
end
tf = all(s >= -1e-9);
end
