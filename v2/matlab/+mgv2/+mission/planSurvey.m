function plan = planSurvey(cfg)
%PLANSURVEY Boustrophedon (lawnmower) coverage lines over a convex survey polygon. SIMULATION ONLY.
%   plan = mgv2.mission.planSurvey(cfg)       cfg: validated MissionConfig
%   Lines run along compass heading cfg.survey_heading_deg, spaced cfg.line_spacing_m, the first and
%   last lines inset by half a spacing so each line covers a swath of +/- spacing/2 (Galceran &
%   Carreras 2013; Cabreira et al. 2019: back-and-forth decomposition for convex regions). Successive
%   lines alternate direction, so turns happen at the polygon edge.
%   plan fields: waypoints_xy (N-by-2, ENU metres, in flight order), line_id (N-by-1), n_lines,
%                line_dir_xy (unit ENU direction of line 1), survey_length_m.
%   Throws mgv2:UnreachableMission if no line fits inside the polygon.
P = cfg.survey_polygon_enu_m;
h = deg2rad(cfg.survey_heading_deg);
d = [sin(h), cos(h)];             % compass heading -> ENU unit vector (east, north)
n = [-d(2), d(1)];                % left-hand normal
proj = P * n';                    % offsets of polygon vertices across the lines
lo = min(proj); hi = max(proj); w = hi - lo;
sp = cfg.line_spacing_m;
nl = max(1, ceil(w / sp - 1e-9));
if w < 1e-6
    error('mgv2:UnreachableMission', 'Survey polygon has zero width across the line direction.');
end
offs = lo + (w - (nl - 1) * sp) / 2 + (0:nl-1)' * sp;   % centred, spacing-sp lines
offs = offs(offs > lo - 1e-9 & offs < hi + 1e-9);
wp = zeros(0, 2); lid = zeros(0, 1); k = 0;
for i = 1:numel(offs)
    [s0, s1, ok] = chord(P, d, n, offs(i));
    if ~ok || s1 - s0 < 1e-6, continue; end
    k = k + 1;
    a = offs(i) * n + s0 * d; b = offs(i) * n + s1 * d;
    if mod(k, 2) == 0, [a, b] = deal(b, a); end
    wp = [wp; a; b]; lid = [lid; k; k]; %#ok<AGROW>
end
if isempty(wp)
    error('mgv2:UnreachableMission', 'No survey line fits inside the polygon at spacing %.2f m.', sp);
end
seg = diff(wp); len = sum(vecnorm(seg, 2, 2));
plan = struct('waypoints_xy', wp, 'line_id', lid, 'n_lines', k, 'line_dir_xy', d, 'survey_length_m', len);
end

function [s0, s1, ok] = chord(P, d, n, off)
% Intersect the line {off*n + s*d} with the convex polygon; return the s-interval.
m = size(P, 1); s = [];
for i = 1:m
    a = P(i,:); b = P(mod(i, m)+1, :);
    pa = a * n' - off; pb = b * n' - off;
    if abs(pa) < 1e-12, s(end+1) = a * d'; end %#ok<AGROW>
    if pa * pb < 0
        t = pa / (pa - pb); x = a + t * (b - a); s(end+1) = x * d'; %#ok<AGROW>
    end
end
ok = numel(s) >= 2; s0 = min([s, inf]); s1 = max([s, -inf]);
end
