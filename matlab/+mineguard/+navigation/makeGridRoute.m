function route = makeGridRoute(navConfig, geometry)
%MAKEGRIDROUTE Fixed serpentine (lawnmower) survey route (mg-contract/1.0, MG-005).
%   route = mineguard.navigation.makeGridRoute(navConfig, geometry)
%
%   navConfig - NavigationConfig (whitelisted fields only; see validateNavConfig).
%   geometry  - ScenarioGeometry (exactly the 6 frozen fields; carries no truth).
%   route     - Nx3 double [x_east_m y_north_m z_up_m], with waypoints at survey cell
%               centres. Rows run east-west and alternate direction, stepping north.
%               z_up_m = navConfig.altitude_m.
%
%   Cells evenly subdivide the bounds, so the pitch is <= grid_spacing_m. Cell centres
%   inside exclusion polygons are dropped. If a remaining leg would cross an exclusion
%   polygon, the route is REJECTED with mineguard:RouteConflict. There is no silent
%   overlap, and no reroute in this baseline. The route depends only on navConfig and
%   geometry, never on hidden truth.
navConfig = validateNavConfig(navConfig);
[bounds, polys] = validateGeometry(geometry);
[xc, yc] = gridCells(bounds, navConfig.grid_spacing_m);

pts = zeros(0, 2);
for j = 1:numel(yc)
    xs = xc;
    if mod(j, 2) == 0
        xs = fliplr(xs);
    end
    ys = repmat(yc(j), size(xs));
    keep = ~insidePolys(xs, ys, polys);
    pts = [pts; xs(keep)' ys(keep)']; %#ok<AGROW>
end
if isempty(pts)
    error('mineguard:RouteConflict', 'MineGuard navigation: every survey cell lies inside an exclusion polygon.');
end

% Leg check: exact segment-polygon intersection, not point sampling. Any leg that
% enters, crosses or touches an exclusion polygon (including narrow polygons) is rejected.
for k = 1:size(pts,1)-1
    a = pts(k,:); b = pts(k+1,:);
    [hit, ip] = segmentHitsPolygons(a, b, polys);
    if hit
        error('mineguard:RouteConflict', ['MineGuard navigation: leg %d from (%.3f, %.3f) to (%.3f, %.3f) ' ...
            'intersects exclusion polygon %d. The baseline planner does not reroute.'], k, a(1), a(2), b(1), b(2), ip);
    end
end
route = [pts, repmat(navConfig.altitude_m, size(pts,1), 1)];
end
