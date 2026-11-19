function tests = testV22SatellitePreview
%TESTV22SATELLITEPREVIEW V22-T4: site file, credits/status (ported #100 cases) and the BITM satellite preview window.
%   Uses injected metadata readers, so no test depends on the network or on map tiles. Opens hidden figures only.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'matlab')));
tc.TestData.root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function info = liveReader(~)
info = struct('copyrightText', "Source: Esri, Test Contributor");
end

function info = offlineReader(~) %#ok<STOUT> always throws: simulates no network
error('mgv22:MetadataUnavailable', 'Simulated offline request.');
end

% ---- site file -------------------------------------------------------------------------------------------
function testSiteFileIsTheConfirmedBitmAnchor(tc)
s = mgv22.siteConfig();
verifyEqual(tc, s.anchor_lla, [15.1682 76.8504 0]);
verifyEqual(tc, s.view_window.lat, [15.1653 15.1693]);
verifyEqual(tc, s.view_window.lon, [76.8489 76.8516]);
verifySubstring(tc, s.banner, "SIMULATED FLIGHT");
verifySubstring(tc, s.credit_text, "Vantor");
verifyEqual(tc, s.offline_fallback, "mgenh009.renderOfflineCampusContext");
end

function testSiteFileThatAllowsImageryOrLacksAnchorIsRejected(tc)
base = jsondecode(fileread(fullfile(tc.TestData.root, 'v2_2', 'config', 'bitm_site.json')));
bad = base; bad.commit_imagery_allowed = true;
verifyError(tc, @() mgv22.siteConfig(writeJson(tc, bad)), 'mgv22:InvalidSiteConfig');
bad = rmfield(base, 'anchor_lla');
verifyError(tc, @() mgv22.siteConfig(writeJson(tc, bad)), 'mgv22:InvalidSiteConfig');
bad = base; bad.anchor_lla = [16 77 0];          % outside the view window
verifyError(tc, @() mgv22.siteConfig(writeJson(tc, bad)), 'mgv22:InvalidSiteConfig');
end

function f = writeJson(tc, s)
f = [tempname '.json']; fid = fopen(f, 'w'); fwrite(fid, jsonencode(s)); fclose(fid);
tc.addTeardown(@() delete(f));
end

% ---- credits and status (ported from c3c12af / #100) -----------------------------------------------------
function testSatelliteRequestsOnlyWorldImageryMetadata(tc)
s = mgv22.siteConfig(); requests = strings(0, 1);
src = mgv22.sat.basemapSource("satellite", s, @reader);
verifyEqual(tc, requests, s.service_url + "?f=json");
verifyEqual(tc, src.metadata_status, "AVAILABLE");
verifyEqual(tc, src.credit_source, "LIVE_SERVICE");
verifyTrue(tc, startsWith(src.credit, "Basemap: satellite | Powered by Esri | Source: Esri, Test Contributor"));
verifyEqual(tc, src.tile_status, "UNVERIFIED");
verifySubstring(tc, src.status, "tile loading unverified");
    function info = reader(url)
        requests(end+1, 1) = string(url);
        info = struct('copyrightText', "Source: Esri, Test Contributor");
    end
end

function testOfflineShowsUnavailableWithPinnedSiteCredits(tc)
s = mgv22.siteConfig();
src = mgv22.sat.basemapSource("satellite", s, @offlineReader);
verifyEqual(tc, src.metadata_status, "UNAVAILABLE");
verifyEqual(tc, src.credit_source, "PINNED_SITE_FILE");
verifyEqual(tc, src.credit, s.credit_text);
verifySubstring(tc, src.status, "Satellite unavailable");
verifyFalse(tc, contains(src.status, "tiles loaded"));
end

function testEmptyOrMalformedMetadataFailsClosed(tc)
s = mgv22.siteConfig();
for response = {struct('copyrightText', ""), struct(), struct('copyrightText', 42), "not a struct"}
    src = mgv22.sat.basemapSource("satellite", s, @(~) response{1});
    verifyEqual(tc, src.metadata_status, "UNAVAILABLE");
    verifyEqual(tc, src.credit_source, "PINNED_SITE_FILE");
end
end

function testOtherBasemapsDoNotQueryMetadataOrGuessSources(tc)
s = mgv22.siteConfig(); requests = 0;
for bm = ["topographic", "streets-light"]
    src = mgv22.sat.basemapSource(bm, s, @reader);
    verifyEqual(tc, src.metadata_status, "NOT_QUERIED");
    verifySubstring(tc, src.credit, "Powered by Esri");
    verifyFalse(tc, contains(src.credit, "Vantor"));
end
src = mgv22.sat.basemapSource("darkwater", s, @reader);
verifyEqual(tc, src.tile_status, "LOCAL_BASEMAP");
verifySubstring(tc, src.credit, "Natural Earth");
verifyFalse(tc, contains(src.credit, "Esri"));
verifyEqual(tc, requests, 0);
verifyError(tc, @() mgv22.sat.basemapSource("google", s), 'mgv22:InvalidBasemap');
    function info = reader(~)
        requests = requests + 1; info = struct('copyrightText', "x");
    end
end

% ---- preview window ---------------------------------------------------------------------------------------
function testPreviewOpensAtBitmWithBannerAndCreditsOutsideTheMap(tc)
p = mgv22.sat.SatellitePreview(MetadataReader=@liveReader);
tc.addTeardown(@() delete(p));
p.open(Visible="off");
verifyTrue(tc, p.isOpen());
verifySubstring(tc, string(p.Banner.Text), "REAL IMAGERY — SIMULATED FLIGHT / NOT A HAZARD MAP");
verifyTrue(tc, startsWith(string(p.Credits.Text), "Basemap: satellite | Powered by Esri | Source"));
verifyNotEqual(tc, p.Credits.Parent, p.Axes, 'credits must be outside the map axes');
verifyFalse(tc, isa(p.Credits.Parent, 'matlab.graphics.axis.GeographicAxes'));
[la, lo] = geolimits(p.Axes); s = p.Site;
verifyLessThanOrEqual(tc, la(1), s.view_window.lat(1) + 1e-9); verifyGreaterThanOrEqual(tc, la(2), s.view_window.lat(2) - 1e-9);
verifyLessThanOrEqual(tc, lo(1), s.view_window.lon(1) + 1e-9); verifyGreaterThanOrEqual(tc, lo(2), s.view_window.lon(2) - 1e-9);
st = p.status();
verifyEqual(tc, [st.state st.basemap st.metadata_status st.tile_status], ["OPEN" "satellite" "AVAILABLE" "UNVERIFIED"]);
verifyEqual(tc, string(p.Link.URL), s.service_url);
end

function testLiveCreditKeepsTheSitePrefixAndFullSourceList(tc)
s = mgv22.siteConfig();
src = mgv22.sat.basemapSource("satellite", s, @(~) struct('copyrightText', "Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community"));
verifyEqual(tc, src.credit, s.credit_text, 'live credit with today''s source list equals the site file text');
verifySubstring(tc, lower(src.credit), "gis user community");
s2 = s; s2.credit_text = "Imagery credit | Source: Old";
src = mgv22.sat.basemapSource("satellite", s2, @liveReader);
verifyEqual(tc, src.credit, "Imagery credit | Source: Esri, Test Contributor", 'the prefix comes from the site file');
end

function testPreviewRejectsInvalidSiteBeforeGraphics(tc)
figs0 = numel(findall(groot, 'Type', 'figure'));
s = mgv22.siteConfig();
bad = s; bad.anchor_lla = [0 0 0];
verifyError(tc, @() mgv22.sat.SatellitePreview(Site=bad), 'mgv22:MissingGeographicAnchor');
bad = s; bad.anchor_lla = [16 77 0];
verifyError(tc, @() mgv22.sat.SatellitePreview(Site=bad), 'mgv22:InvalidSiteConfig');
verifyError(tc, @() mgv22.sat.SatellitePreview(Site=struct('x', 1)), 'mgv22:InvalidSiteConfig');
verifyEqual(tc, numel(findall(groot, 'Type', 'figure')), figs0);
end

function testRoundTripCoversTheWholeViewWindow(tc)
s = mgv22.siteConfig(); w = s.view_window;
[la, lo] = meshgrid(linspace(w.lat(1), w.lat(2), 9), linspace(w.lon(1), w.lon(2), 9));
lla = [la(:) lo(:) zeros(numel(la), 1)];
enu = mgv22.geo.wgs84ToEnu(lla, s.anchor_lla);
back = mgv22.geo.enuToWgs84(enu, s.anchor_lla);
verifyLessThan(tc, max(abs(mgv22.geo.wgs84ToEnu(back, s.anchor_lla) - enu), [], 'all'), 0.01, 'round trip within 1 cm over the whole BITM window');
verifyGreaterThan(tc, max(hypot(enu(:,1), enu(:,2))), 300, 'the grid reaches the window edges');
end

function testOfflinePreviewStillOpensAndSaysUnavailable(tc)
p = mgv22.sat.SatellitePreview(MetadataReader=@offlineReader);
tc.addTeardown(@() delete(p));
p.open(Visible="off");
verifyTrue(tc, p.isOpen());
verifySubstring(tc, string(p.StatusLabel.Text), "Satellite unavailable");
verifySubstring(tc, string(p.Banner.Text), "SATELLITE UNAVAILABLE");
verifyFalse(tc, contains(string(p.Banner.Text), "REAL IMAGERY"), 'a possibly blank map must not be labelled real imagery');
verifyEqual(tc, p.status().metadata_status, "UNAVAILABLE");
verifyEqual(tc, string(p.Credits.Text), p.Site.credit_text);
end

function testDarkAndLightThemes(tc)
for th = ["dark", "light"]
    p = mgv22.sat.SatellitePreview(Theme=th, MetadataReader=@liveReader);
    p.open(Visible="off");
    verifyEqual(tc, string(p.Figure.Theme.BaseColorStyle), th);
    verifyEqual(tc, p.status().theme, th);
    delete(p);
end
end

function testThirtyOpenCloseCyclesLeaveNothingBehind(tc)
figs0 = numel(findall(groot, 'Type', 'figure')); timers0 = numel(timerfindall);
p = mgv22.sat.SatellitePreview(MetadataReader=@liveReader);
for k = 1:30
    p.open(Visible="off"); p.open(Visible="off");     % a second open reuses the window
    verifyEqual(tc, numel(findall(groot, 'Type', 'figure')), figs0 + 1);
    p.close();
end
verifyFalse(tc, p.isOpen());
verifyEqual(tc, p.status().state, "CLOSED");
delete(p);
verifyEqual(tc, numel(findall(groot, 'Type', 'figure')), figs0);
verifyEqual(tc, numel(timerfindall), timers0);
end

function testClosingTheWindowUpdatesTheState(tc)
p = mgv22.sat.SatellitePreview(MetadataReader=@liveReader);
tc.addTeardown(@() delete(p));
p.open(Visible="off");
close(p.Figure);                                    % the window's own close request
verifyFalse(tc, p.isOpen());
end

function testNoImageryFilesInV22(tc)
for ext = ["png", "jpg", "jpeg", "tif", "tiff", "mbtiles"]
    verifyEmpty(tc, dir(fullfile(tc.TestData.root, 'v2_2', '**', "*." + ext)), "no ." + ext + " files may be committed under v2_2 (V22-T3)");
end
end
