function spec = addExclusionZone(spec, kind, a, b)
%ADDEXCLUSIONZONE Add an area where no target may be placed (manual or random).
%   spec = mgv21.placement.addExclusionZone(spec, "CIRCLE", centerXY, radius_m)
%   spec = mgv21.placement.addExclusionZone(spec, "POLYGON", P)       P: N-by-2 (N >= 3) finite ENU metres
%   Throws mgv21:InvalidPlacement on a bad zone.
spec = checkSpec(spec); kind = upper(string(kind)); id = 'mgv21:InvalidPlacement';
switch kind
    case "CIRCLE"
        if ~(isnumeric(a) && numel(a) == 2 && all(isfinite(a)) && isnumeric(b) && isscalar(b) && isfinite(b) && b > 0)
            error(id, 'A CIRCLE zone needs a finite centre [x y] and a positive radius.');
        end
        z = struct('kind', kind, 'center_enu_m', double(a(:)'), 'radius_m', double(b), 'polygon_enu_m', zeros(0, 2));
    case "POLYGON"
        if ~(isnumeric(a) && ismatrix(a) && size(a, 2) == 2 && size(a, 1) >= 3 && all(isfinite(a), 'all'))
            error(id, 'A POLYGON zone needs an N-by-2 (N >= 3) finite vertex list.');
        end
        z = struct('kind', kind, 'center_enu_m', mean(double(a), 1), 'radius_m', NaN, 'polygon_enu_m', double(a));
    otherwise
        error(id, 'Exclusion zone kind must be CIRCLE or POLYGON.');
end
spec.exclusion_zones(end+1, 1) = z;
end
