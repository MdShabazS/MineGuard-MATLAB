function [fwd, info] = forwardFeatures(truth, spec, pub, world)
%FORWARDFEATURES PRIVATE flat surface features for the RGB/thermal forward models (SensorSystem SurfaceFeatures=).
%   [fwd, info] = mgv21.placement.forwardFeatures(truth, spec, pub, world)
%   fwd   struct array accepted by mgv2.sensors.validateSurfaceFeatures: no identity, class or label field,
%         in a seeded random order. info: n_visible_features, n_clutter, n_clutter_requested (private).
%   VISIBLE_DISTURBANCE targets get one disturbed-soil feature each. Clutter patches (bare soil, wet patch, scrap)
%   are ALWAYS added, with the SAME overlapping colour/size/temperature distributions as the V2 scenario builder
%   (mgv2.eval.buildScenario, V2-004 §3.2), so no single feature value identifies a target.
%   NONE targets add NOTHING, and the clutter keep-out ignores them, so fwd is identical with or without them.
%   Stream: RandStream("mrg32k3a", Seed=spec.clutter_seed), Substream 3 (visible-feature appearance, in target
%   order), Substream 4 (clutter positions, appearance and the final order). Features are flat: they never
%   change geometry, so LiDAR cannot see them.
%   Feature magnitudes are ASSUMED synthetic values, not measured landmine signatures.
spec = checkSpec(spec);
if ~(isstruct(truth) && isfield(truth, 'schema_version') && truth.schema_version == mgv21.contract().schemas.truth)
    error('mgv21:InvalidPlacement', 'truth must be a PrivateTargetTruth from mgv21.placement.placeTargets.');
end
env = mgv2.sensors.defaultEnvironment(pub.environment_mode);
sf = env.irradiance_W_m2 / 850;                              % solar factor, as in mgv2.eval.buildScenario
dirt = [0.60 0.49 0.36];
P = pub.survey.polygon_enu_m; T = truth.targets;
vis = T(T.surface_signature == "VISIBLE_DISTURBANCE", :);
F = mgv2.sensors.validateSurfaceFeatures([]);
rv = RandStream('mrg32k3a', 'Seed', spec.clutter_seed); rv.Substream = 3;
taken = zeros(0, 3);                                         % [x y keep-out radius] for clutter
O = world.objects;
if height(O) > 0, taken = [taken; O.x_east_m O.y_north_m O.radius_m + 1.2]; end
for k = 1:numel(world.landmarks), taken(end+1, :) = [world.landmarks(k).xy 2.5]; end %#ok<AGROW>
for k = 1:height(vis)                                        % disturbed soil over a hypothetical shallow object
    u = rand(rv, 1, 4); n1 = randn(rv);
    f = feature([vis.x_east_m(k) vis.y_north_m(k)], dirt);
    f.albedo_rgb = min(dirt * (0.85 + 0.30 * u(1)), 1); f.albedo_mix = 0.35 + 0.45 * u(2); f.radius_m = 0.22 + 0.25 * u(3);
    f.delta_T_K = (0.4 + 1.6 * u(4)) * sf + 0.3 * n1;
    F(end+1, 1) = f; %#ok<AGROW>
    taken(end+1, :) = [vis.x_east_m(k) vis.y_north_m(k) 1.5 + f.radius_m]; %#ok<AGROW>
end
nReq = min(max(round(polyArea(P) / 150), 6), 40);
pattern = ["SOIL","WET","SOIL","SCRAP"]; kinds = pattern(mod(0:nReq-1, numel(pattern)) + 1);
rc = RandStream('mrg32k3a', 'Seed', spec.clutter_seed); rc.Substream = 4;
lo = min(P, [], 1); span = max(P, [], 1) - lo; nC = 0;
for k = 1:nReq
    ok = false;
    for t = 1:400
        p = lo + span .* rand(rc, 1, 2);
        if inpolygon(p(1), p(2), P(:,1), P(:,2)) && (isempty(taken) || all(hypot(taken(:,1) - p(1), taken(:,2) - p(2)) > taken(:,3) + 1.0))
            ok = true; break;
        end
    end
    u = rand(rc, 1, 6); n1 = randn(rc);                      % drawn even when skipped: later clutter stays stable
    if ~ok, continue; end
    f = feature(p, dirt);
    switch kinds(k)
        case "SOIL"      % bare / sun-warmed soil, overlapping the visible-target distribution
            f.albedo_rgb = min(dirt * (0.85 + 0.30 * u(1)), 1); f.albedo_mix = 0.35 + 0.55 * u(2); f.radius_m = 0.25 + 0.50 * u(3);
            f.edge_m = 0.15; f.delta_T_K = (0.3 + 2.2 * u(4)) * sf + 0.3 * n1;
        case "WET"       % damp patch: darker, evaporatively cooler
            f.albedo_rgb = [0.30 0.30 0.22] * (0.8 + 0.4 * u(1)); f.albedo_mix = 0.30 + 0.50 * u(2); f.radius_m = 0.30 + 0.60 * u(3);
            f.edge_m = 0.20; f.delta_T_K = -(0.4 + 2.0 * u(4)) * (0.2 + sf);
        case "SCRAP"     % small bright low-emissivity scrap
            f.albedo_rgb = [0.78 0.78 0.80]; f.albedo_mix = 0.7 + 0.3 * u(2); f.radius_m = 0.08 + 0.15 * u(3); f.edge_m = 0.03;
            f.delta_T_K = (0.5 + 2.0 * u(4)) * sf; f.emissivity = 0.25 + 0.35 * u(5);
    end
    F(end+1, 1) = f; %#ok<AGROW>
    taken(end+1, :) = [p 1.5 + f.radius_m]; %#ok<AGROW>
    nC = nC + 1;
end
fwd = mgv2.sensors.validateSurfaceFeatures(F(randperm(rc, numel(F))));
info = struct('n_visible_features', height(vis), 'n_clutter', nC, 'n_clutter_requested', nReq);
end

function f = feature(p, dirt)
f = struct('center_enu_m', double(p(:)'), 'radius_m', 0.3, 'edge_m', 0.08, 'albedo_rgb', dirt, 'albedo_mix', 0, ...
    'delta_T_K', 0, 'emissivity', NaN);
end

function a = polyArea(P)
a = abs(0.5 * sum(P(:,1) .* circshift(P(:,2), -1) - circshift(P(:,1), -1) .* P(:,2)));
end
