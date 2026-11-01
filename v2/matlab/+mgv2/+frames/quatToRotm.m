function R = quatToRotm(q)
%QUATTOROTM Rotation matrix from a unit quaternion [w x y z] (scalar first).
%   R = mgv2.frames.quatToRotm(q)   R maps body vectors to world vectors: v_world = R * v_body.
%   The quaternion is normalised first; a zero quaternion is an error.
arguments
    q (1,4) double
end
n = norm(q);
if ~(isfinite(n) && n > 0), error('mgv2:InvalidQuaternion', 'Quaternion must be finite and non-zero.'); end
q = q / n; w = q(1); x = q(2); y = q(3); z = q(4);
R = [1-2*(y^2+z^2), 2*(x*y-w*z),   2*(x*z+w*y);
     2*(x*y+w*z),   1-2*(x^2+z^2), 2*(y*z-w*x);
     2*(x*z-w*y),   2*(y*z+w*x),   1-2*(x^2+y^2)];
end
