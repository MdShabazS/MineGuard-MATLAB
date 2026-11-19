function enu_m = wgs84ToEnu(lla, anchor_lla)
%WGS84TOENU Convert geodetic WGS84 points to a local ENU frame at an anchor.
%   enu_m = mgv22.geo.wgs84ToEnu(lla, anchor_lla)
%   lla        N-by-3 [latitude longitude ellipsoidal_height] deg, deg, m
%   anchor_lla 1-by-3 [latitude longitude ellipsoidal_height] deg, deg, m
%   enu_m      N-by-3 [east north up] metres relative to anchor
%
%   Exact inverse of mgv22.geo.enuToWgs84: closed-form WGS84 geodetic -> ECEF,
%   subtract the anchor ECEF, rotate into the anchor tangent frame. Base MATLAB.
%   Same anchor checks (and error IDs) as enuToWgs84. Added for V22-T4.
%   Coordinates are for simulated geographic CONTEXT only.
arguments
    lla (:,3) double {mustBeFinite}
    anchor_lla (1,3) double {mustBeFinite}
end
if hypot(anchor_lla(1), anchor_lla(2)) < 0.01      % about 1 km: tiny offsets from the placeholder are not an explicit anchor
    error('mgv22:MissingGeographicAnchor', ...
        'The [0 0 0] virtual origin is a placeholder. Supply an explicit demo anchor.');
end
lat0 = anchor_lla(1); lon0 = anchor_lla(2); h0 = anchor_lla(3);
if abs(lat0) >= 80 || abs(lon0) >= 179 || h0 < -500 || h0 > 9000
    error('mgv22:UnsupportedGeographicAnchor', ...
        'Preview anchor must be within 80 deg latitude, 179 deg longitude and -500..9000 m ellipsoid height.');
end
if isempty(lla)
    enu_m = zeros(0,3);
    return
end

% WGS84 geodetic -> ECEF (closed form), for the anchor and every point.
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

phi = deg2rad(lla(:,1));
lam = deg2rad(lla(:,2));
h = lla(:,3);
N = a ./ sqrt(1 - e2 * sin(phi).^2);
dx = (N + h) .* cos(phi) .* cos(lam) - x0;
dy = (N + h) .* cos(phi) .* sin(lam) - y0;
dz = (N .* (1 - e2) + h) .* sin(phi) - z0;

% ECEF offset -> ENU (transpose of the rotation used in enuToWgs84).
e = -sl * dx + cl * dy;
n = -sp * cl * dx - sp * sl * dy + cp * dz;
u = cp * cl * dx + cp * sl * dy + sp * dz;
enu_m = [e, n, u];
end
