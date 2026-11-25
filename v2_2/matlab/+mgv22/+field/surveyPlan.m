function P = surveyPlan(fieldLL, opts)
%SURVEYPLAN Turn a field drawn on the BITM view into a flyable V2.1 survey (SIMULATION only).
%   P = mgv22.field.surveyPlan(fieldLL)
%   P = mgv22.field.surveyPlan(fieldLL, AllowHull=true, MaxAreaM2=5000, ...)
%   fieldLL  N-by-2 [lat lon] degrees drawn by the operator anywhere in the BITM satellite view.
%   The ENU frame is centred on the field (anchor = mean vertex lat/lon, height 0), so any field in the view
%   fits the V2.1 preset terrain extent. Checks: mgv22.cutfill.validateOutline (mgv22:InvalidOutline),
%   convexity (mgv22:NonConvexField unless AllowHull), area (mgv22:FieldTooLarge / mgv22:FieldTooSmall),
%   extent from the anchor (mgv22:FieldTooLarge), then the V2.1 validator and planner
%   (mgv21:InvalidSurvey is rethrown as mgv22:FieldNotFlyable with the V2.1 reason).
%   Altitude: the HIGHEST altitude in the V2.1 range [6, 60] m (0.1 m steps) at which a target of
%   TargetDiameterM still spans MinPixelsOnTarget RGB pixels (GSD = 2*alt*tan(hfov/2)/width_px); if even
%   6 m is too coarse, 6 m is used and pixels_rule_met = false. Swath = min(RGB, thermal) footprint width;
%   line spacing = swath*(1-SideOverlap) clamped to [2, 30] m. Home sits 8 m south of the southernmost vertex.
%   P fields: field_anchor_lla, poly_enu, poly_ll, area_m2, area_ha, hull_used, alt_m, gsd_rgb_cm,
%   gsd_thermal_cm, pixels_on_target, pixels_rule_met, swath_m, spacing_m, speed_mps, heading_deg,
%   home_enu_m, pub (PublicMissionConfig, no truth), route_enu, route_ll, n_lines, est_flight_s, est_ticks,
%   label. All values come from simulation models; nothing here is a hazard finding.
arguments
    fieldLL
    opts.Site = mgv22.siteConfig()
    opts.Preset = "TRAINING_FIELD_A"
    opts.MaxAreaM2 (1,1) double {mustBePositive} = 5000
    opts.AllowHull (1,1) logical = false
    opts.MinPixelsOnTarget (1,1) double {mustBePositive} = 5
    opts.TargetDiameterM (1,1) double {mustBePositive} = mgv2.detect.defaultDetectorConfig().size.min_diameter_m
    opts.SideOverlap (1,1) double {mustBeNonnegative} = 0.75
    opts.SpeedMps (1,1) double {mustBePositive} = 3
    opts.HeadingDeg double = []
end
if ~(isnumeric(fieldLL) && ismatrix(fieldLL) && size(fieldLL, 2) == 2 && size(fieldLL, 1) >= 3 && all(isfinite(fieldLL), 'all'))
    error('mgv22:InvalidOutline', 'The field must be an N-by-2 [lat lon] array of at least 3 finite points.');
end
fieldLL = double(fieldLL);
w = opts.Site.view_window;                    % the field must lie in the BITM view, not somewhere panned to
if any(fieldLL(:, 1) < w.lat(1) | fieldLL(:, 1) > w.lat(2) | fieldLL(:, 2) < w.lon(1) | fieldLL(:, 2) > w.lon(2))
    error('mgv22:FieldOutsideView', 'The field must lie inside the BITM view window (lat %.4f–%.4f, lon %.4f–%.4f); draw it on the campus.', ...
        w.lat(1), w.lat(2), w.lon(1), w.lon(2));
end
if opts.SideOverlap >= 1, error('mgv22:InvalidOutline', 'SideOverlap must be in [0, 1).'); end
c21 = mgv21.contract(); L = c21.limits;
pre = mgv21.scenario.environmentPreset(opts.Preset);

% --- field in a field-centred ENU frame ----------------------------------------------------------------
anchor = [mean(fieldLL(:,1)), mean(fieldLL(:,2)), 0];
enu = mgv22.geo.wgs84ToEnu([fieldLL, zeros(size(fieldLL, 1), 1)], anchor);
poly = mgv22.cutfill.validateOutline(enu(:, 1:2));         % CCW; mgv22:InvalidOutline passes through
hull = false;
if ~isConvexCCW(poly)
    if ~opts.AllowHull
        error('mgv22:NonConvexField', ['The drawn field is not convex. V2.1 surveys need a convex field: ' ...
            'redraw it as a convex shape, or allow its convex hull (AllowHull=true) after confirming the larger area.']);
    end
    k = convhull(poly(:,1), poly(:,2));                     % closed, counter-clockwise
    poly = poly(k(1:end-1), :); hull = true;
end
area = polyArea(poly);
if area > opts.MaxAreaM2
    error('mgv22:FieldTooLarge', ['The field is %.0f m^2 (%.2f ha); the limit is %.0f m^2 so the simulated ' ...
        'run stays short (run time grows with area). Draw a smaller field.'], area, area/1e4, opts.MaxAreaM2);
end
if area < L.min_area_m2
    error('mgv22:FieldTooSmall', 'The field is %.0f m^2; V2.1 surveys need at least %.0f m^2.', area, L.min_area_m2);
end
e = pre.scene_config.extent_enu_m; pad = pre.scene_config.home_pad_m; b = pre.bounds_enu_m(1:2, :);
maxExt = min(abs(e(:))) - L.extent_margin_m - pad - 1;      % 80 - 5 - 4 - 1 = 70 m for the V2.1 presets
ext = max(abs(poly(:)));
if ext > maxExt
    error('mgv22:FieldTooLarge', 'The field reaches %.1f m from its centre; at most %.0f m fits the simulated terrain.', ext, maxExt);
end

% --- camera model: altitude, GSD, swath, spacing --------------------------------------------------------
cs = mgv2.sensors.defaultSensorConfig();
rgb = cs.RGB_NADIR.mount; thr = cs.THERMAL_LWIR.mount;
gsd = @(m, alt) 2 * alt * tand(m.hfov_deg / 2) / m.width_px;
altMax = opts.TargetDiameterM * rgb.width_px / (opts.MinPixelsOnTarget * 2 * tand(rgb.hfov_deg / 2));
altMax = floor(altMax * 10 + 1e-9) / 10;
if altMax >= L.alt_agl_m(1)
    alt = min(altMax, L.alt_agl_m(2));
else
    alt = L.alt_agl_m(1);
end
gR = gsd(rgb, alt); gT = gsd(thr, alt);
pix = opts.TargetDiameterM / gR;
met = pix >= opts.MinPixelsOnTarget - 1e-9;
swath = min(gR * rgb.width_px, gT * thr.width_px);
spacing = min(max(swath * (1 - opts.SideOverlap), L.line_spacing_m(1)), L.line_spacing_m(2));

% --- heading and home -------------------------------------------------------------------------------
if isempty(opts.HeadingDeg)
    d = circshift(poly, -1, 1) - poly;
    [~, i] = max(vecnorm(d, 2, 2));
    heading = mod(atan2d(d(i,1), d(i,2)), 360);             % compass: 0 = north, 90 = east
else
    if ~(isscalar(opts.HeadingDeg) && isfinite(opts.HeadingDeg)), error('mgv22:InvalidOutline', 'HeadingDeg must be a finite scalar or [].'); end
    heading = mod(double(opts.HeadingDeg), 360);
end
[~, j] = min(poly(:,2));
home = [poly(j,1), poly(j,2) - 8];
lo = max(e(:,1)' + pad + 1, b(:,1)'); hi = min(e(:,2)' - pad - 1, b(:,2)');
home = min(max(home, lo), hi);

% --- V2.1 SurveySpec, validator and planner ------------------------------------------------------------
s = mgv21.scenario.defaultSurvey(opts.Preset);
s.boundary_kind = "POLYGON"; s.polygon_enu_m = poly; s.home_enu_m = home;
s.line_spacing_m = spacing; s.heading_deg = heading; s.alt_agl_m = alt; s.speed_mps = opts.SpeedMps;
try
    [pub, plan] = mgv21.scenario.buildPublicMission(opts.Preset, s);
catch err
    if strcmp(err.identifier, 'mgv21:InvalidSurvey')
        error('mgv22:FieldNotFlyable', 'This field cannot be flown as a V2.1 survey: %s', err.message);
    end
    rethrow(err);
end
route = mgv2.mission.buildRoute(pub.mission, plan);
polyE = pub.survey.polygon_enu_m;
toLL = @(xy) mgv22.geo.enuToWgs84([xy, zeros(size(xy, 1), 1)], anchor);
pl = toLL(polyE); rl = toLL(route.xy);
est = route.length_m / opts.SpeedMps + 60;                  % + takeoff, climb, descent and landing allowance

P = struct('field_anchor_lla', anchor, 'poly_enu', polyE, 'poly_ll', pl(:, 1:2), 'area_m2', area, 'area_ha', area / 1e4, ...
    'hull_used', hull, 'alt_m', alt, 'gsd_rgb_cm', 100 * gR, 'gsd_thermal_cm', 100 * gT, 'pixels_on_target', pix, ...
    'pixels_rule_met', met, 'swath_m', swath, 'spacing_m', pub.survey.line_spacing_m, 'speed_mps', pub.survey.speed_mps, ...
    'heading_deg', pub.survey.heading_deg, 'home_enu_m', pub.survey.home_enu_m, 'pub', pub, 'route_enu', route.xy, ...
    'route_ll', rl(:, 1:2), 'n_lines', plan.n_lines, 'est_flight_s', est, 'est_ticks', ceil(est / pub.mission.dt_s), ...
    'label', "SIMULATION — virtual survey of a drawn field");
end

function a = polyArea(p)
q = circshift(p, -1, 1);
a = abs(0.5 * sum(p(:,1) .* q(:,2) - q(:,1) .* p(:,2)));
end

function tf = isConvexCCW(p)
q = circshift(p, -1, 1); r = circshift(p, -2, 1);
z = (q(:,1) - p(:,1)) .* (r(:,2) - q(:,2)) - (q(:,2) - p(:,2)) .* (r(:,1) - q(:,1));
tol = 1e-9 * max(1, max(abs(p(:))))^2;
tf = all(z >= -tol);
end
