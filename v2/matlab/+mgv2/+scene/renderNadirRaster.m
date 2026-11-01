function [img, valid, P] = renderNadirRaster(world, sensor, T_ws, sunDirEnu)
%RENDERNADIRRASTER Scene-sampled synthetic camera raster (FEASIBILITY for V2-005, not the final stream).
%   [img, valid, P] = mgv2.scene.renderNadirRaster(world, sensor, T_ws)
%   [img, valid, P] = mgv2.scene.renderNadirRaster(world, sensor, T_ws, sunDirEnu)
%   For every pixel: ray from the camera (pixelRays) -> first terrain intersection (intersectTerrain)
%   -> surface colour (albedoAt, same triangles as the 3-D view, landmark discs included) x Lambert
%   shading from the terrain normal and a sun direction (default from the south-west, 50 deg up).
%   img H-by-W-by-3 uint8; valid H-by-W logical (false = ray missed the terrain -> black, never
%   invented); P (H*W)-by-3 ENU intersection points (column-major pixel order).
%   Limitations (documented): terrain only (rocks/bushes/markers not ray-traced), no cast shadows,
%   no lens distortion, noise or exposure model. V2-004/V2-005 own the final sensor models.
if nargin < 4, sunDirEnu = [-cosd(50) * cosd(45), -cosd(50) * sind(45), sind(50)]; end
L = sunDirEnu(:)' / norm(sunDirEnu);     % unit vector from the ground TOWARD the sun
W = sensor.width_px; H = sensor.height_px;
[uu, vv] = meshgrid(1:W, 1:H);
[O, D] = mgv2.scene.pixelRays(sensor, T_ws, [uu(:) vv(:)]);
[P, hit] = mgv2.scene.intersectTerrain(world, O, D);
rgb = zeros(numel(uu), 3);
if any(hit)
    a = mgv2.scene.albedoAt(world, P(hit,1), P(hit,2));
    e = 0.25;   % finite-difference half-width for the surface normal (m)
    zx = (mgv2.scene.heightAt(world, P(hit,1) + e, P(hit,2)) - mgv2.scene.heightAt(world, P(hit,1) - e, P(hit,2))) / (2 * e);
    zy = (mgv2.scene.heightAt(world, P(hit,1), P(hit,2) + e) - mgv2.scene.heightAt(world, P(hit,1), P(hit,2) - e)) / (2 * e);
    nrm = [-zx, -zy, ones(size(zx))]; nrm = nrm ./ vecnorm(nrm, 2, 2);
    nrm(any(isnan(nrm), 2), :) = repmat([0 0 1], nnz(any(isnan(nrm), 2)), 1);
    shade = 0.45 + 0.55 * max(nrm * L', 0);
    rgb(hit, :) = min(max(a .* shade, 0), 1);
end
img = uint8(round(255 * reshape(rgb, H, W, 3)));
valid = reshape(hit, H, W);
end
