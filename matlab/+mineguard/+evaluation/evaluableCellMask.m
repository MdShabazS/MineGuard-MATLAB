function mask = evaluableCellMask(grid, poses, samples, methodName, rule)
%EVALUABLECELLMASK Observation-support mask (ny x nx logical). It uses NO truth.
%   mask = mineguard.evaluation.evaluableCellMask(grid, poses, samples, methodName, rule)
%   A legal cell is evaluable when at least one pose inside it (same cell rule as scoring) has
%   the modalities that methodName/rule need for a decision:
%     thermal_only: thermal valid (and EM valid too under require_both)
%     em_only:      EM valid (and thermal valid too under require_both)
%     or, weighted: single_valid -> either valid; abstain/require_both -> both valid
%     and:          both valid (every rule)
%   Validity is taken per pose_sample_id. Dropouts and out-of-domain samples therefore remove
%   support, so they can never create a true negative.
G = gridSpec(grid);
pid = string(poses.pose_sample_id);
tOk = ismember(pid, string(samples.pose_sample_id(samples.valid & samples.sensor_kind == "thermal")));
eOk = ismember(pid, string(samples.pose_sample_id(samples.valid & samples.sensor_kind == "em")));
switch string(methodName)
    case "thermal_only", need = tOk & (rule ~= "require_both" | eOk);
    case "em_only",      need = eOk & (rule ~= "require_both" | tOk);
    case {"or","weighted"}
        if rule == "single_valid", need = tOk | eOk; else, need = tOk & eOk; end
    case "and",          need = tOk & eOk;
    otherwise
        error('mineguard:InvalidEvaluationInput', 'MineGuard evaluation: unknown method "%s".', methodName);
end
[lin, inside] = cellIndex(G, poses.x_east_m, poses.y_north_m);
mask = false(G.ny, G.nx);
mask(lin(inside & need)) = true;
mask = mask & G.legal;
end
