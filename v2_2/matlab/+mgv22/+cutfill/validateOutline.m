function poly = validateOutline(poly)
%VALIDATEOUTLINE Check a cut/fill boundary polygon and return it counter-clockwise.
%   poly = mgv22.cutfill.validateOutline(poly)   N-by-2 ENU metres [east north]
%   Consecutive repeated vertices (including a repeated closing vertex) are dropped. Errors with
%   'mgv22:InvalidOutline' if the outline has fewer than 3 distinct points, non-finite values, any two
%   non-adjacent edges that intersect or touch, or an area below 1 m^2.
if ~isnumeric(poly) || ~ismatrix(poly) || size(poly, 2) ~= 2 || isempty(poly)
    error('mgv22:InvalidOutline', 'Outline must be an N-by-2 numeric array of [east north] metres.');
end
poly = double(poly);
if any(~isfinite(poly(:)))
    error('mgv22:InvalidOutline', 'Outline contains NaN or Inf.');
end
keep = [true; any(diff(poly, 1, 1) ~= 0, 2)];    % drop vertices equal to their predecessor; keep the first
if size(poly, 1) > 1 && isequal(poly(1, :), poly(end, :)), keep(end) = false; end   % a closing vertex goes, numbering stays 1..N
poly = poly(keep, :);
n = size(poly, 1);
if n < 3 || size(unique(poly, 'rows'), 1) < 3
    error('mgv22:InvalidOutline', 'Outline needs at least 3 distinct points.');
end
q = circshift(poly, -1, 1);
area2 = sum(poly(:,1).*q(:,2) - q(:,1).*poly(:,2));   % twice the signed (shoelace) area
if abs(area2)/2 < 1
    error('mgv22:InvalidOutline', 'Outline area is below 1 m^2.');
end
tol = 1e-12 * max(1, max(abs(poly(:))))^2;
for i = 1:n
    for j = i+2:n
        if i == 1 && j == n, continue, end          % edges n and 1 are adjacent
        if segmentsTouch(poly(i,:), q(i,:), poly(j,:), q(j,:), tol)
            error('mgv22:InvalidOutline', 'Outline is self-intersecting (edges %d and %d).', i, j);
        end
    end
end
if area2 < 0, poly = flipud(poly); end
end

function tf = segmentsTouch(p1, p2, p3, p4, tol)
d1 = orient(p3, p4, p1, tol); d2 = orient(p3, p4, p2, tol);
d3 = orient(p1, p2, p3, tol); d4 = orient(p1, p2, p4, tol);
tf = (d1*d2 < 0 && d3*d4 < 0) || (d1 == 0 && onSeg(p3, p4, p1)) || (d2 == 0 && onSeg(p3, p4, p2)) || ...
     (d3 == 0 && onSeg(p1, p2, p3)) || (d4 == 0 && onSeg(p1, p2, p4));
end

function s = orient(a, b, c, tol)
v = (b(1)-a(1))*(c(2)-a(2)) - (b(2)-a(2))*(c(1)-a(1));
s = sign(v) * (abs(v) > tol);
end

function tf = onSeg(a, b, c)
tf = c(1) >= min(a(1),b(1)) && c(1) <= max(a(1),b(1)) && c(2) >= min(a(2),b(2)) && c(2) <= max(a(2),b(2));
end
