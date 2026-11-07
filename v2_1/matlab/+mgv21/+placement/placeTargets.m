function [truth, report] = placeTargets(spec, pub, world)
%PLACETARGETS Resolve a PlacementSpec into PrivateTargetTruth (mg-v21-truth/1.0). EVALUATOR-ONLY output.
%   [truth, report] = mgv21.placement.placeTargets(spec, pub, world)
%   NONE    no targets (manual rows and count are ignored).
%   MANUAL  every row of spec.manual is checked (boundary, edge margin, exclusion zones, objects, landmarks,
%           home pad, min spacing); the first violation throws mgv21:InvalidPlacement naming the row and reason.
%   RANDOM  spec.count targets by rejection sampling in the boundary's bounding box with a DEDICATED stream
%           RandStream("mrg32k3a", Seed=spec.seed), Substream 1 (positions); Substream 2 draws each target's
%           signature (VISIBLE_DISTURBANCE with probability visible_fraction, else NONE) and burial depth, so
%           positions do not depend on visible_fraction. The global rng is not used. Same seed and spec ->
%           identical targets. If a target cannot be placed in 2000 tries, throws mgv21:PlacementInfeasible
%           (no partial result).
%   truth   schema_version, mode, seed, generator, preset_id, polygon_enu_m,
%           targets (target_id, x_east_m, y_north_m, surface_signature, burial_depth_m)
%   report  n_targets, n_visible, n_no_signature, tries, min_pair_distance_m
spec = checkSpec(spec); c = mgv21.contract();
mgv21.scenario.assertPublic(pub, "PublicMissionConfig");
T = table('Size', [0 5], 'VariableTypes', ["string","double","double","string","double"], ...
    'VariableNames', ["target_id","x_east_m","y_north_m","surface_signature","burial_depth_m"]);
tries = 0;
switch spec.mode
    case "MANUAL"
        M = spec.manual;
        for k = 1:height(M)
            others = [M.x_east_m([1:k-1, k+1:end]) M.y_north_m([1:k-1, k+1:end])];
            r = locationReason([M.x_east_m(k) M.y_north_m(k)], spec, pub, world, others);
            if r ~= "", error('mgv21:InvalidPlacement', 'Manual target %d at (%.2f, %.2f) m is not allowed: %s.', k, M.x_east_m(k), M.y_north_m(k), r); end
            T(end+1, :) = {sprintf("V21-T%02d", k), M.x_east_m(k), M.y_north_m(k), M.surface_signature(k), M.burial_depth_m(k)}; %#ok<AGROW>
        end
    case "RANDOM"
        P = pub.survey.polygon_enu_m; lo = min(P, [], 1); span = max(P, [], 1) - lo;
        rp = RandStream('mrg32k3a', 'Seed', spec.seed); rp.Substream = 1;
        rsig = RandStream('mrg32k3a', 'Seed', spec.seed); rsig.Substream = 2;
        xy = zeros(0, 2); maxTries = c.limits.random_tries_per_target;
        for k = 1:spec.count
            placed = false;
            for t = 1:maxTries
                tries = tries + 1;
                p = lo + span .* rand(rp, 1, 2);
                if locationReason(p, spec, pub, world, xy) == "", placed = true; break; end
            end
            if ~placed
                error('mgv21:PlacementInfeasible', 'Placed only %d of %d targets after %d tries for target %d; relax the spacing, margin or exclusion zones, or lower the count.', ...
                    k - 1, spec.count, maxTries, k);
            end
            xy(end+1, :) = p; %#ok<AGROW>
            u = rand(rsig, 1, 2);
            sig = "NONE"; if u(1) < spec.visible_fraction, sig = "VISIBLE_DISTURBANCE"; end
            T(end+1, :) = {sprintf("V21-T%02d", k), p(1), p(2), sig, 0.05 + 0.15 * u(2)}; %#ok<AGROW>
        end
end
truth = struct('schema_version', c.schemas.truth, 'mode', spec.mode, 'seed', spec.seed, 'generator', "mrg32k3a", ...
    'preset_id', pub.preset_id, 'polygon_enu_m', pub.survey.polygon_enu_m, 'targets', T);
dmin = NaN;
if height(T) > 1
    D = hypot(T.x_east_m - T.x_east_m', T.y_north_m - T.y_north_m'); D(1:height(T)+1:end) = inf; dmin = min(D, [], 'all');
end
report = struct('n_targets', height(T), 'n_visible', nnz(T.surface_signature == "VISIBLE_DISTURBANCE"), ...
    'n_no_signature', nnz(T.surface_signature == "NONE"), 'tries', tries, 'min_pair_distance_m', dmin);
end
