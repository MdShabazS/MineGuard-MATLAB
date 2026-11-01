function L = toMapLayers(S, ev, coverageRevision, eventRevision)
%TOMAPLAYERS UI overlay layers from a MissionMap snapshot and mapped events. SIMULATED.
%   L = mgv2.bridge.toMapLayers(S, ev, coverageRevision, eventRevision)
%   Coverage raster: cell_state with the MapView colours. UNOBSERVED cells have alpha 0, so they stay absent.
%   Coverage is evidence acquisition only: it is never a statement about hazards or land release.
%   Event markers: a points layer of estimated positions, absent when there are no events.
%   No route layer is produced: MapPanel owns the plan, UAV and flown route.
C = double(S.cell_state) + 1; rgba = mgv2.map.MapView.StateRGBA;
L = struct('id', "v2006_coverage", 'display_name', "Sensor evidence coverage (evidence acquisition only)", 'kind', "raster", ...
    'revision', coverageRevision, 'color', [1 1 1], 'x_enu_m', S.cell_x_m, 'y_enu_m', S.cell_y_m, ...
    'cdata', reshape(rgba(C(:), 1:3), [size(C) 3]), 'alpha', reshape(rgba(C(:), 4), size(C)));
if ~isempty(ev)
    L(2, 1) = struct('id', "v2006_suspected", 'display_name', "SUSPECTED events (simulated, uncalibrated)", 'kind', "points", ...
        'revision', eventRevision, 'color', [0.9 0 0.9], 'x_enu_m', [ev.x_est_m], 'y_enu_m', [ev.y_est_m], 'cdata', [], 'alpha', []);
end
mgv2.sensors.assertPublic(L, "bridgeLayers");
end
