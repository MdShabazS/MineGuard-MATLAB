function v = requireParam(s, channel, name, rule)
%REQUIREPARAM Read a required sensor parameter and check it. No defaults are substituted.
%   rule: "finite" | "positive" | "nonneg" | "halfangle" | "text" | "prob"
id = 'mineguard:InvalidSensorConfig';
if ~isfield(s, name)
    error(id, 'MineGuard sensors: sensor_settings.%s.%s is required (no default is invented).', channel, name);
end
v = s.(name);
if rule == "text"
    if ~((ischar(v) && isrow(v)) || (isstring(v) && isscalar(v) && ~ismissing(v))) || strlength(string(v)) == 0
        error(id, 'MineGuard sensors: sensor_settings.%s.%s must be nonempty text.', channel, name);
    end
    v = string(v);
    return
end
if ~(isnumeric(v) && isreal(v) && isscalar(v)) || ~isfinite(v)
    error(id, 'MineGuard sensors: sensor_settings.%s.%s must be a finite real scalar (NaN/Inf rejected).', channel, name);
end
v = double(v);
switch rule
    case "positive"
        ok = v > 0;
    case "nonneg"
        ok = v >= 0;
    case "halfangle"
        ok = v > 0 && v < pi/2;
    case "prob"
        ok = v >= 0 && v <= 1;
    otherwise
        ok = true;
end
if ~ok
    error(id, 'MineGuard sensors: sensor_settings.%s.%s = %g violates rule "%s".', channel, name, v, rule);
end
end
