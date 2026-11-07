function P = rectangleBoundary(xmin, xmax, ymin, ymax)
%RECTANGLEBOUNDARY Axis-aligned rectangular survey boundary, counter-clockwise, ENU metres.
%   P = mgv21.scenario.rectangleBoundary(xmin, xmax, ymin, ymax)     -> 4-by-2
%   Throws mgv21:InvalidSurvey unless all four values are finite with xmax > xmin and ymax > ymin.
v = [xmin xmax ymin ymax];
if ~(isnumeric(v) && numel(v) == 4 && all(isfinite(v)) && xmax > xmin && ymax > ymin)
    error('mgv21:InvalidSurvey', 'Rectangle needs finite xmin < xmax and ymin < ymax.');
end
P = double([xmin ymin; xmax ymin; xmax ymax; xmin ymax]);
end
