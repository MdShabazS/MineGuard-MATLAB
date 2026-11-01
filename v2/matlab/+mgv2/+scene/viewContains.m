function [inside, ndc] = viewContains(view, P, aspect, margin)
%VIEWCONTAINS Conservative test that world points are inside a perspective camera's view.
%   [inside, ndc] = mgv2.scene.viewContains(view, P)               aspect = 1, margin = 0.9
%   [inside, ndc] = mgv2.scene.viewContains(view, P, aspect, margin)
%   view   struct from mgv2.scene.cameraView (position, target, up, view_angle_deg)
%   P      N-by-3 ENU points; aspect = axes width/height (>= 1 for landscape)
%   ndc    N-by-2 normalised coordinates: |ndc| <= 1 is on screen, where the view angle spans the
%          SHORTER axes dimension (MATLAB applies CameraViewAngle to the smaller dimension).
%   inside true when the point is in front of the camera and |ndc| <= margin on both axes.
if nargin < 3, aspect = 1; end
if nargin < 4, margin = 0.9; end
f = view.target - view.position; f = f / norm(f);
r = cross(f, view.up); r = r / norm(r); u = cross(r, f);
d = P - view.position; z = d * f';
t = tand(view.view_angle_deg / 2);
ax = max(aspect, 1); ay = max(1 / aspect, 1);
ndc = [(d * r') ./ (z * t * ax), (d * u') ./ (z * t * ay)];
inside = z > 0 & all(abs(ndc) <= margin, 2);
end
