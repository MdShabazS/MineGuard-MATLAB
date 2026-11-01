function T_ws = sensorPose(pose, sensor)
%SENSORPOSE World(ENU) <- sensor homogeneous transform for a PoseSample and a rig entry.
%   T_ws = mgv2.scene.sensorPose(pose, sensor)
%   T_ws = T_world_body * T_body_sensor, with T_world_body = [R(q) p; 0 1] from pose.orientation_quat
%   (FLU->ENU, [w x y z]) and pose.position_enu_m.  p_world = T_ws * [p_sensor; 1].
R = mgv2.frames.quatToRotm(pose.orientation_quat);
T_wb = [R pose.position_enu_m(:); 0 0 0 1];
T_ws = T_wb * sensor.T_body_sensor;
end
