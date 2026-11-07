function T = emptyManual()
%EMPTYMANUAL Empty manual-target table with the contract columns.
T = table('Size', [0 4], 'VariableTypes', ["double","double","string","double"], ...
    'VariableNames', ["x_east_m","y_north_m","surface_signature","burial_depth_m"]);
end
