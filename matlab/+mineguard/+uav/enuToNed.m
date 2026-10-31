function ned = enuToNed(enu)
%ENUTONED Convert Nx3 ENU [east north up] to NED [north east down] (metres).
%   This is the ONLY place where the axis convention changes (mg-contract/1.0 rule 1).
%   It is its own inverse, so nedToEnu(ned) == enuToNed(ned).
if ~(isnumeric(enu) && size(enu,2) == 3)
    error('mineguard:InvalidFrame', 'MineGuard UAV adapter: input must be Nx3.');
end
ned = [enu(:,2), enu(:,1), -enu(:,3)];
end
