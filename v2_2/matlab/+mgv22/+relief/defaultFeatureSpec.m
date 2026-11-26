function spec = defaultFeatureSpec()
%DEFAULTFEATURESPEC Demonstration set of SYNTHETIC conflict relief features inside the default field (V22-T12).
%   spec = mgv22.relief.defaultFeatureSpec()
%   Struct array, all inside |x| <= 35 m, |y| <= 25 m (ENU): two craters, a cluster of three foxholes, one trench.
%   Sizes follow the HALO Trust Angola LiDAR trial (craters about 5.9 m wide and 0.65 m deep; foxholes about
%   0.6-0.8 m deep and 1-1.5 m across; trenches long and narrow). The features are SYNTHETIC, not survey data.
%   Fields: type ("crater"|"foxhole"|"trench"), center_enu_m (1x2, NaN for a trench), diameter_m, depth_m,
%   p1, p2 (1x2 trench ends, NaN otherwise), width_m (trench only, NaN otherwise).
n = NaN(1, 2);
spec = [pit("crater", [15 10], 5.9, 0.65), pit("crater", [-20 -8], 5.9, 0.65), ...
    pit("foxhole", [-5 12], 1.2, 0.7), pit("foxhole", [-2 13.5], 1.2, 0.7), pit("foxhole", [1 12.2], 1.2, 0.7), ...
    struct('type', "trench", 'center_enu_m', n, 'diameter_m', NaN, 'depth_m', 0.8, 'p1', [-30 -20], 'p2', [5 -18], 'width_m', 1.0)];

    function s = pit(t, c, dia, dep)
        s = struct('type', t, 'center_enu_m', c, 'diameter_m', dia, 'depth_m', dep, 'p1', n, 'p2', n, 'width_m', NaN);
    end
end
