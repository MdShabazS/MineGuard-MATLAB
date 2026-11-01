function tests = testV2SatelliteGeo
%TESTV2SATELLITEGEO Pure-math tests for optional preview, base MATLAB.
%   Requires: addpath('v2/matlab')
%   Does NOT contact satellite tile servers or run any scientific study.
tests = functiontests(localfunctions);
end

function testZeroOffsetIsExplicitAnchor(tc)
a = [12.983, 77.594, 915];
lla = mgv2.geo.enuToWgs84([0 0 0],a);
verifyEqual(tc,lla(1:2),a(1:2),'AbsTol',1e-10);
verifyEqual(tc,lla(3),a(3),'AbsTol',1e-5);
end

function testEastNorthAndAltitudeSigns(tc)
a = [12.983, 77.594, 915];
lla = mgv2.geo.enuToWgs84([100 0 0; 0 100 0; 0 0 20],a);
verifyGreaterThan(tc,lla(1,2),a(2));
verifyLessThan(tc,abs(lla(1,1)-a(1)),1e-6);
verifyGreaterThan(tc,lla(2,1),a(1));
verifyLessThan(tc,abs(lla(2,2)-a(2)),1e-6);
verifyEqual(tc,lla(3,3),a(3)+20,'AbsTol',1e-5);
end

function testDeterministicAndVectorized(tc)
a = [-20.5, 110.3, 50];
pts = [0 0 0; 120 -80 2; -50 60 1];
x=mgv2.geo.enuToWgs84(pts,a);
y=mgv2.geo.enuToWgs84(pts,a);
verifySize(tc,x,[3 3]);
verifyEqual(tc,x,y);
verifyTrue(tc,all(isfinite(x),'all'));
end

function testPlaceholderOriginRejected(tc)
verifyError(tc,@() mgv2.geo.enuToWgs84([0 0 0],[0 0 0]), ...
    'mgv2:MissingGeographicAnchor');
end

function testPolarAndDatelineOriginsRejected(tc)
verifyError(tc,@() mgv2.geo.enuToWgs84([0 0 0],[85 10 0]), ...
    'mgv2:UnsupportedGeographicAnchor');
verifyError(tc,@() mgv2.geo.enuToWgs84([0 0 0],[20 179.5 0]), ...
    'mgv2:UnsupportedGeographicAnchor');
end

function testTooLargeExtentRejected(tc)
verifyError(tc,@() mgv2.geo.enuToWgs84([11000 0 0],[10 60 0]), ...
    'mgv2:GeographicExtentTooLarge');
end

function testPreviewRequiresExplicitAnchorBeforeOpeningGraphics(tc)
verifyError(tc,@() mgv2SatelliteMapPreview(Visible="off"), ...
    'mgv2:MissingGeographicAnchor');
end
