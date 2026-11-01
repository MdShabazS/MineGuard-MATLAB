function [uv, depth, inImage] = projectToImage(sensor, T_ws, Pw)
%PROJECTTOIMAGE Pinhole projection of ENU world points into a rig camera.
%   [uv, depth, inImage] = mgv2.scene.projectToImage(sensor, T_ws, Pw)
%   Pw N-by-3 ENU; uv N-by-2 pixel coordinates (1-based, pixel centres at integers);
%   depth = distance along the optical axis (m); inImage = depth > 0 and uv inside [0.5, W+0.5]x[0.5, H+0.5].
R = T_ws(1:3, 1:3); t = T_ws(1:3, 4)';
Pc = (Pw - t) * R;                          % rows: R' * (p - t)
depth = Pc(:, 3);
uv = [sensor.fx * Pc(:,1) ./ depth + sensor.cx, sensor.fy * Pc(:,2) ./ depth + sensor.cy];
inImage = depth > 0 & uv(:,1) >= 0.5 & uv(:,1) <= sensor.width_px + 0.5 & uv(:,2) >= 0.5 & uv(:,2) <= sensor.height_px + 0.5;
end
