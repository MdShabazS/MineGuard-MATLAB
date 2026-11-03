function spec = defaultPlacement(mode)
%DEFAULTPLACEMENT PRIVATE PlacementSpec (mg-v21-placement/1.0) for the guide's SETUP panel. SIMULATION ONLY.
%   spec = mgv21.placement.defaultPlacement()            mode "NONE" (no targets)
%   spec = mgv21.placement.defaultPlacement(mode)        "NONE" | "MANUAL" | "RANDOM"
%   Fields: schema_version, mode, seed (RANDOM positions), clutter_seed (clutter and feature appearance),
%   count (RANDOM, 0..50), visible_fraction (RANDOM share with a VISIBLE_DISTURBANCE signature),
%   min_spacing_m, edge_margin_m, exclusion_zones (struct array: kind, center_enu_m, radius_m, polygon_enu_m),
%   manual (table: x_east_m, y_north_m, surface_signature, burial_depth_m).
%   The spec is PRIVATE: it never enters PublicMissionConfig, sensors, detector, live map or export.
if nargin < 1, mode = "NONE"; end
mode = upper(string(mode));
if ~(isscalar(mode) && ismember(mode, mgv21.contract().placement_modes))
    error('mgv21:InvalidPlacement', 'mode must be NONE, MANUAL or RANDOM.');
end
spec = struct('schema_version', mgv21.contract().schemas.placement, 'mode', mode, 'seed', 1, 'clutter_seed', 7007, ...
    'count', 5 * (mode == "RANDOM"), 'visible_fraction', 0.75, 'min_spacing_m', 3, 'edge_margin_m', 1, ...
    'exclusion_zones', emptyZones(), 'manual', emptyManual());
end
