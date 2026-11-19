function F = profileLine(S, P, p1, p2, n)
%PROFILELINE Existing-ground and design-plane elevations along a straight section line.
%   F = mgv22.cutfill.profileLine(S, P, p1, p2)
%   F = mgv22.cutfill.profileLine(S, P, p1, p2, n)   n sample points (default 100, >= 2)
%   p1, p2 are 1-by-2 ENU metres. F.xy (n-by-2), F.dist_m (0..length), F.existing_m (linear interpolation
%   of S.Z; NaN off the grid or in no-data cells), F.design_m (a + b*x + c*y). Errors 'mgv22:InvalidProfile'.
if nargin < 5 || isempty(n), n = 100; end
p1 = double(p1(:).'); p2 = double(p2(:).');
if numel(p1) ~= 2 || numel(p2) ~= 2 || any(~isfinite([p1 p2]))
    error('mgv22:InvalidProfile', 'Profile end points must be finite [east north] pairs.');
end
L = hypot(p2(1)-p1(1), p2(2)-p1(2));
if L == 0
    error('mgv22:InvalidProfile', 'Profile end points must differ.');
end
if ~isscalar(n) || n < 2 || n ~= fix(n)
    error('mgv22:InvalidProfile', 'Number of profile points must be an integer >= 2.');
end
t = linspace(0, 1, n).';
F.xy = p1 + t.*(p2 - p1);
F.dist_m = t*L;
F.existing_m = interp2(S.x, S.y, S.Z, F.xy(:,1), F.xy(:,2), 'linear');
F.design_m = P.a + P.b*F.xy(:,1) + P.c*F.xy(:,2);
end
