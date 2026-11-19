function tests = testV22Geo
%TESTV22GEO Pure-math tests for mgv22.geo (enuToWgs84 / wgs84ToEnu), base MATLAB.
%   Geo tests ported from c3c12af (v2/matlab/tests/testV2SatelliteGeo.m) for V22-T4,
%   plus round-trip tests for the new inverse. No tile servers, no graphics.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))),'matlab')));
end

function testZeroOffsetIsExplicitAnchor(tc)
a = [12.983, 77.594, 915];
lla = mgv22.geo.enuToWgs84([0 0 0],a);
verifyEqual(tc,lla(1:2),a(1:2),'AbsTol',1e-10);
verifyEqual(tc,lla(3),a(3),'AbsTol',1e-5);
end

function testEastNorthAndAltitudeSigns(tc)
a = [12.983, 77.594, 915];
lla = mgv22.geo.enuToWgs84([100 0 0; 0 100 0; 0 0 20],a);
verifyGreaterThan(tc,lla(1,2),a(2));
verifyLessThan(tc,abs(lla(1,1)-a(1)),1e-6);
verifyGreaterThan(tc,lla(2,1),a(1));
verifyLessThan(tc,abs(lla(2,2)-a(2)),1e-6);
verifyEqual(tc,lla(3,3),a(3)+20,'AbsTol',1e-5);
end

function testDeterministicAndVectorized(tc)
a = [-20.5, 110.3, 50];
pts = [0 0 0; 120 -80 2; -50 60 1];
x=mgv22.geo.enuToWgs84(pts,a);
y=mgv22.geo.enuToWgs84(pts,a);
verifySize(tc,x,[3 3]);
verifyEqual(tc,x,y);
verifyTrue(tc,all(isfinite(x),'all'));
end

function testPlaceholderOriginRejected(tc)
verifyError(tc,@() mgv22.geo.enuToWgs84([0 0 0],[0 0 0]), ...
    'mgv22:MissingGeographicAnchor');
end

function testPolarAndDatelineOriginsRejected(tc)
verifyError(tc,@() mgv22.geo.enuToWgs84([0 0 0],[85 10 0]), ...
    'mgv22:UnsupportedGeographicAnchor');
verifyError(tc,@() mgv22.geo.enuToWgs84([0 0 0],[20 179.5 0]), ...
    'mgv22:UnsupportedGeographicAnchor');
end

function testTooLargeExtentRejected(tc)
verifyError(tc,@() mgv22.geo.enuToWgs84([11000 0 0],[10 60 0]), ...
    'mgv22:GeographicExtentTooLarge');
end

function testNearNullGeographicAnchorRejected(tc)
anchors = [0 0 1e-9; 1e-9 0 0; 0 0 5; 0.005 -0.005 100];
for i = 1:size(anchors,1)
    a = anchors(i,:);
    verifyError(tc,@() mgv22.geo.enuToWgs84([0 0 0],a), ...
        'mgv22:MissingGeographicAnchor');
end
end

function testExtremeVerticalOffsetRejected(tc)
verifyError(tc,@() mgv22.geo.enuToWgs84([0 0 5e6],[12.983 77.594 915]), ...
    'mgv22:GeographicExtentTooLarge');
end

function testAnchorJustBeyondPlaceholderAccepted(tc)
lla = mgv22.geo.enuToWgs84([0 0 0],[0.02 0 5]);
verifyEqual(tc,lla(1:2),[0.02 0],'AbsTol',1e-10);
end

function testVerticalOffsetLimitIsInclusive(tc)
lla = mgv22.geo.enuToWgs84([0 0 10000],[12.983 77.594 915]);
verifyEqual(tc,lla(3),10915,'AbsTol',1e-5);
verifyError(tc,@() mgv22.geo.enuToWgs84([0 0 -10001],[12.983 77.594 915]), ...
    'mgv22:GeographicExtentTooLarge');
end

function testRoundTripWithinOneCentimetre(tc)
a = [15.1682 76.8504 0];   % BITM demo anchor
[e,n,u] = ndgrid(-300:50:300, -300:50:300, 0:20:60);
pts = [e(:) n(:) u(:)];
back = mgv22.geo.wgs84ToEnu(mgv22.geo.enuToWgs84(pts,a),a);
verifySize(tc,back,size(pts));
verifyEqual(tc,back,pts,'AbsTol',1e-2);
end

function testAnchorMapsToOrigin(tc)
a = [15.1682 76.8504 0];
verifyEqual(tc,mgv22.geo.wgs84ToEnu(a,a),[0 0 0],'AbsTol',1e-6);
end

function testInversePlaceholderOriginRejected(tc)
verifyError(tc,@() mgv22.geo.wgs84ToEnu([15.1682 76.8504 0],[0 0 0]), ...
    'mgv22:MissingGeographicAnchor');
end

function testInverseEmptyInput(tc)
verifyEqual(tc,mgv22.geo.wgs84ToEnu(zeros(0,3),[15.1682 76.8504 0]),zeros(0,3));
end

function testHundredMetresEastLongitudeChange(tc)
a = [15.1682 76.8504 0];
lla = mgv22.geo.enuToWgs84([100 0 0],a);
dlon = lla(2) - a(2);
% Spherical rule of thumb (111320 m/deg); WGS84 prime-vertical radius differs by ~2e-4 relative.
verifyEqual(tc,dlon,100/(111320*cosd(a(1))),'AbsTol',3e-7);
% Exact WGS84 tangent-plane value.
f = 1/298.257223563; e2 = f*(2-f);
N = 6378137/sqrt(1 - e2*sind(a(1))^2);
verifyEqual(tc,dlon,rad2deg(atan(100/(N*cosd(a(1))))),'AbsTol',1e-10);
end
