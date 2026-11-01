function q = rotmToQuat(R)
%ROTMTOQUAT Unit quaternion [w x y z] (scalar first, w >= 0) from a 3x3 rotation matrix.
%   q = mgv2.frames.rotmToQuat(R)   Numerically stable (Shepperd's method); inverse of quatToRotm.
arguments
    R (3,3) double
end
tr = trace(R);
if tr > 0
    s = 2*sqrt(tr + 1);
    q = [s/4, (R(3,2)-R(2,3))/s, (R(1,3)-R(3,1))/s, (R(2,1)-R(1,2))/s];
elseif R(1,1) > R(2,2) && R(1,1) > R(3,3)
    s = 2*sqrt(1 + R(1,1) - R(2,2) - R(3,3));
    q = [(R(3,2)-R(2,3))/s, s/4, (R(1,2)+R(2,1))/s, (R(1,3)+R(3,1))/s];
elseif R(2,2) > R(3,3)
    s = 2*sqrt(1 + R(2,2) - R(1,1) - R(3,3));
    q = [(R(1,3)-R(3,1))/s, (R(1,2)+R(2,1))/s, s/4, (R(2,3)+R(3,2))/s];
else
    s = 2*sqrt(1 + R(3,3) - R(1,1) - R(2,2));
    q = [(R(2,1)-R(1,2))/s, (R(1,3)+R(3,1))/s, (R(2,3)+R(3,2))/s, s/4];
end
q = q / norm(q);
if q(1) < 0, q = -q; end
end
