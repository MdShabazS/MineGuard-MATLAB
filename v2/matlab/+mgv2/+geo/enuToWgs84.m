function lla = enuToWgs84(enu_m, anchor_lla)
%ENUTOWGS84 Convert a small synthetic local ENU survey to geodetic WGS84.
%   lla = mgv2.geo.enuToWgs84(enu_m, anchor_lla)
%   enu_m      N-by-3 [east north up] metres relative to anchor
%   anchor_lla 1-by-3 [latitude longitude ellipsoidal_height] deg, deg, m
%   lla        N-by-3 [latitude longitude ellipsoidal_height] deg, deg, m
%
%   Base MATLAB; no Mapping Toolbox requirement. ECEF translation + iterative
%   WGS84 geodetic inversion, NOT a spherical flat-earth map projection.
%   Supports only short, user-anchored research survey visualization (<10 km).
%   Rejects anchors at or near the project's [0 0 0] placeholder, polar and dateline
%   cases. Coordinates are for simulated geographic CONTEXT only.
%
%   This code MUST NOT be connected to detector target truth or clearance claims.
arguments
    enu_m (:,3) double {mustBeFinite}
    anchor_lla (1,3) double {mustBeFinite}
end
if hypot(anchor_lla(1), anchor_lla(2)) < 0.01      % about 1 km: tiny offsets from the placeholder are not an explicit anchor
    error('mgv2:MissingGeographicAnchor', ...
        'The [0 0 0] virtual origin is a placeholder. Supply an explicit demo anchor.');
end
lat0 = anchor_lla(1); lon0 = anchor_lla(2); h0 = anchor_lla(3);
if abs(lat0) >= 80 || abs(lon0) >= 179 || h0 < -500 || h0 > 9000
    error('mgv2:UnsupportedGeographicAnchor', ...
        'Preview anchor must be within 80 deg latitude, 179 deg longitude and -500..9000 m ellipsoid height.');
end
if ~isempty(enu_m) && any(hypot(enu_m(:,1), enu_m(:,2)) > 10000 | abs(enu_m(:,3)) > 10000)
    error('mgv2:GeographicExtentTooLarge', ...
        'The optional preview is restricted to horizontal and vertical offsets within 10 km of its WGS84 anchor.');
end
if isempty(enu_m)
    lla = zeros(0,3);
    return
end

% Geodetic origin -> Earth-centered Earth-fixed (ECEF), WGS84.
a = 6378137.0;
f = 1 / 298.257223563;
e2 = f * (2 - f);
phi0 = deg2rad(lat0);
lam0 = deg2rad(lon0);
sp = sin(phi0); cp = cos(phi0); sl = sin(lam0); cl = cos(lam0);
N0 = a / sqrt(1 - e2 * sp^2);
x0 = (N0 + h0) * cp * cl;
y0 = (N0 + h0) * cp * sl;
z0 = (N0 * (1 - e2) + h0) * sp;

% ENU -> ECEF using an orthonormal tangent-frame rotation.
e = enu_m(:,1);
n = enu_m(:,2);
u = enu_m(:,3);
x = x0 - sl * e - sp * cl * n + cp * cl * u;
y = y0 + cl * e - sp * sl * n + cp * sl * u;
z = z0 + cp * n + sp * u;

% ECEF -> geodetic; repeated fixed-point update at this short-range scale.
p = hypot(x, y);
phi = atan2(z, p .* (1 - e2));
for k = 1:8
    N = a ./ sqrt(1 - e2 * sin(phi).^2);
    phi = atan2(z + e2 * N .* sin(phi), p);
end
N = a ./ sqrt(1 - e2 * sin(phi).^2);
height_m = p ./ cos(phi) - N;
lla = [rad2deg(phi), rad2deg(atan2(y, x)), height_m];
end
