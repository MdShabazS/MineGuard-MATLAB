function c = conventions()
%CONVENTIONS Single source of truth for MineGuard V2 frames, units and quaternion order.
%   c = mgv2.frames.conventions()
%
%   World frame (canonical, internal): ENU = (x_east_m, y_north_m, z_up_m), metres, origin = declared
%     virtual survey datum. z_up_m is height above that datum, NOT height above terrain.
%   Altitude above ground: altitude_agl_m = z_up_m - terrainHeight(x_east_m, y_north_m).
%   Body frame: FLU = (x forward, y left, z up), attached to the aircraft centre of mass.
%   Orientation: unit quaternion q = [w x y z] (scalar first) rotating FLU body vectors into ENU:
%     v_enu = R(q) * v_flu. Yaw is about +z_up, measured from +East toward +North (counter-clockwise).
%   Compass heading (display only): heading_deg = mod(90 - yaw_deg, 360), clockwise from North.
%   UAV Toolbox adapter only: NED world (x north, y east, z down) with FRD body (forward, right, down),
%     R_ned_enu = [0 1 0; 1 0 0; 0 0 -1], R_flu_frd = diag([1 -1 -1]).
%   Time: t_s seconds from mission start on the engine clock (never wall clock).
c = struct( ...
    'world', "ENU", 'world_axes', ["x_east_m","y_north_m","z_up_m"], 'units_length', "m", ...
    'body', "FLU", 'quat_order', "wxyz", 'quat_maps', "body(FLU)->world(ENU)", ...
    'yaw', "rad, about +Up, from +East toward +North", 'heading', "deg, clockwise from North (display)", ...
    'toolbox_world', "NED", 'toolbox_body', "FRD", ...
    'R_ned_enu', [0 1 0; 1 0 0; 0 0 -1], 'R_flu_frd', diag([1 -1 -1]), ...
    'time', "t_s from engine SimulationClock (fixed dt), never wall clock");
end
