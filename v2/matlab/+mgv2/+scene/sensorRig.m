function rig = sensorRig()
%SENSORRIG PROVISIONAL sensor mounting and intrinsics for V2-005 (frozen later by V2-004).
%   rig = mgv2.scene.sensorRig()   struct array: id, kind, T_body_sensor (4x4), and per kind:
%     camera: width_px, height_px, hfov_deg, fx, fy, cx, cy (pixels; pixel centres at integers, 1-based)
%     lidar : az_limits_deg, el_limits_deg, max_range_m. el_limits use the UAV Toolbox
%             uavLidarPointCloudGenerator convention on a NED/FRD platform, where +elevation points
%             toward body DOWN (verified in testV2003Scene s17: ElevationLimits [60 90] sees the ground)
%   Frames: body = FLU (mgv2.frames.conventions). Camera frame = x right, y down (image), z along the
%   optical axis. Every sensor here is NADIR: optical axis = body -z, image "up" = aircraft forward
%   (image +y = body -x, image +x = body -y). Positions are on the payload pod (quadrotorModel).
%   These values are engineering placeholders, NOT the V2-004 sensor contract.
Rbc = [[0 -1 0]', [-1 0 0]', [0 0 -1]'];   % columns = camera axes in body: x_c=-y_b, y_c=-x_b, z_c=-z_b (right-handed)
rig = struct('id', {}, 'kind', {}, 'T_body_sensor', {}, 'width_px', {}, 'height_px', {}, 'hfov_deg', {}, ...
    'fx', {}, 'fy', {}, 'cx', {}, 'cy', {}, 'az_limits_deg', {}, 'el_limits_deg', {}, 'max_range_m', {}, 'status', {});
rig(end+1) = cam("rgb_nadir", [0.055 0.000 0.090], Rbc, 640, 360, 70);
rig(end+1) = cam("thermal_nadir", [0.055 -0.030 0.090], Rbc, 160, 120, 50);
L = struct('id', "lidar_nadir", 'kind', "lidar", 'T_body_sensor', T([-0.050 0 0.100], Rbc), 'width_px', [], 'height_px', [], ...
    'hfov_deg', [], 'fx', [], 'fy', [], 'cx', [], 'cy', [], 'az_limits_deg', [-180 180], 'el_limits_deg', [45 90], ...
    'max_range_m', 60, 'status', "PROVISIONAL (pending V2-004)");
rig(end+1) = L;
end

function s = cam(id, pos, R, w, h, hfov)
fx = (w / 2) / tand(hfov / 2);
s = struct('id', id, 'kind', "camera", 'T_body_sensor', T(pos, R), 'width_px', w, 'height_px', h, 'hfov_deg', hfov, ...
    'fx', fx, 'fy', fx, 'cx', (w + 1) / 2, 'cy', (h + 1) / 2, 'az_limits_deg', [], 'el_limits_deg', [], 'max_range_m', 200, ...
    'status', "PROVISIONAL (pending V2-004)");
end

function M = T(p, R)
M = [R p(:); 0 0 0 1];
end
