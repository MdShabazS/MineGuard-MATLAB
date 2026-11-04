function reason = locationReason(xy, spec, pub, world, others)
%LOCATIONREASON "" if xy is an allowed target location, else the reason. others: K-by-2 targets to keep spacing from.
L = mgv21.contract().limits; P = pub.survey.polygon_enu_m; reason = "";
if ~(isnumeric(xy) && numel(xy) == 2 && all(isfinite(xy))), reason = "position is not a finite [x y]"; return; end
x = xy(1); y = xy(2);
if ~inpolygon(x, y, P(:,1), P(:,2)), reason = "outside the survey boundary"; return; end
if edgeDistance(xy, P) < spec.edge_margin_m, reason = sprintf("closer than %g m to the survey boundary", spec.edge_margin_m); return; end
Z = spec.exclusion_zones;
for k = 1:numel(Z)
    if Z(k).kind == "CIRCLE" && norm(xy - Z(k).center_enu_m) <= Z(k).radius_m, reason = sprintf("inside exclusion zone %d", k); return; end
    if Z(k).kind == "POLYGON" && inpolygon(x, y, Z(k).polygon_enu_m(:,1), Z(k).polygon_enu_m(:,2)), reason = sprintf("inside exclusion zone %d", k); return; end
end
O = world.objects;
if height(O) > 0
    d = hypot(O.x_east_m - x, O.y_north_m - y) - O.radius_m;
    [dm, k] = min(d);
    if dm < L.object_keepout_m, reason = sprintf("on or next to object %s", O.object_id(k)); return; end
end
for k = 1:numel(world.landmarks)
    if norm(xy - world.landmarks(k).xy) - world.landmarks(k).radius_m < L.landmark_keepout_m
        reason = sprintf("on or next to landmark %s", world.landmarks(k).id); return;
    end
end
h = pub.survey.home_enu_m; hp = pub.scene_config.home_pad_m / 2 + 1;
if max(abs(xy - h)) <= hp, reason = "on the home pad"; return; end
if ~isempty(others) && min(hypot(others(:,1) - x, others(:,2) - y)) < spec.min_spacing_m
    reason = sprintf("closer than %g m to another target", spec.min_spacing_m);
end
end

function d = edgeDistance(p, P)
n = size(P, 1); d = inf;
for i = 1:n
    a = P(i,:); b = P(mod(i, n) + 1, :); ab = b - a;
    t = min(max(dot(p - a, ab) / dot(ab, ab), 0), 1);
    d = min(d, norm(p - (a + t * ab)));
end
end
