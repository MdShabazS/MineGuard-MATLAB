function [hit, polyIndex] = segmentHitsPolygons(a, b, polys)
%SEGMENTHITSPOLYGONS Exact test of whether segment a->b touches or enters any polygon.
%   [hit, polyIndex] = segmentHitsPolygons(a, b, polys)
%   a, b  - 1x2 ENU points (metres). polys - cell array of Nx2 closed polygons.
%   hit is true when the segment
%     (1) has an endpoint inside or on the boundary of a polygon, or
%     (2) intersects or touches any polygon edge, including collinear overlap,
%         a vertex graze, or a polygon narrower than any sampling step.
%   The test is conservative: boundary contact counts as a conflict. Orientation
%   tests use a tolerance scaled to the coordinate magnitude, with no point sampling.
hit = false;
polyIndex = 0;
for k = 1:numel(polys)
    P = polys{k};
    if any(inpolygon([a(1) b(1)], [a(2) b(2)], P(:,1), P(:,2)))
        hit = true; polyIndex = k; return
    end
    Q = [P; P(1,:)];   % close the ring
    scale = max([1, abs(a), abs(b), max(abs(P(:)))]);
    tol = 1e-12 * scale^2;
    for e = 1:size(P,1)
        if segmentsIntersect(a, b, Q(e,:), Q(e+1,:), tol)
            hit = true; polyIndex = k; return
        end
    end
end
end

function tf = segmentsIntersect(p1, p2, q1, q2, tol)
o1 = orient(p1, p2, q1); o2 = orient(p1, p2, q2);
o3 = orient(q1, q2, p1); o4 = orient(q1, q2, p2);
s1 = sgn(o1, tol); s2 = sgn(o2, tol); s3 = sgn(o3, tol); s4 = sgn(o4, tol);
if s1 * s2 < 0 && s3 * s4 < 0
    tf = true; return                      % proper crossing
end
tf = (s1 == 0 && onSegment(p1, p2, q1)) || (s2 == 0 && onSegment(p1, p2, q2)) || ...
     (s3 == 0 && onSegment(q1, q2, p1)) || (s4 == 0 && onSegment(q1, q2, p2));
end

function v = orient(a, b, c)
v = (b(1) - a(1)) * (c(2) - a(2)) - (b(2) - a(2)) * (c(1) - a(1));
end

function s = sgn(v, tol)
s = (v > tol) - (v < -tol);
end

function tf = onSegment(a, b, c)
% c is (near-)collinear with a-b; check it lies within the bounding box of a-b.
e = 1e-12 * max([1, abs(a), abs(b), abs(c)]);
tf = c(1) >= min(a(1), b(1)) - e && c(1) <= max(a(1), b(1)) + e && ...
     c(2) >= min(a(2), b(2)) - e && c(2) <= max(a(2), b(2)) + e;
end
