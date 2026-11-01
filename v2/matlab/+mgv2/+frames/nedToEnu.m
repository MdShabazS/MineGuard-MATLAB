function p_enu = nedToEnu(p_ned)
%NEDTOENU Convert NED rows [x_north y_east z_down] to ENU rows [x_east y_north z_up].
%   p_enu = mgv2.frames.nedToEnu(p_ned)   Exact inverse of mgv2.frames.enuToNed.
arguments
    p_ned (:,3) double
end
p_enu = [p_ned(:,2), p_ned(:,1), -p_ned(:,3)];
end
