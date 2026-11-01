function [O, D] = pixelRays(sensor, T_ws, uv)
%PIXELRAYS World rays (origin, unit direction; ENU) through camera pixel coordinates.
%   [O, D] = mgv2.scene.pixelRays(sensor, T_ws, uv)    uv N-by-2 (1-based pixel coordinates)
%   Exact inverse of mgv2.scene.projectToImage for points in front of the camera.
dc = [(uv(:,1) - sensor.cx) / sensor.fx, (uv(:,2) - sensor.cy) / sensor.fy, ones(size(uv, 1), 1)];
dc = dc ./ vecnorm(dc, 2, 2);
D = dc * T_ws(1:3, 1:3)';
O = repmat(T_ws(1:3, 4)', size(uv, 1), 1);
end
