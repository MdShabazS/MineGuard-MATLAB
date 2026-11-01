function [p_ned, q_ned_frd] = poseEnuToNed(p_enu, q_enu_flu)
%POSEENUTONED Convert a pose (ENU position, FLU->ENU quaternion) to UAV Toolbox NED/FRD form.
%   [p_ned, q_ned_frd] = mgv2.frames.poseEnuToNed(p_enu, q_enu_flu)
%   q_ned_frd maps FRD body vectors into NED: R_ned_frd = R_ned_enu * R_enu_flu * R_flu_frd.
%   Use only at the UAV Toolbox boundary (uavPlatform ReferenceFrame "NED", multirotorFlightTrajectory).
arguments
    p_enu (1,3) double
    q_enu_flu (1,4) double
end
c = mgv2.frames.conventions();
p_ned = mgv2.frames.enuToNed(p_enu);
q_ned_frd = mgv2.frames.rotmToQuat(c.R_ned_enu * mgv2.frames.quatToRotm(q_enu_flu) * c.R_flu_frd);
end
