function spec = moveTarget(spec, k, xy)
%MOVETARGET Move MANUAL target k (row of spec.manual) to ENU [x y] metres. Throws mgv21:InvalidPlacement.
%   spec = mgv21.placement.moveTarget(spec, k, xy)
spec = checkSpec(spec);
if ~(isnumeric(k) && isscalar(k) && k == round(k) && k >= 1 && k <= height(spec.manual))
    error('mgv21:InvalidPlacement', 'No manual target %s.', string(k));
end
if ~(isnumeric(xy) && numel(xy) == 2 && all(isfinite(xy))), error('mgv21:InvalidPlacement', 'xy must be a finite ENU [x_east y_north].'); end
spec.manual.x_east_m(k) = double(xy(1)); spec.manual.y_north_m(k) = double(xy(2));
end
