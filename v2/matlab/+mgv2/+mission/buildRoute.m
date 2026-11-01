function route = buildRoute(cfg, plan)
%BUILDROUTE Continuous horizontal mission path home -> survey -> home with per-segment phase labels.
%   route = mgv2.mission.buildRoute(cfg, plan)
%   The vertical phases (TAKEOFF, CLIMB, LANDING) happen over the home pad and are handled by the
%   engine; this function builds the single horizontal polyline flown at the AGL setpoint:
%     TRANSIT     home -> first survey waypoint (inside the documented home corridor)
%     SURVEY      the lawnmower waypoints from planSurvey
%     RETURN_HOME last survey waypoint -> home
%   One continuous path means no stop-and-go at phase boundaries; phase follows the segment being flown.
%   route fields: xy (M-by-2), seg_phase (M-1 string), s (cumulative arc length, M-by-1), length_m,
%                 corridor_segments (2x4: [x0 y0 x1 y1] of the transit and return legs).
home = cfg.home_enu_m; wp = plan.waypoints_xy;
xy = [home; wp; home];
ph = [ "TRANSIT", repmat("SURVEY", 1, size(wp, 1) - 1), "RETURN_HOME" ];
keep = [true; vecnorm(diff(xy), 2, 2) > 1e-9];       % drop zero-length segments
if ~all(keep)
    idx = find(keep); ph = ph(idx(2:end) - 1); xy = xy(keep, :);
end
s = [0; cumsum(vecnorm(diff(xy), 2, 2))];
route = struct('xy', xy, 'seg_phase', ph, 's', s, 'length_m', s(end), ...
    'corridor_segments', [home wp(1,:); wp(end,:) home]);
end
