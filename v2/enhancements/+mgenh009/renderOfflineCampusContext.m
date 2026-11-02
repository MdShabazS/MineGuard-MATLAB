function [fig, info] = renderOfflineCampusContext(varargin)
%RENDEROFFLINECAMPUSCONTEXT Draw an original, non-geographic campus-context schematic.
%   [fig, info] = mgenh009.renderOfflineCampusContext('Visible','off', ...
%       'AssetPath','missing.png') uses only MATLAB graphics. An asset is never
%   loaded: rights and campus bounds have not been approved. AssetPath lets a
%   future integration request an asset and receive an explicit fallback status.
%   Caller owns and closes the returned figure. No timers or callbacks are made.
p = inputParser;
addParameter(p, 'Visible', 'on', @(x) ischar(x) && any(strcmp(x, {'on','off'})));
addParameter(p, 'AssetPath', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(p, varargin{:});
assetPath = char(p.Results.AssetPath);
if isempty(assetPath)
    assetStatus = "NOT_REQUESTED";
elseif isfile(assetPath)
    assetStatus = "PRESENT_NOT_APPROVED_SCHEMATIC_USED";
else
    assetStatus = "MISSING_SCHEMATIC_USED";
end

% Coordinates are arbitrary page units; no WGS84, ENU or surveyed geometry.
buildings = [12 22 18 12; 48 24 22 13; 16 65 23 12; 59 62 20 13];
paths = [5 50 95 50; 44 8 44 91; 8 15 92 85];
labels = ["ILLUSTRATIVE"; "NOT SURVEYED"; "SIMULATION CONTEXT"];
fig = figure('Visible', p.Results.Visible, 'Name', 'Illustrative campus context', ...
    'NumberTitle', 'off', 'Color', [0.97 0.97 0.95]);
try
    ax = axes('Parent', fig, 'Position', [0.07 0.13 0.86 0.69]);
    hold(ax, 'on'); axis(ax, [0 100 0 100]); axis(ax, 'equal'); axis(ax, 'off');
    rectangle(ax, 'Position', [3 3 94 94], 'FaceColor', [0.88 0.92 0.84], ...
        'EdgeColor', [0.45 0.55 0.43], 'LineWidth', 1.5);
    for k = 1:size(paths,1)
        line(ax, paths(k,[1 3]), paths(k,[2 4]), 'Color', [0.72 0.70 0.61], 'LineWidth', 7);
    end
    for k = 1:size(buildings,1)
        rectangle(ax, 'Position', buildings(k,:), 'FaceColor', [0.48 0.59 0.66], ...
            'EdgeColor', [0.26 0.36 0.42], 'LineWidth', 1.2);
    end
    text(ax, 50, 94, 'SCHEMATIC CAMPUS CONTEXT', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'Color', [0.12 0.20 0.25]);
    text(ax, 50, 4, 'Arbitrary diagram units — no real campus footprint or flight path', ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.15 0.19 0.15]);
    annotation(fig, 'textbox', [0.07 0.82 0.86 0.12], 'String', ...
        'ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 12, ...
        'Color', [0.38 0.16 0.10]);
    info = struct('schema_version', "mgenh009/1", 'kind', "ORIGINAL_SCHEMATIC", ...
        'coordinate_frame', "ARBITRARY_DIAGRAM_UNITS", 'georeferenced', false, ...
        'asset_status', assetStatus, 'labels', labels, 'buildings', buildings, 'paths', paths);
catch err
    if isgraphics(fig), close(fig); end
    rethrow(err);
end
end
