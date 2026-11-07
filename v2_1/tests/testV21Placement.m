classdef testV21Placement < matlab.unittest.TestCase
    %TESTV21PLACEMENT V21-003: NONE/MANUAL/RANDOM private targets, constraints, firewall, no-signature counterfactual.
    %   Headless. From the repository root: runtests('v2_1/tests/testV21Placement.m')
    %   Most tests use a small deterministic world (one rock at the origin, one landmark) so that positions are known;
    %   one test uses the real V2 training-field world. Written on the Mac without execution (V21-008: Windows).

    properties
        Pub; W
    end

    methods (TestClassSetup)
        function setup(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2', 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_1', 'matlab')));
            tc.Pub = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", mgv21.scenario.defaultSurvey());   % boundary +-40 x +-30 m
            O = table("ROCK-001", "rock", 0, 0, 0.5, 'VariableNames', {'object_id', 'kind', 'x_east_m', 'y_north_m', 'radius_m'});
            tc.W = struct('objects', O, 'landmarks', struct('id', "LM-1", 'xy', [20 10], 'radius_m', 0.6));
        end
    end

    methods
        function spec = manualSpec(tc, xy, sig) %#ok<INUSL>
            spec = mgv21.placement.defaultPlacement("MANUAL");
            for k = 1:size(xy, 1), spec = mgv21.placement.addTarget(spec, xy(k,:), sig(k)); end
        end
        function spec = randomSpec(~, seed, count)
            spec = mgv21.placement.defaultPlacement("RANDOM"); spec.seed = seed; spec.count = count;
        end
    end

    methods (Test)
        function defaultsAndModes(tc)
            for m = ["NONE", "MANUAL", "RANDOM"]
                s = mgv21.placement.defaultPlacement(m);
                tc.verifyEqual(s.mode, m); tc.verifyEqual(s.schema_version, "mg-v21-placement/1.0");
            end
            tc.verifyEqual(mgv21.placement.defaultPlacement().mode, "NONE");
            tc.verifyError(@() mgv21.placement.defaultPlacement("GRID"), 'mgv21:InvalidPlacement');
        end

        function manualAddMoveDelete(tc)
            s = tc.manualSpec([10 5; -10 -5; 25 -15], ["VISIBLE_DISTURBANCE", "NONE", "VISIBLE_DISTURBANCE"]);
            tc.verifyEqual(height(s.manual), 3);
            s = mgv21.placement.moveTarget(s, 2, [-12 -8]);
            tc.verifyEqual([s.manual.x_east_m(2) s.manual.y_north_m(2)], [-12 -8]);
            s = mgv21.placement.deleteTarget(s, 1);
            tc.verifyEqual(height(s.manual), 2);
            tc.verifyEqual(s.manual.surface_signature', ["NONE", "VISIBLE_DISTURBANCE"]);
            [truth, rep] = mgv21.placement.placeTargets(s, tc.Pub, tc.W);
            tc.verifyEqual(truth.targets.target_id', ["V21-T01", "V21-T02"]);
            tc.verifyEqual([truth.targets.x_east_m truth.targets.y_north_m], [-12 -8; 25 -15]);
            tc.verifyEqual([rep.n_visible rep.n_no_signature], [1 1]);
            tc.verifyError(@() mgv21.placement.moveTarget(s, 3, [0 5]), 'mgv21:InvalidPlacement');
            tc.verifyError(@() mgv21.placement.deleteTarget(s, 0), 'mgv21:InvalidPlacement');
        end

        function manualEditInputsAreChecked(tc)
            tc.verifyError(@() mgv21.placement.addTarget(mgv21.placement.defaultPlacement("RANDOM"), [1 2]), 'mgv21:InvalidPlacement');
            s = mgv21.placement.defaultPlacement("MANUAL");
            tc.verifyError(@() mgv21.placement.addTarget(s, [NaN 2]), 'mgv21:InvalidPlacement');
            tc.verifyError(@() mgv21.placement.addTarget(s, [1 2], "MINE"), 'mgv21:InvalidPlacement');
            tc.verifyError(@() mgv21.placement.addTarget(s, [1 2], "NONE", -1), 'mgv21:InvalidPlacement');
        end

        function forbiddenManualLocationsAreRejected(tc)
            s0 = mgv21.placement.addExclusionZone(mgv21.placement.defaultPlacement("MANUAL"), "CIRCLE", [-20 -20], 4);
            s0 = mgv21.placement.addExclusionZone(s0, "POLYGON", [30 15; 38 15; 38 25; 30 25]);
            bad = [50 0; 39.6 0; 0 0.6; 20 11; -20 -18; 34 20];   % outside, edge margin, rock, landmark, circle, polygon zone
            for k = 1:size(bad, 1)
                [ok, why] = mgv21.placement.checkLocation(s0, tc.Pub, tc.W, bad(k,:));
                tc.verifyFalse(ok, sprintf('row %d', k)); tc.verifyNotEqual(why, "");
                s = mgv21.placement.addTarget(s0, bad(k,:));
                tc.verifyError(@() mgv21.placement.placeTargets(s, tc.Pub, tc.W), 'mgv21:InvalidPlacement', sprintf('row %d', k));
            end
            s = mgv21.placement.addTarget(mgv21.placement.addTarget(s0, [5 5]), [6 5]);   % 1 m < min spacing 3 m
            tc.verifyError(@() mgv21.placement.placeTargets(s, tc.Pub, tc.W), 'mgv21:InvalidPlacement');
            [ok, why] = mgv21.placement.checkLocation(s0, tc.Pub, tc.W, [5 5]);
            tc.verifyTrue(ok); tc.verifyEqual(why, "");
            [ok, ~] = mgv21.placement.checkLocation(s, tc.Pub, tc.W, [6 6], 2);   % moving row 2 ignores itself, not row 1
            tc.verifyFalse(ok);
        end

        function sameSeedSameTargets(tc)
            a = mgv21.placement.placeTargets(tc.randomSpec(42, 8), tc.Pub, tc.W);
            b = mgv21.placement.placeTargets(tc.randomSpec(42, 8), tc.Pub, tc.W);
            tc.verifyEqual(a, b);
            tc.verifyEqual([a.seed a.mode a.generator], [42 "RANDOM" "mrg32k3a"]);
        end

        function differentSeedOrCountDiffers(tc)
            a = mgv21.placement.placeTargets(tc.randomSpec(42, 8), tc.Pub, tc.W);
            b = mgv21.placement.placeTargets(tc.randomSpec(43, 8), tc.Pub, tc.W);
            c = mgv21.placement.placeTargets(tc.randomSpec(42, 3), tc.Pub, tc.W);
            tc.verifyNotEqual([a.targets.x_east_m a.targets.y_north_m], [b.targets.x_east_m b.targets.y_north_m]);
            tc.verifyEqual(height(c.targets), 3);
            tc.verifyEqual(c.targets(:, 2:3), a.targets(1:3, 2:3), 'positions are a seeded sequence');
        end

        function randomRespectsAllConstraints(tc)
            s = tc.randomSpec(7, 20); s.min_spacing_m = 5; s.edge_margin_m = 3;
            s = mgv21.placement.addExclusionZone(s, "CIRCLE", [0 0], 10);
            [t, rep] = mgv21.placement.placeTargets(s, tc.Pub, tc.W);
            x = t.targets.x_east_m; y = t.targets.y_north_m;
            tc.verifyEqual(height(t.targets), 20);
            tc.verifyGreaterThanOrEqual(rep.min_pair_distance_m, 5);
            tc.verifyTrue(all(abs(x) <= 37 & abs(y) <= 27), 'edge margin');
            tc.verifyTrue(all(hypot(x, y) > 10), 'exclusion zone (and the rock)');
            tc.verifyTrue(all(hypot(x - 20, y - 10) >= 2.1), 'landmark keep-out');
        end

        function visibleFractionChangesSignaturesNotPositions(tc)
            s1 = tc.randomSpec(9, 10); s1.visible_fraction = 1; s0 = s1; s0.visible_fraction = 0;
            a = mgv21.placement.placeTargets(s1, tc.Pub, tc.W); b = mgv21.placement.placeTargets(s0, tc.Pub, tc.W);
            tc.verifyEqual(a.targets(:, 2:3), b.targets(:, 2:3));
            tc.verifyTrue(all(a.targets.surface_signature == "VISIBLE_DISTURBANCE"));
            tc.verifyTrue(all(b.targets.surface_signature == "NONE"));
        end

        function zeroTargetsAreValid(tc)
            for s = {mgv21.placement.defaultPlacement("NONE"), tc.randomSpec(1, 0), mgv21.placement.defaultPlacement("MANUAL")}
                priv = mgv21.placement.lockScenario(s{1}, tc.Pub, tc.W);
                tc.verifyEqual(height(priv.truth.targets), 0);
                tc.verifyGreaterThanOrEqual(priv.n_clutter, 6, 'clutter is present even without targets');
                tc.verifyEqual(numel(priv.surface_features), priv.n_clutter);
            end
        end

        function impossiblePlacementThrows(tc)
            s = tc.randomSpec(1, 50); s.min_spacing_m = 50;
            tc.verifyError(@() mgv21.placement.placeTargets(s, tc.Pub, tc.W), 'mgv21:PlacementInfeasible');
            s = mgv21.placement.addExclusionZone(tc.randomSpec(1, 1), "POLYGON", [-45 -35; 45 -35; 45 35; -45 35]);
            tc.verifyError(@() mgv21.placement.placeTargets(s, tc.Pub, tc.W), 'mgv21:PlacementInfeasible');
            s = tc.randomSpec(1, 51);
            tc.verifyError(@() mgv21.placement.placeTargets(s, tc.Pub, tc.W), 'mgv21:InvalidPlacement');
        end

        function markersOnlyForManualDuringSetup(tc)
            s = tc.manualSpec([10 5; -10 -5], ["VISIBLE_DISTURBANCE", "NONE"]);
            tc.verifyEqual(height(mgv21.placement.setupMarkers(s, "SETUP")), 2);
            tc.verifyEqual(height(mgv21.placement.setupMarkers(s, "LOCKED")), 0);
            tc.verifyEqual(height(mgv21.placement.setupMarkers(s, "RUN")), 0);
            tc.verifyEqual(height(mgv21.placement.setupMarkers(tc.randomSpec(1, 5), "SETUP")), 0);
        end

        function truthNeverReachesPublicRecords(tc)
            pub0 = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", mgv21.scenario.defaultSurvey());
            s = tc.manualSpec([10 5; -10 -5], ["VISIBLE_DISTURBANCE", "NONE"]);
            priv = mgv21.placement.lockScenario(s, tc.Pub, tc.W);
            tc.verifyEqual(tc.Pub, pub0, 'pub does not depend on placement');
            mgv21.scenario.assertPublic(tc.Pub, "pub");
            mgv2.sensors.assertPublic(priv.surface_features, "SurfaceFeatures");
            tc.verifyEqual(sort(string(fieldnames(priv.surface_features)))', ...
                sort(["center_enu_m","radius_m","edge_m","albedo_rgb","albedo_mix","delta_T_K","emissivity"]));
            tc.verifyError(@() mgv21.scenario.assertPublic(priv), 'mgv2:TruthLeak');
            tc.verifyError(@() mgv21.scenario.assertPublic(struct('x', s)), 'mgv2:TruthLeak');
            tc.verifyError(@() mgv21.scenario.assertPublic(priv.truth), 'mgv2:TruthLeak');
        end

        function noSignatureTargetsChangeNothingObservable(tc)
            s = tc.manualSpec([10 5; -10 -5; 25 -15; -25 15], ["VISIBLE_DISTURBANCE", "NONE", "VISIBLE_DISTURBANCE", "NONE"]);
            truth = mgv21.placement.placeTargets(s, tc.Pub, tc.W);
            cut = truth; cut.targets = truth.targets(truth.targets.surface_signature ~= "NONE", :);
            tc.verifyEqual(mgv21.placement.forwardFeatures(truth, s, tc.Pub, tc.W), mgv21.placement.forwardFeatures(cut, s, tc.Pub, tc.W));
            allNone = tc.manualSpec([10 5; -10 -5], ["NONE", "NONE"]);
            a = mgv21.placement.lockScenario(allNone, tc.Pub, tc.W);
            b = mgv21.placement.lockScenario(mgv21.placement.defaultPlacement("NONE"), tc.Pub, tc.W);
            tc.verifyEqual(a.surface_features, b.surface_features, 'buried no-signature targets add no observable effect');
        end

        function visibleTargetsHideAmongClutter(tc)
            s = tc.manualSpec([10 5; -10 -5; 25 -15], repmat("VISIBLE_DISTURBANCE", 1, 3));
            [f, info] = mgv21.placement.forwardFeatures(mgv21.placement.placeTargets(s, tc.Pub, tc.W), s, tc.Pub, tc.W);
            tc.verifyEqual(info.n_visible_features, 3);
            tc.verifyGreaterThan(info.n_clutter, info.n_visible_features);
            tc.verifyEqual(numel(f), 3 + info.n_clutter);
            c = vertcat(f.center_enu_m); isTgt = ismember(round(c, 9), round([10 5; -10 -5; 25 -15], 9), 'rows');
            tc.verifyEqual(nnz(isTgt), 3);
            mixT = [f(isTgt).albedo_mix]; mixC = [f(~isTgt).albedo_mix];
            tc.verifyTrue(any(mixC >= min(mixT) & mixC <= max(mixT)), 'clutter overlaps target appearance');
        end

        function realWorldRandomKeepsOffObjects(tc)
            p = mgv21.scenario.environmentPreset("TRAINING_FIELD_A"); w = mgv2.scene.buildWorld(p.scene_config);
            pub = mgv21.scenario.buildPublicMission("TRAINING_FIELD_A", p.default_survey);
            t = mgv21.placement.placeTargets(tc.randomSpec(2026, 12), pub, w).targets;
            O = w.objects;
            for k = 1:height(t)
                d = hypot(O.x_east_m - t.x_east_m(k), O.y_north_m - t.y_north_m(k)) - O.radius_m;
                tc.verifyGreaterThanOrEqual(min(d), 0.5);
            end
            priv = mgv21.placement.lockScenario(tc.randomSpec(2026, 12), pub, w);
            tc.verifyEqual(priv.truth.targets, t);
        end
    end
end
