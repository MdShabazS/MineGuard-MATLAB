function spec = deleteTarget(spec, k)
%DELETETARGET Remove MANUAL target k (row of spec.manual). Throws mgv21:InvalidPlacement.
%   spec = mgv21.placement.deleteTarget(spec, k)
spec = checkSpec(spec);
if ~(isnumeric(k) && isscalar(k) && k == round(k) && k >= 1 && k <= height(spec.manual))
    error('mgv21:InvalidPlacement', 'No manual target %s.', string(k));
end
spec.manual(k, :) = [];
end
