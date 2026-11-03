classdef testV21Scenario < matlab.unittest.TestCase
    %TESTV21SCENARIO V21-002: environment presets, survey boundary/grid validation, PublicMissionConfig. SIMULATED.
    %   Headless. From the repository root: runtests('v2_1/tests/testV21Scenario.m')
    %   Written on the Mac without execution; first executed on Windows by Rahil (V21-008).

    properties (TestParameter)
        preset = {"TRAINING_FIELD_A", "ROCKY_UPLAND", "DRY_FLATS"}
    end

    methods (TestClassSetup)
        function setup(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2', 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_1', 'matlab')));
        end
    end

    methods (Static)
        function s = withPoly(s, P, kind)
            s.polygon_enu_m = P; if nargin > 2, s.boundary_kind = kind; end
        end
    end

    methods (Test)
        % ---- presets ---------------------------------------------------------------------------------
        function presetsAreListedWithTrainingFieldFirst(tc)
            ids = mgv21.scenario.presetIds();
            tc.verifyGreaterThanOrEqual(numel(ids), 3);
            tc.verifyEqual(ids(1), "TRAINING_FIELD_A");
            tc.verifyEqual(mgv21.scenario.environmentPreset().preset_id, "TRAINING_FIELD_A");
        end

        function trainingFieldIsTheV2Default(tc)
            p = mgv21.scenario.environmentPreset("TRAINING_FIELD_A");
            tc.verifyEqual(p.scene_config, mgv2.scene.defaultSceneConfig());
            m = mgv2.mission.defaultConfig();
            tc.verifyEqual(p.bounds_enu_m, m.bounds_enu_m);
            tc.verifyEqual(p.default_survey.polygon_enu_m, m.survey_polygon_enu_m);
            tc.verifyEqual(p.default_survey.home_enu_m, m.home_enu_m);
        end

        function presetsDifferInTerrainNotJustNames(tc)
            ids = mgv21.scenario.presetIds(); P = arrayfun(@(i) mgv21.scenario.environmentPreset(i), ids, 'UniformOutput', false); P = [P{:}];
            for i = 1:numel(P)
                for j = i+1:numel(P)
                    a = P(i).scene_config; b = P(j).scene_config;
                    tc.verifyNotEqual(a.seed, b.seed);
                    tc.verifyNotEqual([a.relief_m a.slope a.n_rocks a.n_bushes], [b.relief_m b.slope b.n_rocks b.n_bushes]);
                end
            end
            tc.verifyEqual(numel(unique([P.environment_mode])), numel(P));
            w1 = mgv2.scene.buildWorld(P(1).scene_config); w2 = mgv2.scene.buildWorld(P(2).scene_config);
            tc.verifyGreaterThan(max(abs(w1.Z(:) - w2.Z(:))), 1, 'terrain heights must differ');
            tc.verifyNotEqual(height(w1.objects), height(w2.objects));
        end

        function unknownPresetIsRejected(tc)
            tc.verifyError(@() mgv21.scenario.environmentPreset("MOON"), 'mgv21:UnknownPreset');
            tc.verifyError(@() mgv21.scenario.validateSurvey(mgv21.scenario.defaultSurvey(), "MOON"), 'mgv21:UnknownPreset');
        end

        function everyPresetDefaultBuildsAFlyablePublicMission(tc, preset)
            p = mgv21.scenario.environmentPreset(preset);
            w = mgv2.scene.buildWorld(p.scene_config);
            [pub, plan] = mgv21.scenario.buildPublicMission(preset, p.default_survey, World=w);
            tc.verifyEqual(pub.schema_version, "mg-v21-public/1.0");
            tc.verifyEqual(mgv2.mission.validateConfig(pub.mission), pub.mission);
            tc.verifyEqual(plan, mgv2.mission.planSurvey(pub.mission));
            tc.verifyGreaterThanOrEqual(plan.n_lines, 2);
            tc.verifyEqual(pub.scene_config.survey_polygon_enu_m, pub.mission.survey_polygon_enu_m);
            tc.verifyEqual(pub.scene_config.home_enu_m, pub.mission.home_enu_m);
            mgv21.scenario.assertPublic(pub, "pub");
            w2 = mgv21.scenario.buildWorld(pub);
            tc.verifyEqual(w2.Z, w.Z);
        end

        % ---- boundaries -------------------------------------------------------------------------------
        function rectangleHelperIsCounterClockwise(tc)
            P = mgv21.scenario.rectangleBoundary(-10, 30, -5, 25);
            tc.verifyEqual(P, [-10 -5; 30 -5; 30 25; -10 25]);
            tc.verifyError(@() mgv21.scenario.rectangleBoundary(5, 5, 0, 10), 'mgv21:InvalidSurvey');
            tc.verifyError(@() mgv21.scenario.rectangleBoundary(0, NaN, 0, 10), 'mgv21:InvalidSurvey');
        end

        function convexPolygonIsAccepted(tc)
            s = testV21Scenario.withPoly(mgv21.scenario.defaultSurvey(), [-30 -20; 20 -25; 35 10; 0 30; -35 15], "POLYGON");
            [s2, r] = mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A");
            tc.verifyEqual(s2.polygon_enu_m, s.polygon_enu_m);
            tc.verifyFalse(r.polygon_reordered);
            tc.verifyGreaterThan(r.area_m2, 400);
        end

        function clockwiseIsReorderedAndReported(tc)
            s = mgv21.scenario.defaultSurvey(); P = s.polygon_enu_m;
            [s2, r] = mgv21.scenario.validateSurvey(testV21Scenario.withPoly(s, flipud(P)), "TRAINING_FIELD_A");
            tc.verifyTrue(r.polygon_reordered);
            tc.verifyEqual(s2.polygon_enu_m, P);
        end

        function closingVertexIsDropped(tc)
            s = mgv21.scenario.defaultSurvey(); P = s.polygon_enu_m;
            [s2, r] = mgv21.scenario.validateSurvey(testV21Scenario.withPoly(s, [P; P(1,:)]), "TRAINING_FIELD_A");
            tc.verifyTrue(r.closing_vertex_dropped);
            tc.verifyEqual(s2.polygon_enu_m, P);
        end

        function invalidPolygonsAreRejected(tc)
            s = mgv21.scenario.defaultSurvey();
            bad = { ...
                [-30 -20; 30 -20; NaN 20; -30 20], ...                  non-finite
                [-30 -20; 30 -20], ...                                  too few vertices
                [-30 -20; 30 -20; 30 -20.1; 30 20; -30 20], ...         repeated vertex
                [-30 -20; 30 20; 30 -20; -30 20], ...                   bow-tie (self-intersecting)
                [-30 -20; 30 -20; 30 20; 0 0; -30 20], ...              non-convex (notch)
                [0 0; 10 0; 10 10; 0 10], ...                           area 100 m^2 < 400
                [-30 -20; 30 -20; 0 -20.0000001; 0 20], ...             degenerate / collinear spike
                [-79 -20; 30 -20; 30 20; -79 20], ...                   outside the extent margin
                (1:3)' * [1 1]};                                        %#ok<*NBRAK2> collinear, zero area
            for k = 1:numel(bad)
                tc.verifyError(@() mgv21.scenario.validateSurvey(testV21Scenario.withPoly(s, bad{k}, "POLYGON"), "TRAINING_FIELD_A"), ...
                    'mgv21:InvalidSurvey', sprintf('case %d', k));
            end
        end

        function rectangleKindMustBeAnAxisRectangle(tc)
            s = testV21Scenario.withPoly(mgv21.scenario.defaultSurvey(), [-30 -20; 20 -25; 35 10; 0 30; -35 15], "RECTANGLE");
            tc.verifyError(@() mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A"), 'mgv21:InvalidSurvey');
        end

        function homeMustBeInsideExtentAndGeofence(tc)
            s = mgv21.scenario.defaultSurvey();
            for h = {[-79 -50], [0 90], [NaN 0], [1 2 3]}
                s.home_enu_m = h{1};
                tc.verifyError(@() mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A"), 'mgv21:InvalidSurvey');
            end
        end

        function wrongFieldsAreRejected(tc)
            s = mgv21.scenario.defaultSurvey(); s.targets = [1 2];
            tc.verifyError(@() mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A"), 'mgv21:InvalidSurvey');
        end

        % ---- grid and route ----------------------------------------------------------------------------
        function gridSettingsChangeThePlan(tc)
            s = mgv21.scenario.defaultSurvey();
            [~, r10] = mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A");
            s.line_spacing_m = 5; [~, r5] = mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A");
            tc.verifyGreaterThan(r5.n_lines, r10.n_lines);
            s.line_spacing_m = 10; s.heading_deg = 0; [~, r0] = mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A");
            tc.verifyNotEqual(r0.plan.waypoints_xy, r10.plan.waypoints_xy);
            s.heading_deg = -270; s2 = mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A");
            tc.verifyEqual(s2.heading_deg, 90);
            s.heading_deg = 90; s.alt_agl_m = 25; s.speed_mps = 4;
            [pub, ~] = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", s);
            tc.verifyEqual([pub.mission.alt_agl_setpoint_m pub.mission.speed_mps], [25 4]);
        end

        function outOfRangeSettingsAreRejected(tc)
            s0 = mgv21.scenario.defaultSurvey();
            bad = {'line_spacing_m', 1; 'line_spacing_m', 31; 'line_spacing_m', NaN; 'alt_agl_m', 5; 'alt_agl_m', 61; ...
                'speed_mps', 0; 'speed_mps', 9; 'speed_mps', -1; 'heading_deg', Inf};
            for k = 1:size(bad, 1)
                s = s0; s.(bad{k,1}) = bad{k,2};
                tc.verifyError(@() mgv21.scenario.validateSurvey(s, "TRAINING_FIELD_A"), 'mgv21:InvalidSurvey', sprintf('%s=%g', bad{k,1}, bad{k,2}));
            end
        end

        function routeTooLongForTimeoutIsRejected(tc)
            s = mgv21.scenario.defaultSurvey("DRY_FLATS"); s.line_spacing_m = 2; s.speed_mps = 2;
            tc.verifyError(@() mgv21.scenario.validateSurvey(s, "DRY_FLATS"), 'mgv21:InvalidSurvey');
            [~, r] = mgv21.scenario.validateSurvey(mgv21.scenario.defaultSurvey("DRY_FLATS"), "DRY_FLATS");
            tc.verifyLessThanOrEqual(r.est_flight_s, r.flight_budget_s);
        end

        function terrainClearanceIsCheckedAgainstTheCeiling(tc)
            p = mgv21.scenario.environmentPreset("ROCKY_UPLAND"); w = mgv2.scene.buildWorld(p.scene_config);
            [~, r] = mgv21.scenario.validateSurvey(p.default_survey, "ROCKY_UPLAND", w);
            tc.verifyTrue(r.terrain_checked);
            tc.verifyTrue(all(isfinite(r.terrain_z_range_m)));
            tc.verifyLessThan(r.terrain_z_range_m(2) + p.default_survey.alt_agl_m + 5, p.bounds_enu_m(3,2));
            wLow = w; wLow.Z = w.Z + p.bounds_enu_m(3,2);           % ground lifted to the ceiling
            tc.verifyError(@() mgv21.scenario.validateSurvey(p.default_survey, "ROCKY_UPLAND", wLow), 'mgv21:InvalidSurvey');
            wOther = mgv2.scene.buildWorld(mgv21.scenario.environmentPreset("DRY_FLATS").scene_config);
            tc.verifyError(@() mgv21.scenario.validateSurvey(p.default_survey, "ROCKY_UPLAND", wOther), 'mgv21:InvalidSurvey');
        end

        % ---- firewall -----------------------------------------------------------------------------------
        function publicFirewallRejectsPrivateNames(tc)
            pub = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", mgv21.scenario.defaultSurvey());
            for name = ["surface_features", "placement", "target_id", "truth", "manual"]
                x = pub; x.(name) = 1;
                tc.verifyError(@() mgv21.scenario.assertPublic(x), 'mgv2:TruthLeak', name);
            end
        end
    end
end
