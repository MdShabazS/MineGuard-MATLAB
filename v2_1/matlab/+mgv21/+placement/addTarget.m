function spec = addTarget(spec, xy, signature, burialDepth)
%ADDTARGET Append a MANUAL private target at ENU [x y] metres.
%   spec = mgv21.placement.addTarget(spec, xy)                         signature "VISIBLE_DISTURBANCE", depth 0.10 m
%   spec = mgv21.placement.addTarget(spec, xy, signature, burialDepth) signature "VISIBLE_DISTURBANCE" | "NONE"
%   Checks the value types only; the location is checked against the boundary, exclusion zones, objects and
%   spacing by checkLocation (live feedback) and by placeTargets (at LOCK). Throws mgv21:InvalidPlacement.
if nargin < 3, signature = "VISIBLE_DISTURBANCE"; end
if nargin < 4, burialDepth = 0.10; end
spec = checkSpec(spec);
if spec.mode ~= "MANUAL", error('mgv21:InvalidPlacement', 'Targets can be added by hand only in MANUAL mode.'); end
checkXY(xy);
signature = string(signature);
if ~(isscalar(signature) && ismember(signature, mgv21.contract().signatures)), error('mgv21:InvalidPlacement', 'signature must be VISIBLE_DISTURBANCE or NONE.'); end
if ~(isnumeric(burialDepth) && isscalar(burialDepth) && isfinite(burialDepth) && burialDepth >= 0 && burialDepth <= 1)
    error('mgv21:InvalidPlacement', 'burialDepth must be in [0, 1] m.');
end
if height(spec.manual) >= mgv21.contract().limits.target_count(2), error('mgv21:InvalidPlacement', 'Too many targets.'); end
spec.manual(end+1, :) = {double(xy(1)), double(xy(2)), signature, double(burialDepth)};
end

function checkXY(xy)
if ~(isnumeric(xy) && numel(xy) == 2 && all(isfinite(xy))), error('mgv21:InvalidPlacement', 'xy must be a finite ENU [x_east y_north].'); end
end
