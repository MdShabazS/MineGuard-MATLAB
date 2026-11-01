function parts = quadrotorModel()
%QUADROTORMODEL Physically scaled multirotor mesh in the BODY frame (FLU, metres). SIMULATION ONLY.
%   parts = mgv2.scene.quadrotorModel()   struct array: name, V (n-by-3 body coords), F, rgb, alpha
%   Geometry: F450-class quadrotor, motor-to-motor diagonal 0.45 m (arm radius 0.225 m at +/-45 deg),
%   0.254 m (10 in) propeller discs, skid landing gear, nadir payload pod under the nose.
%   Body origin = centre of the landing-gear contact plane: skid bottoms are at z = 0, so a pose whose
%   z equals the terrain height renders the aircraft standing ON the ground, never in it.
%   Front arms are red/orange and rear arms grey, so heading is readable at a glance.
zArm = 0.17; Rm = 0.225; parts = struct('name', {}, 'V', {}, 'F', {}, 'rgb', {}, 'alpha', {});
parts(end+1) = box('fuselage', [0 0 0.175], [0.17 0.11 0.06], [0.18 0.19 0.21], 1);
parts(end+1) = box('canopy', [0.01 0 0.215], [0.12 0.08 0.025], [0.92 0.92 0.90], 1);
ang = deg2rad([45 -45 135 -135]); armCol = {[0.95 0.30 0.10], [0.95 0.30 0.10], [0.40 0.40 0.42], [0.40 0.40 0.42]};
for k = 1:4
    m = [Rm * cos(ang(k)), Rm * sin(ang(k))];
    parts(end+1) = beam(sprintf('arm%d', k), [0 0 zArm], [m zArm], 0.022, armCol{k}); %#ok<AGROW>
    parts(end+1) = cyl(sprintf('motor%d', k), [m zArm - 0.005], 0.02, 0.035, 12, [0.12 0.12 0.13], 1); %#ok<AGROW>
    parts(end+1) = cyl(sprintf('rotor%d', k), [m zArm + 0.035], 0.127, 0.004, 28, [0.75 0.80 0.85], 0.35); %#ok<AGROW>
end
for s = [-1 1]
    parts(end+1) = beam(sprintf('skid%+d', s), [-0.13 s * 0.10 0.008], [0.13 s * 0.10 0.008], 0.008, [0.10 0.10 0.10]); %#ok<AGROW>
    parts(end+1) = beam(sprintf('strutF%+d', s), [0.07 s * 0.10 0.008], [0.05 s * 0.05 0.15], 0.006, [0.10 0.10 0.10]); %#ok<AGROW>
    parts(end+1) = beam(sprintf('strutR%+d', s), [-0.07 s * 0.10 0.008], [-0.05 s * 0.05 0.15], 0.006, [0.10 0.10 0.10]); %#ok<AGROW>
end
parts(end+1) = box('payload_pod', [0.055 0 0.12], [0.06 0.07 0.05], [0.25 0.25 0.27], 1);
parts(end+1) = box('lens', [0.055 0 0.093], [0.025 0.025 0.006], [0.05 0.05 0.08], 1);
end

function p = box(name, c, s, rgb, alpha)
[X, Y, Z] = ndgrid([-0.5 0.5] * s(1), [-0.5 0.5] * s(2), [-0.5 0.5] * s(3));
V = [X(:) Y(:) Z(:)] + c;
F = [1 3 4 2; 5 6 8 7; 1 2 6 5; 3 7 8 4; 1 5 7 3; 2 4 8 6];
F = [F(:, [1 2 3]); F(:, [1 3 4])];
p = struct('name', string(name), 'V', V, 'F', F, 'rgb', rgb, 'alpha', alpha);
end

function p = beam(name, a, b, r, rgb)
% square-section beam from a to b with half-width r
d = b - a; L = norm(d); u = d / L;
t = cross(u, [0 0 1]); if norm(t) < 1e-6, t = cross(u, [0 1 0]); end
t = t / norm(t); w = cross(u, t);
o = [t + w; t - w; -t - w; -t + w] * r;
V = [a + o; b + o];
F = [1 2 6; 1 6 5; 2 3 7; 2 7 6; 3 4 8; 3 8 7; 4 1 5; 4 5 8; 1 4 3; 1 3 2; 5 6 7; 5 7 8];
p = struct('name', string(name), 'V', V, 'F', F, 'rgb', rgb, 'alpha', 1);
end

function p = cyl(name, c, r, h, n, rgb, alpha)
a = (0:n-1)' * 2 * pi / n; ring = [r * cos(a), r * sin(a)];
V = [ring + c(1:2), c(3) + zeros(n, 1); ring + c(1:2), c(3) + h + zeros(n, 1); c(1:2) c(3); c(1:2) c(3) + h];
k = (1:n)'; k2 = mod(k, n) + 1;
F = [k k2 k2 + n; k k2 + n k + n; repmat(2*n + 1, n, 1) k2 k; repmat(2*n + 2, n, 1) k + n k2 + n];
p = struct('name', string(name), 'V', V, 'F', F, 'rgb', rgb, 'alpha', alpha);
end
