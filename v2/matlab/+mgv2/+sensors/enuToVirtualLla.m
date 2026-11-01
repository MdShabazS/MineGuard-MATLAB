function lla = enuToVirtualLla(enu, origin)
%ENUTOVIRTUALLLA VIRTUAL geodetic coordinates from local ENU (small-field tangent-plane approximation).
%   lla = mgv2.sensors.enuToVirtualLla(enu, origin)    enu N-by-3 (m), origin [lat0 lon0 alt0] (deg, deg, m)
%   lat = lat0 + N / M(lat0), lon = lon0 + E / (Nr(lat0) cos lat0), alt = alt0 + U with WGS84 meridian (M)
%   and prime-vertical (Nr) radii. Valid for fields of a few km (error grows ~ d^2 / R). Base MATLAB only;
%   testV2005Sensors cross-checks it against MathWorks enu2lla when that function is available.
%   The coordinates are a VIRTUAL reference for display, never measured GNSS positions.
a = 6378137.0; f = 1 / 298.257223563; e2 = f * (2 - f);
lat0 = deg2rad(origin(1)); s2 = sin(lat0)^2;
M = a * (1 - e2) / (1 - e2 * s2)^1.5; Nr = a / sqrt(1 - e2 * s2);
lla = [origin(1) + rad2deg(enu(:,2) / M), origin(2) + rad2deg(enu(:,1) / (Nr * cos(lat0))), origin(3) + enu(:,3)];
end
