function w = discOverlapFraction(R, a, d)
%DISCOVERLAPFRACTION Fraction of a footprint disc (radius R) covered by an object disc
%   (radius a) whose centre is a horizontal distance d away. Result is in [0,1].
%   This is a linear area-mixing (footprint dilution) model: a small object fully inside
%   a large footprint contributes a^2/R^2, so flying higher can never amplify a fixed
%   small source. R = 0 is a point sample (1 inside the object disc, else 0).
%   R is a scalar; a and d may be vectors of the same size.
w = zeros(size(d));
if R <= 0
    w(d <= a) = 1;
    return
end
for k = 1:numel(d)
    ak = a(min(k, numel(a)));
    dk = d(k);
    if dk >= R + ak
        A = 0;
    elseif dk <= abs(R - ak)
        A = pi * min(R, ak)^2;
    else
        c1 = (dk^2 + R^2 - ak^2) / (2 * dk * R);
        c2 = (dk^2 + ak^2 - R^2) / (2 * dk * ak);
        A = R^2 * acos(max(-1, min(1, c1))) + ak^2 * acos(max(-1, min(1, c2))) ...
            - 0.5 * sqrt(max(0, (-dk + R + ak) * (dk + R - ak) * (dk - R + ak) * (dk + R + ak)));
    end
    w(k) = min(1, max(0, A / (pi * R^2)));
end
end
