function h = headingDegFromYaw(yaw)
%HEADINGDEGFROMYAW Compass heading in degrees [0,360), clockwise from North, from ENU yaw (rad).
%   h = mgv2.frames.headingDegFromYaw(yaw)   yaw 0 (facing East) -> 90 deg; yaw pi/2 (North) -> 0 deg.
h = mod(90 - rad2deg(yaw), 360);
end
