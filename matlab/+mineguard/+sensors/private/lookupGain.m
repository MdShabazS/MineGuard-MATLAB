function gain = lookupGain(lookup, materials, channel, lookupName)
%LOOKUPGAIN Per-object model gain from a documented material lookup struct.
%   Every material present in the truth table must have an explicit finite entry.
%   An unknown material is an error and never defaults to a "detectable" gain.
id = 'mineguard:InvalidSensorConfig';
if ~isstruct(lookup) || ~isscalar(lookup)
    error(id, 'MineGuard sensors: sensor_settings.%s.%s must be a struct mapping material_type to gain.', channel, lookupName);
end
materials = string(materials);
gain = zeros(numel(materials), 1);
for k = 1:numel(materials)
    m = materials(k);
    if ~isvarname(m) || ~isfield(lookup, m)
        error(id, 'MineGuard sensors: material "%s" has no entry in sensor_settings.%s.%s (unknown materials are unsupported).', m, channel, lookupName);
    end
    g = lookup.(m);
    if ~(isnumeric(g) && isreal(g) && isscalar(g) && isfinite(g))
        error(id, 'MineGuard sensors: sensor_settings.%s.%s.%s must be a finite real scalar.', channel, lookupName, m);
    end
    gain(k) = double(g);
end
end
