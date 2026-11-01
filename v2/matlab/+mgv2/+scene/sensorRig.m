function rig = sensorRig()
%SENSORRIG Sensor mounting and intrinsics aligned to V2-004 mg-v2-sensors/1.0 default targets.
%   rig = mgv2.scene.sensorRig()   struct array, one entry per V2-004 controlled sensor_id:
%     RGB_NADIR      camera 320x240, 70 deg HFOV (V2-004 §2.4 default target)
%     THERMAL_LWIR   camera 160x120, 45 deg HFOV (V2-004 §2.5 default target, own mount)
%     LIDAR_TERRAIN  max range 100 m (V2-004 §2.6), ray layout declared below
%   Common fields: sensor_id, kind, translation_body_m [1x3], rotation_sensor_to_body [3x3] (ACTIVE
%   rotation mapping sensor-frame vectors into the FLU body frame, V2-004 §2.1), T_body_sensor (4x4 of
%   the same), config_origin "ASSUMED", contract "mg-v2-sensors/1.0".
%   Camera fields: width_px, height_px, hfov_deg, fx, fy, cx, cy (1-based pixel centres at integers,
%   principal point ((W+1)/2,(H+1)/2), fy = fx square pixels), K (3x3), distortion (zeros, explicit).
%   LiDAR fields: az_limits_deg, el_limits_deg, az_res_deg, el_res_deg, max_range_m. The elevation
%   limits use the UAV Toolbox uavLidarPointCloudGenerator convention on a NED/FRD platform, where
%   +elevation points toward body DOWN (verified in testV2003Scene s17).
%   Frames: body = FLU. Optical frame: +x pixel-right, +y pixel-down, +z along the optical axis. All three
%   sensors are NADIR: optical axis = body -z, image "up" = aircraft forward (image +y = body -x).
%   Mount TRANSLATIONS (payload pod positions on mgv2.scene.quadrotorModel) are V2-003 engineering
%   assumptions (V2-004 fixes the format, not numeric mount offsets).
Rbc = [[0 -1 0]', [-1 0 0]', [0 0 -1]'];   % columns = optical axes in body: x_c=-y_b, y_c=-x_b, z_c=-z_b (det +1)
rig = [cam("RGB_NADIR", [0.055 0.000 0.090], Rbc, 320, 240, 70), ...
       cam("THERMAL_LWIR", [0.055 -0.030 0.090], Rbc, 160, 120, 45), ...
       lidar("LIDAR_TERRAIN", [-0.050 0 0.100], Rbc)];
end

function s = base(id, kind, pos, R)
s = struct('sensor_id', id, 'kind', kind, 'translation_body_m', pos, 'rotation_sensor_to_body', R, ...
    'T_body_sensor', [R pos(:); 0 0 0 1], 'config_origin', "ASSUMED", 'contract', "mg-v2-sensors/1.0", ...
    'width_px', [], 'height_px', [], 'hfov_deg', [], 'fx', [], 'fy', [], 'cx', [], 'cy', [], 'K', [], 'distortion', [], ...
    'az_limits_deg', [], 'el_limits_deg', [], 'az_res_deg', [], 'el_res_deg', [], 'max_range_m', []);
end

function s = cam(id, pos, R, w, h, hfov)
s = base(id, "camera", pos, R);
fx = (w / 2) / tand(hfov / 2);
s.width_px = w; s.height_px = h; s.hfov_deg = hfov; s.fx = fx; s.fy = fx; s.cx = (w + 1) / 2; s.cy = (h + 1) / 2;
s.K = [fx 0 s.cx; 0 fx s.cy; 0 0 1]; s.distortion = zeros(1, 5);   % [k1 k2 p1 p2 k3], explicitly zero
s.max_range_m = 200;
end

function s = lidar(id, pos, R)
s = base(id, "lidar", pos, R);
s.az_limits_deg = [-180 180]; s.el_limits_deg = [45 90]; s.az_res_deg = 2; s.el_res_deg = 2; s.max_range_m = 100;
end
