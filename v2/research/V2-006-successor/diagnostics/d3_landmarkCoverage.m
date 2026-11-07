function T = d3_landmarkCoverage(dataDir)
%D3_LANDMARKCOVERAGE Reported sigma against PUBLIC landmark error in the committed TRAIN tracks. No target truth is read.
%   Committed TRAIN sigma is pre-fix (evidence V2-006 section 3), so sqrt(sigma^2 + pose^2) reconstructs the current form.
G = mgv2.eval.scenarioGroups(); G = G([G.split] == "TRAIN"); p = mgv2.detect.defaultDetectorConfig().association.pose_sigma_m; rows = {};
for g = reshape(G, 1, [])
    D = readtable(fullfile(dataDir, "train_tracks_" + g.group_id + ".csv"), 'TextType', 'string'); pub = mgv2.eval.buildScenario(g);
    for L = reshape(pub.world.landmarks, 1, [])
        d = hypot(D.x_m - L.xy(1), D.y_m - L.xy(2)); [~, j] = sort(d); j = j(d(j) <= L.radius_m + 1);
        if isempty(j), continue; end
        [~, b] = max(D.n_obs_rgb(j) + D.n_obs_thermal(j)); k = j(b); e = [D.x_m(k) - L.xy(1), D.y_m(k) - L.xy(2)]; s = hypot(D.sigma_m(k), p);
        rows(end+1, :) = {g.group_id, L.id, D.n_obs_rgb(k) + D.n_obs_thermal(k), norm(e), D.sigma_m(k), s, abs(e(1)) / s, abs(e(2)) / s, numel(j)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', ["group","landmark","n_obs","error_m","sigma_committed_m","sigma_current_form_m","z_x","z_y","tracks_near"]); disp(T);
z = [T.z_x; T.z_y]; fprintf('per-axis |z| n=%d: within 1 sigma %.2f, within 2 sigma %.2f (a calibrated Gaussian gives 0.68, 0.95); median error %.3f m\n', numel(z), mean(z <= 1), mean(z <= 2), median(T.error_m));
fprintf('A landmark is large and high-contrast and its centre need not be the centroid of a halo, so this is one narrow check, not coverage for small objects.\n');
end
