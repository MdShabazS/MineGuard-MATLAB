function w = wording()
%WORDING Standard result wording for every V2.2 view (V22-T10). Basis: IMAS 07.11 Land release (Ed.2, 2026):
%   indirect evidence can only create a SUSPECTED hazardous area, and decisions rest on evidence, not its absence.
%   w = mgv22.wording()
%   w.suspected    label for any detector output shown to a person
%   w.no_detection sentence to show wherever an empty map or zero detections could be misread
%   w.scope        one-line project scope
%   w.forbidden    words never used in result text (lower case); see the test that scans the v2_2 views
w = struct( ...
    'suspected', "SIMULATION – suspected anomaly, indirect evidence only – not for operational use", ...
    'no_detection', "No suspected anomaly found in simulation. This does not mean the ground is free of hazards.", ...
    'scope', "MineGuard is a simulation concept demonstrator, not a validated landmine detector.", ...
    'forbidden', ["clear", "cleared", "safe", "mine found", "mines found", "mine detected", "mines detected", "mine-free", "hazard-free"]);
end
