function [s, report] = validateSurvey(s, id, world)
%VALIDATESURVEY Check a SurveySpec against a preset and the V2 planner; throws mgv21:InvalidSurvey with the reason.
%   [s, report] = mgv21.scenario.validateSurvey(s, id)          geometry, settings, V2 validator and planner
%   [s, report] = mgv21.scenario.validateSurvey(s, id, world)   + terrain clearance against the geofence
%   s       SurveySpec (mg-v21-survey/1.0), returned NORMALISED: counter-clockwise polygon, a repeated closing
%           vertex removed, heading in [0, 360), double values.
%   report  preset_id, area_m2, n_lines, survey_length_m, est_flight_s, flight_budget_s, polygon_reordered,
%           closing_vertex_dropped, terrain_checked, terrain_z_range_m, mission (validated V2 MissionConfig),
%           plan (mgv2.mission.planSurvey output).
%   Rejected (never repaired): non-finite values, < 3 or > 32 vertices, repeated vertices, self-intersecting or
%   non-convex boundaries (the V2 planner is convex-only), area < 400 m^2, a boundary or home outside the terrain
%   extent or geofence, out-of-range spacing/altitude/speed, a route whose estimated flight exceeds 80 % of the
%   V2 timeout, and anything the V2 validator or planner refuses. A "RECTANGLE" must be an axis-aligned
%   rectangle. With a world, the highest ground under the boundary or home plus altitude plus 5 m must stay
%   below the geofence ceiling and the lowest ground above its floor.
if nargin < 3, world = []; end
id_ = 'mgv21:InvalidSurvey';
c = mgv21.contract(); L = c.limits;
p = mgv21.scenario.environmentPreset(id);
want = ["schema_version","boundary_kind","polygon_enu_m","home_enu_m","line_spacing_m","heading_deg","alt_agl_m","speed_mps"];
if ~(isstruct(s) && isscalar(s)) || ~isempty(setxor(string(fieldnames(s))', want))
    error(id_, 'SurveySpec fields must be exactly: %s.', strjoin(want, ", "));
end
if string(s.schema_version) ~= c.schemas.survey, error(id_, 'schema_version must be "%s".', c.schemas.survey); end
kind = string(s.boundary_kind);
if ~(isscalar(kind) && ismember(kind, c.boundary_kinds)), error(id_, 'boundary_kind must be RECTANGLE or POLYGON.'); end
s.boundary_kind = kind;

% --- polygon geometry -------------------------------------------------------------------------------
P = s.polygon_enu_m;
if ~(isnumeric(P) && ismatrix(P) && size(P, 2) == 2 && all(isfinite(P), 'all'))
    error(id_, 'polygon_enu_m must be an N-by-2 matrix of finite ENU metres.');
end
P = double(P); dropped = false;
if size(P, 1) > 3 && norm(P(1,:) - P(end,:)) < L.min_vertex_gap_m, P(end, :) = []; dropped = true; end
n = size(P, 1);
if n < L.polygon_vertices(1) || n > L.polygon_vertices(2)
    error(id_, 'The boundary needs %d to %d vertices (got %d).', L.polygon_vertices(1), L.polygon_vertices(2), n);
end
for i = 1:n
    for j = i+1:n
        if norm(P(i,:) - P(j,:)) < L.min_vertex_gap_m
            error(id_, 'Vertices %d and %d are closer than %.1f m (repeated vertex).', i, j, L.min_vertex_gap_m);
        end
    end
end
if selfIntersects(P), error(id_, 'The boundary crosses itself (self-intersecting polygon).'); end
a = 0.5 * sum(P(:,1) .* circshift(P(:,2), -1) - circshift(P(:,1), -1) .* P(:,2));
reordered = a < 0;
if reordered, P = flipud(P); a = -a; end
if a < L.min_area_m2, error(id_, 'The boundary area %.1f m^2 is below the minimum %.0f m^2.', a, L.min_area_m2); end
if ~isConvexCCW(P)
    error(id_, 'The boundary is not convex. The V2 survey planner supports convex areas only; split it or draw a convex boundary.');
end
if kind == "RECTANGLE" && ~isAxisRectangle(P)
    error(id_, 'boundary_kind RECTANGLE needs 4 vertices of an axis-aligned rectangle (use POLYGON otherwise).');
end
e = p.scene_config.extent_enu_m; m = L.extent_margin_m; b = p.bounds_enu_m;
if any(P(:,1) < e(1,1) + m | P(:,1) > e(1,2) - m | P(:,2) < e(2,1) + m | P(:,2) > e(2,2) - m)
    error(id_, 'The boundary must stay at least %.0f m inside the terrain extent [%g %g] x [%g %g] m.', m, e(1,1), e(1,2), e(2,1), e(2,2));
end
if any(P(:,1) < b(1,1) | P(:,1) > b(1,2) | P(:,2) < b(2,1) | P(:,2) > b(2,2))
    error(id_, 'The boundary lies outside the geofence.');
end
s.polygon_enu_m = P;

% --- home and grid settings ---------------------------------------------------------------------------
h = s.home_enu_m; pad = p.scene_config.home_pad_m;
if ~(isnumeric(h) && numel(h) == 2 && all(isfinite(h))), error(id_, 'home_enu_m must be finite [x_east y_north].'); end
h = double(h(:)');
if ~(h(1) > e(1,1) + pad && h(1) < e(1,2) - pad && h(2) > e(2,1) + pad && h(2) < e(2,2) - pad) ...
        || h(1) < b(1,1) || h(1) > b(1,2) || h(2) < b(2,1) || h(2) > b(2,2)
    error(id_, 'Home must lie inside the terrain extent (with its %g m pad) and inside the geofence.', pad);
end
s.home_enu_m = h;
s.line_spacing_m = scalarIn(s.line_spacing_m, L.line_spacing_m, 'line_spacing_m', id_);
s.alt_agl_m = scalarIn(s.alt_agl_m, L.alt_agl_m, 'alt_agl_m', id_);
if ~(isnumeric(s.heading_deg) && isscalar(s.heading_deg) && isfinite(s.heading_deg)), error(id_, 'heading_deg must be a finite scalar.'); end
s.heading_deg = mod(double(s.heading_deg), 360);
v2c = mgv2.mission.defaultConfig().constraints;
s.speed_mps = scalarIn(s.speed_mps, [0 v2c.max_speed_mps], 'speed_mps', id_);
if s.speed_mps <= 0, error(id_, 'speed_mps must be positive.'); end
if s.alt_agl_m - L.max_object_height_m < v2c.min_clearance_m
    error(id_, 'alt_agl_m leaves less than %g m clearance over %.1f m objects.', v2c.min_clearance_m, L.max_object_height_m);
end
s.schema_version = c.schemas.survey;

% --- V2 validator, planner and flight-time estimate ---------------------------------------------------
mc = missionFor(s, p, "V21RUN-CHECK", 0);
try
    plan = mgv2.mission.planSurvey(mc);
catch err
    error(id_, 'The V2 survey planner refused this route: %s', err.message);
end
wp = plan.waypoints_xy; cc = mc.constraints; v = s.speed_mps;
turn_s = 2 * v / cc.max_accel_mps2;                         % decelerate + re-accelerate at each line end
est = mc.preflight_s + s.alt_agl_m / cc.max_climb_mps + norm(wp(1,:) - h) / v + plan.survey_length_m / v ...
    + plan.n_lines * turn_s + norm(wp(end,:) - h) / v + s.alt_agl_m / cc.max_descent_mps;
budget = L.timeout_fraction * cc.timeout_s;
if est > budget
    error(id_, 'Estimated flight %.0f s exceeds the %.0f s budget (%.0f %% of the %g s timeout); widen the spacing, raise the speed or shrink the boundary.', ...
        est, budget, 100 * L.timeout_fraction, cc.timeout_s);
end

% --- terrain clearance (optional) ----------------------------------------------------------------------
zr = [NaN NaN];
if ~isempty(world)
    if ~(isstruct(world) && isfield(world, 'config') && isequal(world.config.seed, p.scene_config.seed) ...
            && isequal(world.config.extent_enu_m, e))
        error(id_, 'The world does not belong to preset %s.', p.preset_id);
    end
    [X, Y] = meshgrid(world.x, world.y);
    in = inpolygon(X, Y, P(:,1), P(:,2));
    z = [world.Z(in); mgv2.scene.heightAt(world, P(:,1), P(:,2)); mgv2.scene.heightAt(world, h(1), h(2))];
    zr = [min(z) max(z)];
    if zr(2) + s.alt_agl_m + L.ceiling_margin_m > b(3,2)
        error(id_, 'Ground up to %.1f m + %.1f m altitude + %g m margin exceeds the geofence ceiling %g m.', zr(2), s.alt_agl_m, L.ceiling_margin_m, b(3,2));
    end
    if zr(1) < b(3,1), error(id_, 'Ground down to %.1f m lies below the geofence floor %g m.', zr(1), b(3,1)); end
end
report = struct('preset_id', p.preset_id, 'area_m2', a, 'n_lines', plan.n_lines, 'survey_length_m', plan.survey_length_m, ...
    'est_flight_s', est, 'flight_budget_s', budget, 'polygon_reordered', reordered, 'closing_vertex_dropped', dropped, ...
    'terrain_checked', ~isempty(world), 'terrain_z_range_m', zr, 'mission', mc, 'plan', plan);
end

function x = scalarIn(x, lim, name, id_)
if ~(isnumeric(x) && isscalar(x) && isfinite(x) && x >= lim(1) && x <= lim(2))
    error(id_, '%s must be a finite scalar in [%g, %g].', name, lim(1), lim(2));
end
x = double(x);
end

function tf = selfIntersects(P)
n = size(P, 1); tf = false;
for i = 1:n
    a1 = P(i,:); a2 = P(mod(i, n) + 1, :);
    for j = i+1:n
        if j == i + 1 || (i == 1 && j == n), continue; end   % adjacent edges share a vertex
        b1 = P(j,:); b2 = P(mod(j, n) + 1, :);
        if segmentsTouch(a1, a2, b1, b2), tf = true; return; end
    end
end
end

function tf = segmentsTouch(p1, p2, q1, q2)
o = @(a, b, c) (b(1) - a(1)) * (c(2) - a(2)) - (b(2) - a(2)) * (c(1) - a(1));
on = @(a, b, c) min(a(1), b(1)) - 1e-9 <= c(1) && c(1) <= max(a(1), b(1)) + 1e-9 && min(a(2), b(2)) - 1e-9 <= c(2) && c(2) <= max(a(2), b(2)) + 1e-9;
d1 = o(q1, q2, p1); d2 = o(q1, q2, p2); d3 = o(p1, p2, q1); d4 = o(p1, p2, q2);
tf = (d1 * d2 < 0 && d3 * d4 < 0) || (abs(d1) < 1e-9 && on(q1, q2, p1)) || (abs(d2) < 1e-9 && on(q1, q2, p2)) ...
    || (abs(d3) < 1e-9 && on(p1, p2, q1)) || (abs(d4) < 1e-9 && on(p1, p2, q2));
end

function tf = isConvexCCW(P)
n = size(P, 1); s = zeros(n, 1);
for k = 1:n
    a = P(k,:); b = P(mod(k, n) + 1, :); c = P(mod(k + 1, n) + 1, :);
    s(k) = (b(1) - a(1)) * (c(2) - b(2)) - (b(2) - a(2)) * (c(1) - b(1));
end
tf = all(s >= -1e-9);
end

function tf = isAxisRectangle(P)
tf = size(P, 1) == 4 && numel(unique(round(P(:,1), 9))) == 2 && numel(unique(round(P(:,2), 9))) == 2;
end
