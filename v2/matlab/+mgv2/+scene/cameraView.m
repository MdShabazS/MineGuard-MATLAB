function v = cameraView(mode, pose, world, params)
%CAMERAVIEW Operator camera for a given aircraft pose (pure function; ENU metres, degrees).
%   v = mgv2.scene.cameraView(mode, pose, world)
%   v = mgv2.scene.cameraView(mode, pose, world, params)
%   mode   "isometric" | "follow" | "chase" | "topdown" | "orbit"
%   pose   struct with position_enu_m [1x3] and yaw_rad (PoseSample fields)
%   params optional struct; fields used per mode (defaults in brackets):
%     follow : follow_dist_m [14], follow_az_deg [-135], follow_el_deg [28]   world-fixed offset
%     chase  : chase_dist_m [7], chase_el_deg [16], chase_yaw_rad [pose.yaw_rad] (renderer smooths it)
%     orbit  : orbit_az_deg [35], orbit_el_deg [18], orbit_dist_m [2.2]       close inspection
%     isometric / topdown : whole survey field (extent, polygon and home) kept in view
%   v fields: position, target, up (1x3), view_angle_deg, mode.
%   Follow/chase/orbit keep the aircraft at the view centre (target), so it cannot be lost in turns,
%   climbs or descents; isometric/topdown frame the full field, which contains every legal position.
if nargin < 4, params = struct(); end
g = @(n, d) getp(params, n, d);
p = pose.position_enu_m;
switch string(mode)
    case "isometric"
        [c, R] = fieldFrame(world); va = 32;
        D = R / tand(va / 2) * 0.80; az = -128; el = 38;
        v = mk(c + D * [cosd(el) * cosd(az), cosd(el) * sind(az), sind(el)], c, [0 0 1], va);
    case "topdown"
        [c, R] = fieldFrame(world); va = 34;
        v = mk(c + [0 0 R / tand(va / 2) * 1.02], c, [0 1 0], va);
    case "follow"
        d = g('follow_dist_m', 14); az = g('follow_az_deg', -135); el = g('follow_el_deg', 28);
        t = p + [0 0 0.15];
        v = mk(t + d * [cosd(el) * cosd(az), cosd(el) * sind(az), sind(el)], t, [0 0 1], 40);
    case "chase"
        d = g('chase_dist_m', 7); el = g('chase_el_deg', 16); yw = g('chase_yaw_rad', pose.yaw_rad);
        f = [cos(yw) sin(yw) 0]; t = p + 2.5 * f + [0 0 0.1];
        v = mk(p - d * cosd(el) * f + [0 0 d * sind(el) + 0.4], t, [0 0 1], 50);
    case "orbit"
        d = g('orbit_dist_m', 2.2); az = g('orbit_az_deg', 35); el = g('orbit_el_deg', 18);
        t = p + [0 0 0.12];
        v = mk(t + d * [cosd(el) * cosd(az), cosd(el) * sind(az), sind(el)], t, [0 0 1], 35);
    otherwise
        error('mgv2:InvalidCameraMode', 'Unknown camera mode "%s" (isometric|follow|chase|topdown|orbit).', string(mode));
end
v.mode = string(mode);
end

function v = mk(pos, tgt, up, va)
v = struct('position', pos, 'target', tgt, 'up', up, 'view_angle_deg', va);
end

function x = getp(s, n, d)
if isfield(s, n), x = s.(n); else, x = d; end
end

function [c, R] = fieldFrame(world)
e = world.config.extent_enu_m; P = [world.config.survey_polygon_enu_m; world.config.home_enu_m];
lo = min([P; e(:,1)'] , [], 1); hi = max([P; e(:,2)'], [], 1);
zc = median(world.Z(:));
c = [(lo + hi) / 2, zc]; R = norm(hi - lo) / 2;
end
