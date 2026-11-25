function tests = testV22FieldPlan
%TESTV22FIELDPLAN Tests for mgv22.field.surveyPlan (V22-T11): drawn field -> V2.1 survey. SIMULATION only.
%   Test fields are ENU offsets around a point inside the BITM view, converted to [lat lon] with enuToWgs84.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2', 'matlab')));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_1', 'matlab')));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_2', 'matlab')));
site = mgv22.siteConfig();
c = mgv22.geo.enuToWgs84([-60 -100 0], site.anchor_lla);    % a point inside the BITM view window
tc.TestData.site = site;
tc.TestData.center = [c(1:2) 0];
end

function ll = toLL(tc, enuXY)
lla = mgv22.geo.enuToWgs84([enuXY, zeros(size(enuXY, 1), 1)], tc.TestData.center);
ll = lla(:, 1:2);
end

function r = rect(w, h)
r = [-w/2 -h/2; w/2 -h/2; w/2 h/2; -w/2 h/2];
end

function testRectanglePlan(tc)
P = mgv22.field.surveyPlan(toLL(tc, rect(60, 40)));
verifyEqual(tc, P.area_m2, 2400, 'RelTol', 1e-6);
verifyFalse(tc, P.hull_used);
back = mgv22.geo.wgs84ToEnu([P.poly_ll, zeros(size(P.poly_ll, 1), 1)], P.field_anchor_lla);
verifyLessThan(tc, max(vecnorm(back(:, 1:2) - P.poly_enu, 2, 2)), 0.01);
verifyGreaterThanOrEqual(tc, P.alt_m, 6); verifyLessThanOrEqual(tc, P.alt_m, 60);
verifyGreaterThanOrEqual(tc, P.spacing_m, 2); verifyLessThanOrEqual(tc, P.spacing_m, 30);
mgv2.mission.validateConfig(P.pub.mission);
lo = min(P.poly_enu) - 1; hi = max(P.poly_enu) + 1;
sv = P.route_enu(2:end-1, :);                               % survey waypoints (home -> ... -> home)
verifyTrue(tc, all(sv(:,1) >= lo(1) & sv(:,1) <= hi(1) & sv(:,2) >= lo(2) & sv(:,2) <= hi(2)));
verifyFalse(tc, inpolygon(P.home_enu_m(1), P.home_enu_m(2), P.poly_enu(:,1), P.poly_enu(:,2)));
verifyGreaterThan(tc, P.n_lines, 0);
verifyGreaterThan(tc, P.est_flight_s, 60);
verifyEqual(tc, P.est_ticks, ceil(P.est_flight_s / P.pub.mission.dt_s));
verifySize(tc, P.route_ll, size(P.route_enu));
verifySubstring(tc, char(P.label), 'SIMULATION');
end

function testAltitudePixelRule(tc)
ll = toLL(tc, rect(60, 40));
P = mgv22.field.surveyPlan(ll, MinPixelsOnTarget=5, TargetDiameterM=0.15);
verifyTrue(tc, (P.pixels_on_target >= 5 && P.pixels_rule_met) || (P.alt_m == 6 && ~P.pixels_rule_met));
verifyEqual(tc, P.pixels_on_target, 0.15 / (P.gsd_rgb_cm / 100), 'RelTol', 1e-12);
cam = mgv2.sensors.defaultSensorConfig().RGB_NADIR.mount;
verifyEqual(tc, P.gsd_rgb_cm, 100 * 2 * P.alt_m * tand(cam.hfov_deg / 2) / cam.width_px, 'RelTol', 1e-12);
verifyGreaterThan(tc, P.gsd_thermal_cm, 0);
mins = [3 4 5 6 8];
alt = zeros(size(mins)); pix = alt;
for k = 1:numel(mins)
    Q = mgv22.field.surveyPlan(ll, MinPixelsOnTarget=mins(k));
    alt(k) = Q.alt_m; pix(k) = Q.pixels_on_target;
    verifyTrue(tc, Q.pixels_rule_met == (Q.pixels_on_target >= mins(k) - 1e-9));
end
verifyTrue(tc, all(diff(alt) <= 1e-12), 'More pixels required must never raise the altitude.');
verifyTrue(tc, all(diff(pix) >= -1e-12), 'More pixels required must never lower the pixel count.');
end

function testNonConvexAndHull(tc)
L = [0 0; 60 0; 60 30; 30 30; 30 60; 0 60] - 30;
ll = toLL(tc, L);
verifyError(tc, @() mgv22.field.surveyPlan(ll), 'mgv22:NonConvexField');
P = mgv22.field.surveyPlan(ll, AllowHull=true);
verifyTrue(tc, P.hull_used);
verifyEqual(tc, P.area_m2, 60*60 - 30*30/2, 'RelTol', 1e-6);
end

function testSizeAndOutlineErrors(tc)
verifyError(tc, @() mgv22.field.surveyPlan(toLL(tc, rect(150, 60))), 'mgv22:FieldTooLarge');
verifyError(tc, @() mgv22.field.surveyPlan(toLL(tc, rect(15, 15))), 'mgv22:FieldTooSmall');
bow = [0 0; 40 0; 0 40; 40 40] - 20;
verifyError(tc, @() mgv22.field.surveyPlan(toLL(tc, bow)), 'mgv22:InvalidOutline');
end

function testHeadingFollowsLongestEdge(tc)
P = mgv22.field.surveyPlan(toLL(tc, rect(60, 20)));
verifyTrue(tc, abs(P.heading_deg - 90) < 0.5 || abs(P.heading_deg - 270) < 0.5);
end

function testPublicOnly(tc)
P = mgv22.field.surveyPlan(toLL(tc, rect(60, 40)));
mgv21.scenario.assertPublic(P.pub);
f = lower(string(fieldnames(P)));
bad = [mgv21.contract().private_names, "truth", "target_truth", "targettruth", "ground_truth", "true_targets"];
verifyEmpty(tc, intersect(f, bad));
verifyFalse(tc, any(contains(f, "truth")));
end
