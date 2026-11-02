function t = theme()
%THEME Shared restrained dark palette and fonts of the mission-control UI (display only).
%   t = mgv2.ui.theme()
t = struct('bg', [0.09 0.10 0.12], 'panel', [0.14 0.15 0.18], 'text', [0.92 0.93 0.95], 'muted', [0.68 0.71 0.76], ...
    'sky', [0.58 0.72 0.86], 'bannerBg', [0.50 0.05 0.05], 'bannerFg', [1 1 1], ...
    'valid', [0.45 0.85 0.55], 'invalid', [1 0.72 0.25], 'stale', [1 0.45 0.40], 'none', [0.68 0.71 0.76], ...
    'mono', monoFont(), 'warning', "SIMULATION ONLY: synthetic sensors on a synthetic scene. Suspected anomalies are NOT verified mines; a virtually scanned cell is NOT physically safe.");
end

function f = monoFont()
if ismac, f = 'Menlo'; elseif ispc, f = 'Consolas'; else, f = 'Courier New'; end
end
