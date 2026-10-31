function in = insidePolys(x, y, polys)
%INSIDEPOLYS True where (x,y) lies inside or on the edge of any exclusion polygon.
in = false(size(x));
for k = 1:numel(polys)
    in = in | inpolygon(x, y, polys{k}(:,1), polys{k}(:,2));
end
end
