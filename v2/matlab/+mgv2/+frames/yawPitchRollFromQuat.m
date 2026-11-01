function [yaw, pitch, roll] = yawPitchRollFromQuat(q)
%YAWPITCHROLLFROMQUAT Intrinsic Z-Y-X angles (radians) from [w x y z]; inverse of quatFromYawPitchRoll.
%   [yaw, pitch, roll] = mgv2.frames.yawPitchRollFromQuat(q)   pitch in [-pi/2, pi/2].
R = mgv2.frames.quatToRotm(q);
pitch = asin(max(-1, min(1, -R(3,1))));
yaw = atan2(R(2,1), R(1,1));
roll = atan2(R(3,2), R(3,3));
end
