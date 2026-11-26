function [S2, truth] = injectFeatures(S, spec)
%INJECTFEATURES Cut SYNTHETIC craters, foxholes and trenches into a surface (V22-T12).
%   [S2, truth] = mgv22.relief.injectFeatures(S, spec)      spec from mgv22.relief.defaultFeatureSpec
%   Crater/foxhole: paraboloid bowl depth*(1-(r/R)^2) for r < R, R = diameter/2.
%   Trench: depth*max(0, 1-(d/(w/2))^2), d = distance to the segment p1-p2.
%   Depths are subtracted from S.Z; NaN cells stay NaN; overlapping features add. S2.source is unchanged and
%   S2.label gains " + SYNTHETIC conflict features". truth is the PRIVATE answer key (never shown in a view):
%   id ("CF-01"...), type, x_east_m, y_north_m (segment midpoint for a trench), size_m (diameter or length), depth_m.
%   Invalid type or non-finite/non-positive sizes -> error 'mgv22:InvalidRelief'.
[X, Y] = meshgrid(S.x, S.y);
cut = zeros(size(S.Z)); n = numel(spec);
id = strings(n, 1); type = strings(n, 1); xe = zeros(n, 1); yn = xe; sz = xe; dep = xe;
for k = 1:n
    f = spec(k); t = string(f.type);
    if ~isscalar(t) || ~any(t == ["crater" "foxhole" "trench"])
        error('mgv22:InvalidRelief', 'Feature %d: type must be crater, foxhole or trench.', k);
    end
    if ~(isscalar(f.depth_m) && isfinite(f.depth_m) && f.depth_m > 0)
        error('mgv22:InvalidRelief', 'Feature %d: depth_m must be finite and positive.', k);
    end
    if t == "trench"
        p1 = f.p1(:)'; p2 = f.p2(:)'; w = f.width_m;
        if numel(p1) ~= 2 || numel(p2) ~= 2 || ~all(isfinite([p1 p2])) || ~(isscalar(w) && isfinite(w) && w > 0)
            error('mgv22:InvalidRelief', 'Feature %d: trench needs finite p1, p2 and positive width_m.', k);
        end
        v = p2 - p1; L2 = v*v';
        if L2 > 0, u = max(0, min(1, ((X - p1(1))*v(1) + (Y - p1(2))*v(2))/L2)); else, u = zeros(size(X)); end
        d = hypot(X - p1(1) - u*v(1), Y - p1(2) - u*v(2));
        cut = cut + f.depth_m*max(0, 1 - (d/(w/2)).^2);
        c = (p1 + p2)/2; sz(k) = sqrt(L2);
    else
        c = f.center_enu_m(:)'; R = f.diameter_m/2;
        if numel(c) ~= 2 || ~all(isfinite(c)) || ~(isscalar(R) && isfinite(R) && R > 0)
            error('mgv22:InvalidRelief', 'Feature %d: %s needs a finite centre and positive diameter_m.', k, t);
        end
        r = hypot(X - c(1), Y - c(2));
        cut = cut + f.depth_m*max(0, 1 - (r/R).^2);
        sz(k) = f.diameter_m;
    end
    id(k) = sprintf("CF-%02d", k); type(k) = t; xe(k) = c(1); yn(k) = c(2); dep(k) = f.depth_m;
end
S2 = S;
S2.Z = S.Z - cut;                                                      % NaN - cut stays NaN
S2.label = string(S.label) + " + SYNTHETIC conflict features";
truth = table(id, type, xe, yn, sz, dep, 'VariableNames', {'id', 'type', 'x_east_m', 'y_north_m', 'size_m', 'depth_m'});
end
