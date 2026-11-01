function cfg = defaultConfig(varargin)
%DEFAULTCONFIG Nominal V2 MissionConfig (mg-v2-contract/1.0 subset owned by V2-002). SIMULATION ONLY.
%   cfg = mgv2.mission.defaultConfig()
%   cfg = mgv2.mission.defaultConfig(Name=Value, ...)   override any top-level field (or "constraints",
%                                                        "wind" with a full struct)
%   All lengths in metres, speeds m/s, accelerations m/s^2, angles degrees unless the name says _rad,
%   times seconds. Positions are ENU (mgv2.frames.conventions). Every numeric constant below is a
%   documented engineering assumption for a small (~1.5 kg, 0.45 m diagonal) survey multirotor,
%   not a measured vehicle parameter.
cfg = struct();
cfg.schema_version = "mg-v2-contract/1.0";
cfg.run_id = "V2RUN-NOMINAL-0001";
cfg.scenario_id = "V2-TRAINING-FIELD-A";
cfg.seed = 2002;
cfg.dt_s = 0.05;                                   % ADR-03 nominal tick (20 Hz)
cfg.bounds_enu_m = [-70 70; -70 70; -10 120];      % geofence: [xmin xmax; ymin ymax; zmin zmax] (z above datum)
cfg.survey_polygon_enu_m = [-40 -30; 40 -30; 40 30; -40 30];  % convex, counter-clockwise (x_east, y_north)
cfg.home_enu_m = [-55 -50];                        % launch / landing pad (x_east, y_north); z from terrain
cfg.virtual_wgs84_origin = [0 0 0];                % [lat_deg lon_deg alt_m] VIRTUAL, not measured GNSS
cfg.alt_agl_setpoint_m = 15;                       % survey height above ground
cfg.takeoff_agl_m = 3;                             % TAKEOFF ends, CLIMB begins
cfg.speed_mps = 6;                                 % cruise / survey ground speed
cfg.line_spacing_m = 10;                           % lawnmower line spacing
cfg.survey_heading_deg = 90;                       % direction of survey lines, compass (90 = lines run E-W)
cfg.preflight_s = 1.0;                             % hold on pad while preflight checks are reported
cfg.constraints = struct( ...
    'max_speed_mps', 8, ...                        % horizontal speed limit
    'max_climb_mps', 2.5, 'max_descent_mps', 1.5, ...
    'max_accel_mps2', 3.0, ...                     % horizontal acceleration limit (=> ~17 deg tilt)
    'max_vert_accel_mps2', 2.0, ...
    'max_tilt_deg', 25, ...
    'max_yaw_rate_dps', 60, ...
    'min_clearance_m', 4, ...                      % airborne AGL floor outside takeoff/landing
    'corridor_halfwidth_m', 5, ...                 % documented home<->survey transit corridor half-width
    'landing_tolerance_m', 0.05, 'touchdown_speed_mps', 0.35, ...
    'arrive_tolerance_m', 0.75, ...
    'timeout_s', 900);
cfg.wind = struct('enabled', false, 'mean_enu_mps', [0 0 0], 'gust_sigma_mps', 0, 'gust_tau_s', 3);
cfg.feature_flags = struct('record_commanded', true);
for k = 1:2:numel(varargin)
    cfg.(string(varargin{k})) = varargin{k+1};
end
end
