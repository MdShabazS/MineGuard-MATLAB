function tests = testV2SatelliteGeo
%TESTV2SATELLITEGEO Pure-math tests for optional preview, base MATLAB.
%   Sets its own path, like the other V2 suites.
%   Does NOT contact satellite tile servers or run any scientific study.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
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

function testNearNullGeographicAnchorRejected(tc)
anchors = [0 0 1e-9; 1e-9 0 0; 0 0 5; 0.005 -0.005 100];
for i = 1:size(anchors,1)
    a = anchors(i,:);
    verifyError(tc,@() mgv2.geo.enuToWgs84([0 0 0],a), ...
        'mgv2:MissingGeographicAnchor');
end
end

function testExtremeVerticalOffsetRejected(tc)
verifyError(tc,@() mgv2.geo.enuToWgs84([0 0 5e6],[12.983 77.594 915]), ...
    'mgv2:GeographicExtentTooLarge');
end

function testPreviewRejectsNearNullAnchorBeforeGraphics(tc)
verifyError(tc,@() mgv2SatelliteMapPreview(AnchorLLA=[0 0 5],Visible="off"), ...
    'mgv2:MissingGeographicAnchor');
end

function testAnchorJustBeyondPlaceholderAccepted(tc)
lla = mgv2.geo.enuToWgs84([0 0 0],[0.02 0 5]);
verifyEqual(tc,lla(1:2),[0.02 0],'AbsTol',1e-10);
end

function testVerticalOffsetLimitIsInclusive(tc)
lla = mgv2.geo.enuToWgs84([0 0 10000],[12.983 77.594 915]);
verifyEqual(tc,lla(3),10915,'AbsTol',1e-5);
verifyError(tc,@() mgv2.geo.enuToWgs84([0 0 -10001],[12.983 77.594 915]), ...
    'mgv2:GeographicExtentTooLarge');
end

function testDarkwaterCreditsNaturalEarthNotEsri(tc)
o = mgv2SatelliteMapPreview(AnchorLLA=[29.97917 31.13417 80],Basemap="darkwater",Visible="off");
c = onCleanup(@() delete(o.figure));
verifySubstring(tc,string(o.attribution_label.Text),"Natural Earth");
verifyFalse(tc,contains(string(o.attribution_label.Text),"Esri"));
verifyEqual(tc,string(o.figure.Theme.BaseColorStyle),"dark");
verifySubstring(tc,string(o.warning_label.Text),"SIMULATION ONLY");
end

function testSatelliteCreditIsNamedWhetherOnlineOrNot(tc)
o = mgv2SatelliteMapPreview(AnchorLLA=[29.97917 31.13417 80],Visible="off");
c = onCleanup(@() delete(o.figure));
txt = string(o.attribution_label.Text);
verifyTrue(tc,startsWith(txt,"Basemap: satellite | Powered by Esri | Source"));
verifySubstring(tc,lower(txt),"gis user community");
verifyTrue(tc,ismember(o.credit_source,["LIVE_SERVICE","PINNED_2026_11_02"]));
verifySubstring(tc,string(o.attribution_link.URL),"World_Imagery");
verifyNotEmpty(tc,char(o.status_label.Text));
verifyEqual(tc,o.tile_status,"UNVERIFIED");
verifySubstring(tc,string(o.status_label.Text),"tile loading unverified");
end

function testOtherEsriBasemapsNameNoGuessedSourceList(tc)
for bm = ["topographic","streets-light"]
    o = mgv2SatelliteMapPreview(AnchorLLA=[29.97917 31.13417 80],Basemap=bm,Visible="off");
    c = onCleanup(@() delete(o.figure));
    txt = string(o.attribution_label.Text);
    verifySubstring(tc,txt,"Powered by Esri");
    verifyFalse(tc,contains(txt,"HERE") || contains(txt,"Vantor"),bm);
    verifyEqual(tc,o.credit_source,"MAP_NATIVE");
    clear c
end
end

function testBasemapSourceDoesNotQueryUnrelatedMetadata(tc)
requests = strings(0,1);
for bm = ["topographic","streets-light"]
    src = mgv2.geo.basemapSource(bm,@readMetadata);
    verifyEqual(tc,numel(requests),0,"No metadata request for " + bm);
    verifyEqual(tc,src.metadata_status,"NOT_QUERIED");
    verifyEqual(tc,src.tile_status,"UNVERIFIED");
    verifySubstring(tc,src.status,"Basemap " + bm + " selected");
    verifySubstring(tc,src.credit,"Basemap: " + bm);
    verifySubstring(tc,src.credit,"Powered by Esri");
    verifyFalse(tc,contains(src.credit,"Vantor"));
end
src = mgv2.geo.basemapSource("darkwater",@readMetadata);
verifyEqual(tc,numel(requests),0,"No metadata request for darkwater");
verifyEqual(tc,src.metadata_status,"NOT_APPLICABLE");
verifyEqual(tc,src.tile_status,"LOCAL_BASEMAP");
verifySubstring(tc,src.credit,"Natural Earth");
    function info = readMetadata(url)
        requests(end+1,1) = string(url);
        info = struct('copyrightText',"Source: Test Contributor");
    end
end

function testSatelliteRequestsOnlyWorldImageryMetadata(tc)
requests = strings(0,1);
src = mgv2.geo.basemapSource("satellite",@readMetadata);
verifyEqual(tc,requests,"https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer?f=json");
verifyEqual(tc,src.metadata_status,"AVAILABLE");
verifyEqual(tc,src.credit_source,"LIVE_SERVICE");
verifySubstring(tc,src.credit,"Test Contributor");
verifyEqual(tc,src.tile_status,"UNVERIFIED");
verifySubstring(tc,src.status,"tile loading unverified");
    function info = readMetadata(url)
        requests(end+1,1) = string(url);
        info = struct('copyrightText',"Source: Esri, Test Contributor");
    end
end

function testSatelliteMetadataFailureKeepsPinnedCredits(tc)
reader = @(~) error('mgv2:MetadataUnavailable','Simulated offline request.');
src = mgv2.geo.basemapSource("satellite",reader);
verifyEqual(tc,src.metadata_status,"UNAVAILABLE");
verifyEqual(tc,src.credit_source,"PINNED_2026_11_02");
verifySubstring(tc,src.credit,"GIS User Community");
verifyEqual(tc,src.tile_status,"UNVERIFIED");
verifyFalse(tc,contains(src.status,"tiles loaded"));
end

function testSatelliteEmptyMetadataAlsoFailsClosed(tc)
reader = @(~) struct('copyrightText',"");
src = mgv2.geo.basemapSource("satellite",reader);
verifyEqual(tc,src.metadata_status,"UNAVAILABLE");
verifyEqual(tc,src.credit_source,"PINNED_2026_11_02");
end

function testSatelliteMalformedMetadataKeepsPinnedCredits(tc)
for response = {struct(),struct('copyrightText',42)}
    src = mgv2.geo.basemapSource("satellite",@(~) response{1});
    verifyEqual(tc,src.metadata_status,"UNAVAILABLE");
    verifyEqual(tc,src.credit_source,"PINNED_2026_11_02");
end
end
