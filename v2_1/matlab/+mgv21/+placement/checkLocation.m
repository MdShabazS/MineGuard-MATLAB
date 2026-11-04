function [ok, reason] = checkLocation(spec, pub, world, xy, ignoreRow)
%CHECKLOCATION Live SETUP feedback: may a target be placed at xy? Never throws for a bad location.
%   [ok, reason] = mgv21.placement.checkLocation(spec, pub, world, xy)
%   [ok, reason] = mgv21.placement.checkLocation(spec, pub, world, xy, ignoreRow)   ignore manual row (when moving it)
%   Refused: outside the survey boundary or within edge_margin_m of it, inside an exclusion zone, within 0.5 m of a
%   rock/bush/marker footprint or 1.5 m of a landmark, on the home pad, closer than min_spacing_m to another manual
%   target. reason is "" when ok.
if nargin < 5, ignoreRow = []; end
spec = checkSpec(spec);
M = spec.manual; keep = true(height(M), 1); keep(ignoreRow(ignoreRow >= 1 & ignoreRow <= height(M))) = false;
reason = locationReason(xy, spec, pub, world, [M.x_east_m(keep) M.y_north_m(keep)]);
ok = reason == "";
end
