function names = truthFieldNames()
%TRUTHFIELDNAMES Field names that must never appear in data given to navigation,
%   detection, fusion or RL inputs (mg-contract/1.0 rule 6, ground-truth firewall).
%   Keeping the list here lets consumer modules enforce the firewall without naming
%   truth fields in their own source code.
names = ["hidden_truth","TargetTruth","truth","target_id","label","burial_depth_m", ...
    "material_type","target_count","clutter_count","surface_exposed","x_east_m","y_north_m"];
end
