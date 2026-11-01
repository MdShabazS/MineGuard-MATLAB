function p_ned = enuToNed(p_enu)
%ENUTONED Convert ENU position/vector rows [x_east y_north z_up] to NED rows [x_north y_east z_down].
%   p_ned = mgv2.frames.enuToNed(p_enu)   p_enu is N-by-3 (metres or any consistent unit).
%   This is the ONLY place the ENU->NED axis swap is written (UAV Toolbox adapter, ADR-04).
arguments
    p_enu (:,3) double
end
p_ned = [p_enu(:,2), p_enu(:,1), -p_enu(:,3)];
end
