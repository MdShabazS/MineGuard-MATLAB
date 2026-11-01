function [rgb, cmap, lim] = thermalPalette(temperature_K, paletteId, lim)
%THERMALPALETTE DISPLAY-ONLY false colour for an apparent-temperature raster (never changes the Kelvin data).
%   [rgb, cmap, lim] = mgv2.sensors.thermalPalette(temperature_K, paletteId)
%   [rgb, cmap, lim] = mgv2.sensors.thermalPalette(temperature_K, paletteId, [minK maxK])
%   paletteId: "IRONBOW" | "WHITE_HOT" | "BLACK_HOT" | "TURBO". NaN (invalid) pixels are shown dark grey.
%   The input array is only read; the returned rgb is a separate uint8 image for the GUI. Use
%   lim - 273.15 for a Celsius legend; the scientific sample stays in K.
if nargin < 3 || isempty(lim)
    v = temperature_K(isfinite(temperature_K));
    if isempty(v), lim = [0 1]; else, lim = [min(v) max(v)]; end
    if diff(lim) < 1e-6, lim = lim + [-0.5 0.5]; end
end
n = 256;
switch upper(string(paletteId))
    case "IRONBOW"
        k = [0 0 0; 0.13 0 0.45; 0.55 0 0.6; 0.85 0.25 0.1; 1 0.65 0; 1 1 0.75];
        cmap = interp1(linspace(0, 1, size(k, 1)), k, linspace(0, 1, n));
    case "WHITE_HOT", cmap = repmat(linspace(0, 1, n)', 1, 3);
    case "BLACK_HOT", cmap = repmat(linspace(1, 0, n)', 1, 3);
    case "TURBO", cmap = turbo(n);
    otherwise, error('mgv2:InvalidSensorConfig', 'Unknown palette "%s".', string(paletteId));
end
idx = round((temperature_K - lim(1)) / diff(lim) * (n - 1)) + 1;
idx = min(max(idx, 1), n);
ok = isfinite(temperature_K); idx(~ok) = 1;
rgb = zeros([size(temperature_K) 3]);
for c = 1:3
    ch = reshape(cmap(idx, c), size(temperature_K)); ch(~ok) = 0.25; rgb(:, :, c) = ch;
end
rgb = uint8(round(255 * rgb));
end
