function P = planeFromSlope(z0, x0, y0, slopePct, headingDeg)
%PLANEFROMSLOPE Design plane through a point, falling slopePct percent toward a compass heading.
%   P = mgv22.cutfill.planeFromSlope(z0, x0, y0, slopePct, headingDeg)
%   (x0, y0, z0) in ENU metres; slopePct in [0,100]; headingDeg is the downhill azimuth (clockwise from
%   north), normalised to [0,360). Returns the same struct as mgv22.cutfill.fitPlane: z = a + b*x + c*y.
args = [z0, x0, y0, slopePct, headingDeg];
if ~isnumeric(args) || numel(args) ~= 5 || any(~isfinite(args))
    error('mgv22:InvalidPlane', 'Plane inputs must be finite scalars.');
end
if slopePct < 0 || slopePct > 100
    error('mgv22:InvalidPlane', 'Slope must be between 0 and 100 percent.');
end
h = mod(headingDeg, 360); s = slopePct/100;
b = -s*sind(h); c = -s*cosd(h);
P = struct('a', z0 - b*x0 - c*y0, 'b', b, 'c', c, 'slope_pct', slopePct, 'heading_deg', h);
if slopePct == 0, P.heading_deg = 0; end
end
