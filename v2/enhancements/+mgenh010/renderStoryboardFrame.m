function [fig, info] = renderStoryboardFrame(state, varargin)
%RENDERSTORYBOARDFRAME Original offline intro cards, separate from mission UI.
%   CITY_CONTEXT is a named orientation card, not a city map. CAMPUS_CONTEXT
%   reuses ENH-009's schematic. SIMULATION_HANDOFF is a boundary card only.
p = inputParser;
addParameter(p, 'Visible', 'on', @(x) ischar(x) && any(strcmp(x, {'on','off'})));
parse(p, varargin{:});
state = string(state);
if ~isscalar(state) || ~any(state == ["CITY_CONTEXT", "CAMPUS_CONTEXT", "SIMULATION_HANDOFF"])
    error('mgenh010:InvalidStoryboard', 'Unknown presentation stage.');
end
if state == "CAMPUS_CONTEXT"
    [fig, fallback] = mgenh009.renderOfflineCampusContext('Visible',p.Results.Visible);
    info = struct('stage',state,'kind',"ORIGINAL_SCHEMATIC",'georeferenced',false, ...
        'mission_started',false,'fallback_status',fallback.asset_status, ...
        'label',"ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT");
    return;
end
if state == "CITY_CONTEXT"
    heading = 'BALLARI — CITY ORIENTATION';
    body = 'Named presentation context only. No map, coordinates or surveyed location.';
    foot = 'ILLUSTRATIVE / NOT SURVEYED / NO GEOGRAPHIC SCALE';
else
    heading = 'TRANSITION TO SEPARATE SYNTHETIC UAV SIMULATION';
    body = 'End of location introduction. Open the existing simulation separately.';
    foot = 'SIMULATION CONTEXT / NO REAL CAMPUS SURVEY OR DETECTION';
end
fig = figure('Visible',p.Results.Visible,'Name',heading,'NumberTitle','off', ...
    'Color',[0.96 0.97 0.96]);
try
    ax = axes('Parent',fig,'Position',[0.08 0.15 0.84 0.7]);
    axis(ax,[0 1 0 1]); axis(ax,'off');
    rectangle(ax,'Position',[0.03 0.08 0.94 0.84], 'FaceColor',[0.87 0.92 0.91], ...
        'EdgeColor',[0.20 0.35 0.37], 'LineWidth',2);
    text(ax,0.5,0.72,heading,'HorizontalAlignment','center','FontWeight','bold','FontSize',15,'Color',[0.08 0.14 0.16]);
    text(ax,0.5,0.48,body,'HorizontalAlignment','center','FontSize',10,'Color',[0.08 0.14 0.16]);
    text(ax,0.5,0.22,foot,'HorizontalAlignment','center','FontWeight','bold','FontSize',10, ...
        'Color',[0.42 0.17 0.10]);
    info = struct('stage',state,'kind',"ORIGINAL_TITLE_CARD",'georeferenced',false, ...
        'mission_started',false,'fallback_status',"NOT_APPLICABLE",'label',string(foot));
catch err
    if isgraphics(fig), close(fig); end
    rethrow(err);
end
end
