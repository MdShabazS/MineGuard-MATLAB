function tests = testV22MissionOverlay
%TESTV22MISSIONOVERLAY V22-T5: virtual mission route / drone overlay on the BITM satellite preview.
%   Hidden figures and an injected metadata reader only: no network, no map-tile dependency.
%   Everything drawn is a VIRTUAL simulated flight; nothing here represents detection capability.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
for d = ["v2", "v2_1", "v2_2"]
    tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, d, 'matlab')));
end
end

function setup(tc)
p = mgv22.sat.SatellitePreview(MetadataReader=@(~) struct('copyrightText', "Source: Test"));
p.open(Visible="off");
tc.TestData.preview = p;
tc.TestData.pub = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", mgv21.scenario.defaultSurvey("TRAINING_FIELD_A"));
tc.TestData.overlays = {};
end

function teardown(tc)
for k = 1:numel(tc.TestData.overlays)
    if isvalid(tc.TestData.overlays{k}), delete(tc.TestData.overlays{k}); end
end
if isvalid(tc.TestData.preview), delete(tc.TestData.preview); end
end

function ov = makeOverlay(tc)
ov = mgv22.sat.MissionOverlay(tc.TestData.preview, tc.TestData.pub);
tc.TestData.overlays{end+1} = ov;
end

function eng = makeEngine(tc)
eng = mgv2.engine.MissionEngine(tc.TestData.pub.mission, mgv2.engine.flatTerrain());
eng.start();
end

function ll = expectedLatLon(tc, enu)
lla = mgv22.geo.enuToWgs84([enu(1) enu(2) 0], tc.TestData.preview.Site.anchor_lla);
ll = lla(1:2);
end

% ---- 1. layers and geometry round trip -------------------------------------------------------------------
function testLayersDrawnAndVerticesRoundTrip(tc)
ov = makeOverlay(tc); p = tc.TestData.preview; m = tc.TestData.pub.mission;
lines = {ov.Boundary, ov.Route, ov.Home, ov.Drone, ov.Trail};
for k = 1:numel(lines)
    verifyTrue(tc, isvalid(lines{k}));
    verifyEqual(tc, lines{k}.Parent, p.Axes);
end
anchor = p.Site.anchor_lla;
B = ov.BoundaryLLA;
verifyEqual(tc, size(B, 2), 3);
verifyEqual(tc, B(1, :), B(end, :), 'boundary polygon must be closed');
P = m.survey_polygon_enu_m;
enuB = mgv22.geo.wgs84ToEnu(B, anchor);
verifyEqual(tc, enuB(:, 1:2), [P; P(1, :)], 'AbsTol', 0.01);
route = mgv2.mission.buildRoute(m, mgv2.mission.planSurvey(m));
enuR = mgv22.geo.wgs84ToEnu(ov.RouteLLA, anchor);
verifyEqual(tc, enuR(:, 1:2), route.xy, 'AbsTol', 0.01);
verifySize(tc, ov.HomeLLA, [1 3]);
enuH = mgv22.geo.wgs84ToEnu(ov.HomeLLA, anchor);
verifyEqual(tc, enuH(1:2), m.home_enu_m, 'AbsTol', 0.01);
verifyTrue(tc, isnan(ov.LastTick));
end

% ---- 2. labels -------------------------------------------------------------------------------------------
function testVirtualLabelsNoForbiddenWordsAndLegend(tc)
ov = makeOverlay(tc); p = tc.TestData.preview;
lines = {ov.Boundary, ov.Route, ov.Home, ov.Drone, ov.Trail};
forbidden = lower(string(p.Site.forbidden_on_imagery));
for k = 1:numel(lines)
    name = string(lines{k}.DisplayName);
    verifySubstring(tc, name, "VIRTUAL");
    for w = forbidden
        verifyFalse(tc, contains(lower(name), w), sprintf('"%s" contains forbidden word "%s"', name, w));
    end
end
verifyNotEmpty(tc, p.Axes.Legend);
verifySubstring(tc, string(p.Banner.Text), "SIMULATED FLIGHT");
end

% ---- 3. firewall and preview state -----------------------------------------------------------------------
function testTruthLeakAndClosedPreviewRejected(tc)
p = tc.TestData.preview; pub = tc.TestData.pub;
bad = pub; bad.truth = 1;
verifyError(tc, @() mgv22.sat.MissionOverlay(p, bad), 'mgv2:TruthLeak');
bad = pub; bad.targets = 1;
verifyError(tc, @() mgv22.sat.MissionOverlay(p, bad), 'mgv2:TruthLeak');
closed = mgv22.sat.SatellitePreview(MetadataReader=@(~) struct('copyrightText', "Source: Test"));
tc.addTeardown(@() delete(closed));
verifyError(tc, @() mgv22.sat.MissionOverlay(closed, pub), 'mgv22:PreviewNotOpen');
p.close();
verifyError(tc, @() mgv22.sat.MissionOverlay(p, pub), 'mgv22:PreviewNotOpen');
end

% ---- 4. update follows the engine ------------------------------------------------------------------------
function testUpdateMatchesEngineSnapshot(tc)
ov = makeOverlay(tc); eng = makeEngine(tc);
checks = [1 5 12 20 33 40]; n = 0;
for t = 1:40
    eng.step();
    if ismember(t, checks)
        s = eng.snapshot(); ov.update(s); n = n + 1;
        verifyEqual(tc, [ov.Drone.LatitudeData(end) ov.Drone.LongitudeData(end)], ...
            expectedLatLon(tc, s.position_enu_m), 'AbsTol', 1e-9);
        verifyEqual(tc, ov.LastTick, s.tick_id);
        verifyEqual(tc, ov.LastTick, eng.TickId);
        verifyEqual(tc, size(ov.TrailLLA), [n 2]);
        verifyEqual(tc, ov.TrailLLA(end, :), expectedLatLon(tc, s.position_enu_m), 'AbsTol', 1e-9);
    end
end
verifyError(tc, @() ov.update(struct('x', 1)), 'mgv22:InvalidPose');
end

% ---- 5. scrubbing from the pose log ----------------------------------------------------------------------
function testSyncFromPoseLog(tc)
ov = makeOverlay(tc); eng = makeEngine(tc);
for t = 1:200, eng.step(); end
T = eng.poseLog();
for tick = [0 50 100 150 200]
    ov.syncFromPoseLog(T, tick);
    rows = find(T.tick_id <= tick);
    r = rows(end);
    verifyEqual(tc, [ov.Drone.LatitudeData(end) ov.Drone.LongitudeData(end)], ...
        expectedLatLon(tc, T.position_enu_m(r, :)), 'AbsTol', 1e-9);
    verifyEqual(tc, size(ov.TrailLLA, 1), numel(rows));
    verifyEqual(tc, size(ov.TrailLLA, 1), tick + 1);
end
verifyError(tc, @() ov.syncFromPoseLog(T, min(T.tick_id) - 1), 'mgv22:InvalidPose');
end

% ---- 6. live binding -------------------------------------------------------------------------------------
function testBindEngineAndSafeAfterDelete(tc)
ov = makeOverlay(tc); eng = makeEngine(tc);
ov.bindEngine(eng);
for t = 1:30, eng.step(); end
verifyEqual(tc, ov.LastTick, eng.TickId);
s = eng.snapshot();
verifyEqual(tc, [ov.Drone.LatitudeData(end) ov.Drone.LongitudeData(end)], ...
    expectedLatLon(tc, s.position_enu_m), 'AbsTol', 1e-9);
delete(ov);
verifyWarningFree(tc, @() stepN(eng, 5));
verifyEqual(tc, eng.TickId, 35);
end

function stepN(eng, n)
for k = 1:n, eng.step(); end
end

% ---- 7. update cost --------------------------------------------------------------------------------------
function testUpdateIsFast(tc)
ov = makeOverlay(tc); eng = makeEngine(tc);
snaps = cell(1, 200);
for k = 1:200, eng.step(); snaps{k} = eng.snapshot(); end
dt = zeros(1, 200);
for k = 1:200
    t0 = tic; ov.update(snaps{k}); dt(k) = toc(t0);
end
m = mean(dt);
fprintf("UPDATE_MEAN_MS %.3f\n", 1000 * m);
verifyLessThan(tc, m, 0.005);
end

% ---- 8. delete -------------------------------------------------------------------------------------------
function testDeleteRemovesGraphicsKeepsPreview(tc)
ov = makeOverlay(tc); p = tc.TestData.preview;
lines = {ov.Boundary, ov.Route, ov.Home, ov.Drone, ov.Trail};
delete(ov);
for k = 1:numel(lines), verifyFalse(tc, isvalid(lines{k})); end
verifyTrue(tc, p.isOpen());
end
