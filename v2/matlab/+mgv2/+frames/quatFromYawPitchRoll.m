function q = quatFromYawPitchRoll(yaw, pitch, roll)
%QUATFROMYAWPITCHROLL Quaternion [w x y z] (FLU body -> ENU world) from intrinsic Z-Y-X angles.
%   q = mgv2.frames.quatFromYawPitchRoll(yaw, pitch, roll)   radians.
%   R = Rz(yaw) * Ry(pitch) * Rx(roll) in the ENU/FLU convention:
%     yaw   about +Up, from +East toward +North;
%     pitch about body +y (left): positive pitch puts the nose DOWN (right-hand rule about +left);
%     roll  about body +x (forward): positive roll puts the left side UP (right wing down).
cz = cos(yaw); sz = sin(yaw); cy = cos(pitch); sy = sin(pitch); cx = cos(roll); sx = sin(roll);
Rz = [cz -sz 0; sz cz 0; 0 0 1]; Ry = [cy 0 sy; 0 1 0; -sy 0 cy]; Rx = [1 0 0; 0 cx -sx; 0 sx cx];
q = mgv2.frames.rotmToQuat(Rz * Ry * Rx);
end
