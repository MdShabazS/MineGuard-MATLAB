function [p_enu, q_enu_flu] = poseNedToEnu(p_ned, q_ned_frd)
%POSENEDTOENU Inverse of mgv2.frames.poseEnuToNed (NED/FRD -> ENU/FLU).
%   [p_enu, q_enu_flu] = mgv2.frames.poseNedToEnu(p_ned, q_ned_frd)
arguments
    p_ned (1,3) double
    q_ned_frd (1,4) double
end
c = mgv2.frames.conventions();
p_enu = mgv2.frames.nedToEnu(p_ned);
q_enu_flu = mgv2.frames.rotmToQuat(c.R_ned_enu' * mgv2.frames.quatToRotm(q_ned_frd) * c.R_flu_frd');
end
