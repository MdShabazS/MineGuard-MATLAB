function M = setupMarkers(spec, phase)
%SETUPMARKERS Target markers the guide's map may draw: MANUAL targets during SETUP only, otherwise none.
%   M = mgv21.placement.setupMarkers(spec, phase)     phase: "SETUP" or anything else (e.g. "LOCKED", "RUN")
%   M  table x_east_m, y_north_m, surface_signature. EMPTY unless phase == "SETUP" and spec.mode == "MANUAL":
%      random targets are never shown, and after LOCK every marker disappears.
spec = checkSpec(spec);
M = spec.manual(:, ["x_east_m","y_north_m","surface_signature"]);
if ~(string(phase) == "SETUP" && spec.mode == "MANUAL"), M = M([], :); end
end
