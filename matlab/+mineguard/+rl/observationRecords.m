function [observation, allowedCells] = observationRecords(S, G, cfg, scenarioId)
%OBSERVATIONRECORDS Build the view-only observation struct and allowed-cell table for selectSurveyCell.
observation = struct('schema_version', "mg013-obs/1.0", 'scenario_id', string(scenarioId), ...
    'layout_id', cfg.layout_id, 'vector', mineguard.rl.observationVector(S, G, cfg));
allowedCells = table((1:G.N)', G.centers(:,1), G.centers(:,2), G.legal, G.reach(S.cell, :)', S.visited, ...
    'VariableNames', {'cell_id','x_center_m','y_center_m','is_legal','reachable_from_current','is_visited'});
end
