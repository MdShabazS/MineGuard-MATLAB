function report = mgv2CameraGeometryDemo(outDir)
%MGV2CAMERAGEOMETRYDEMO V2-003 camera-geometry feasibility for V2-005. SIMULATION ONLY.
%   report = mgv2CameraGeometryDemo()          show the figure
%   report = mgv2CameraGeometryDemo(outDir)    also save V2-003-camera-geometry-feasibility.png there
%   A calibration landmark painted at a KNOWN terrain coordinate is projected into the provisional
%   RGB and thermal nadir cameras, back-projected to the terrain, located in a scene-sampled raster,
%   and checked against each camera's ground footprint. Provisional rig (pending V2-004); terrain-only
%   raster; NOT the V2-005 sensor streams.
if nargin < 1, outDir = ""; end

w = mgv2.scene.buildWorld(); rig = mgv2.scene.sensorRig(); L = w.landmarks(1); Pl = [L.xy L.z];
pose = struct('position_enu_m', [Pl(1:2) + [2 -3], Pl(3) + 15], 'orientation_quat', mgv2.frames.quatFromYawPitchRoll(deg2rad(25), deg2rad(-6), deg2rad(4)), ...
    't_s', 0, 'yaw_rad', deg2rad(25));
f = figure('Color', 'w', 'Position', [60 60 1500 520], 'Name', 'V2-003 camera geometry feasibility (SIMULATION)');
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact');
title(tl, {'SIMULATION — V2-003 camera-geometry feasibility (provisional rig; NOT the V2-005 sensor streams)', ...
    sprintf('pose E %.1f N %.1f U %.1f m, yaw %.0f%s pitch %.0f%s roll %.0f%s; landmark %s at E %.2f N %.2f', pose.position_enu_m, 25, char(176), -6, char(176), 4, char(176), L.id, L.xy)}, 'FontSize', 11);
ax = nexttile(tl); hold(ax, 'on'); axis(ax, 'equal');
m = 25; sel = abs(w.V(:,1) - Pl(1)) < m & abs(w.V(:,2) - Pl(2)) < m;
scatter(ax, w.V(sel,1), w.V(sel,2), 6, w.vertex_rgb(sel,:), 'filled', 'DisplayName', 'terrain vertex albedo');
cols = {[0.9 0.1 0.1], [0.1 0.3 0.95]}; out = strings(2, 1);
for k = 1:2
    c = rig(k); T_ws = mgv2.scene.sensorPose(pose, c); [C, ok] = mgv2.scene.cameraFootprint(w, c, T_ws);
    plot(ax, C([1:4 1], 1), C([1:4 1], 2), '-', 'Color', cols{k}, 'LineWidth', 2, 'DisplayName', c.id + " footprint");
    [uv, ~, in] = mgv2.scene.projectToImage(c, T_ws, Pl); [O, Dd] = mgv2.scene.pixelRays(c, T_ws, uv); Pg = mgv2.scene.intersectTerrain(w, O, Dd);
    [img, valid] = mgv2.scene.renderNadirRaster(w, c, T_ws);
    col = double(reshape(img, [], 3)) / 255; mm = vecnorm(col - L.color, 2, 2) < 0.12; [vv, uu] = ind2sub([c.height_px c.width_px], find(mm));
    out(k) = sprintf('%s: %dx%d, landmark projects to (u,v)=(%.2f, %.2f) in image=%d; back-projected error %.2e m; raster centroid (%.2f, %.2f) -> %.2f px; valid pixels %d/%d; footprint ok=%d', ...
        c.id, c.width_px, c.height_px, uv, in, norm(Pg - Pl), mean(uu), mean(vv), norm([mean(uu) mean(vv)] - uv), nnz(valid), numel(valid), ok);
    a2 = nexttile(tl); image(a2, img); axis(a2, 'image'); hold(a2, 'on');
    plot(a2, uv(1), uv(2), 'w+', 'MarkerSize', 18, 'LineWidth', 1.5);
    title(a2, sprintf('%s raster %dx%d (scene-sampled, terrain only)', c.id, c.width_px, c.height_px), 'Interpreter', 'none');
    xlabel(a2, 'u [px]  (image up = aircraft forward)'); ylabel(a2, 'v [px]');
end
plot(ax, Pl(1), Pl(2), 'kp', 'MarkerSize', 14, 'MarkerFaceColor', L.color, 'DisplayName', L.id + " (known terrain coordinate)");
plot(ax, pose.position_enu_m(1), pose.position_enu_m(2), 'k^', 'MarkerFaceColor', 'y', 'DisplayName', 'aircraft (ENU xy)');
legend(ax, 'Location', 'southoutside', 'Interpreter', 'none'); xlabel(ax, 'x east [m]'); ylabel(ax, 'y north [m]'); title(ax, 'Ground footprints on the world albedo');
drawnow; if strlength(string(outDir)) > 0, exportgraphics(f, fullfile(outDir, 'V2-003-camera-geometry-feasibility.png'), 'Resolution', 110); end
fprintf('%s\n', out);
report = out;
end
