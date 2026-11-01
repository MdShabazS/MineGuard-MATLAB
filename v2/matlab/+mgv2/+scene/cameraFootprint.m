function [corners, valid] = cameraFootprint(world, sensor, T_ws)
%CAMERAFOOTPRINT Ground footprint of a rig camera: 4 image-corner rays intersected with the terrain.
%   [corners, valid] = mgv2.scene.cameraFootprint(world, sensor, T_ws)
%   corners 4-by-3 ENU (order: top-left, top-right, bottom-right, bottom-left image corners);
%   valid false if any corner ray misses the terrain (corners then contain NaN rows).
W = sensor.width_px; H = sensor.height_px;
uv = [0.5 0.5; W + 0.5 0.5; W + 0.5 H + 0.5; 0.5 H + 0.5];
[O, D] = mgv2.scene.pixelRays(sensor, T_ws, uv);
[corners, hit] = mgv2.scene.intersectTerrain(world, O, D);
valid = all(hit);
end
