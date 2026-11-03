classdef testV21SetupUI < matlab.uitest.TestCase
    %TESTV21SETUPUI V21-005 mission SETUP window tests. SIMULATION ONLY: targets are private synthetic hypotheses.
    %   From the repository root:  runtests('v2_1/tests/testV21SetupUI.m')
    %   Needs a graphics desktop. Most tests drive the public test API with the window hidden; the tests named
    %   gui* open a visible window and press the real controls. Every placement check uses only the frozen
    %   mg-v21-contract/1.0 functions; nothing here weakens or replaces Shabaz's validators.

    properties
        App
        Launches = struct('pub', {}, 'world', {}, 'priv', {})
    end

    methods (TestClassSetup)
        function setup(tc)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2', 'matlab')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'v2_1', 'matlab')));
        end
    end

    methods (TestMethodTeardown)
        function closeApp(tc)
            if ~isempty(tc.App) && isvalid(tc.App), delete(tc.App); end
            tc.App = []; tc.Launches = struct('pub', {}, 'world', {}, 'priv', {});
        end
    end

    methods (Access = private)
        function app = open(tc, varargin)
            app = mgv21.ui.MissionSetupApp('Visible', "off", 'OnLaunch', @(p, w, v) tc.record(p, w, v), varargin{:});
            tc.App = app;
        end

        function record(tc, pub, world, priv)
            tc.Launches(end+1) = struct('pub', pub, 'world', world, 'priv', priv);
        end

        function xy = addManual(tc, app, n)
            %ADDMANUAL Click candidate points inside the boundary until n targets were accepted by checkLocation.
            P = app.Survey.polygon_enu_m; xy = zeros(0, 2);
            [gx, gy] = meshgrid(min(P(:, 1)) + 4:7:max(P(:, 1)) - 4, min(P(:, 2)) + 4:7:max(P(:, 2)) - 4);
            for c = [gx(:) gy(:)]'
                if size(xy, 1) >= n, break; end
                if ~all(inpolygon(c(1) + [-3 3 3 -3], c(2) + [-3 -3 3 3], P(:, 1), P(:, 2))), continue; end
                before = app.NumManualTargets;
                app.clickMap(c(1), c(2));
                if app.NumManualTargets == before + 1, xy(end+1, :) = c'; end %#ok<AGROW>
            end
            tc.assertEqual(size(xy, 1), n, 'could not find enough accepted MANUAL locations inside the survey');
        end

        function xy = markerXY(~, app)
            %MARKERXY Every target marker drawn on the setup map (both signature styles).
            xy = zeros(0, 2);
            for tag = ["setup_marker_visible", "setup_marker_none"]
                h = findall(app.Figure, 'Tag', tag);
                x = h.XData(:); y = h.YData(:); keep = ~isnan(x);
                xy = [xy; x(keep) y(keep)]; %#ok<AGROW>
            end
        end

        function verifyRouteHidden(tc, app)
            h = findall(app.Figure, 'Tag', 'setup_route');
            tc.verifyFalse(app.RouteVisible);
            tc.verifyTrue(all(isnan(h.XData)), 'an invalid survey must draw no route');
            tc.verifyEmpty(app.Pub);
            tc.verifyEqual(string(app.Controls.lock.Enable), "off", 'LOCK must be disabled for an invalid survey');
        end

        function verifyRouteShown(tc, app)
            %VERIFYROUTESHOWN The drawn route is the V2 route of planSurvey(pub.mission) (contract §3).
            h = findall(app.Figure, 'Tag', 'setup_route');
            route = mgv2.mission.buildRoute(app.Pub.mission, mgv2.mission.planSurvey(app.Pub.mission));
            tc.verifyTrue(app.RouteVisible);
            tc.verifyEqual([h.XData(:) h.YData(:)], route.xy, 'AbsTol', 1e-9);
            tc.verifyEqual(app.ValidationErrorId, "");
            tc.verifyEqual(string(app.Controls.lock.Enable), "on");
        end
    end

    methods (Test)
        function threePresetsGiveDifferentWorlds(tc)
            app = tc.open(); ids = mgv21.scenario.presetIds();
            tc.verifyEqual(numel(ids), 3);
            Z = cell(1, numel(ids)); R = cell(1, numel(ids));
            for k = 1:numel(ids)
                app.selectPreset(ids(k));
                tc.verifyEqual(app.PresetId, ids(k));
                tc.verifyEqual(string(app.Controls.preset.Value), ids(k));
                tc.verifyEqual(string(app.Pub.preset_id), ids(k));
                tc.verifyEqual(string(app.Pub.schema_version), "mg-v21-public/1.0");
                tc.verifyEqual(app.World.Z, mgv21.scenario.buildWorld(app.Pub).Z, 'map world must be buildWorld(pub)');
                tc.verifySubstring(string(app.Controls.presetInfo.Text), string(mgv21.scenario.environmentPreset(ids(k)).title));
                tc.verifyRouteShown(app);
                img = findall(app.Figure, 'Tag', 'setup_terrain');
                tc.verifyNumElements(img, 1, 'exactly one terrain image');
                Z{k} = app.World.Z; R{k} = app.Pub.mission;
            end
            for a = 1:numel(ids)
                for b = a+1:numel(ids)
                    tc.verifyFalse(isequal(Z{a}, Z{b}), sprintf('presets %s and %s must give different terrain', ids(a), ids(b)));
                    tc.verifyFalse(isequal(R{a}, R{b}), sprintf('presets %s and %s must give different missions', ids(a), ids(b)));
                end
            end
        end

        function altitudeBelowLimitIsRejected(tc)
            app = tc.open(); lim = mgv21.contract().limits.alt_agl_m;
            app.setGrid("alt_agl_m", lim(1) - 1);
            tc.verifyEqual(app.ValidationErrorId, "mgv21:InvalidSurvey");
            tc.verifyTrue(startsWith(app.ValidationText, "INVALID SURVEY: "));
            tc.verifyEqual(string(app.Controls.validation.Text), app.ValidationText, 'the error is shown in the window');
            tc.verifyEqual(app.Controls.validation.FontColor, mgv2.ui.theme().stale);
            tc.verifyRouteHidden(app);
            tc.verifyFalse(app.lockAndStart()); tc.verifyEqual(app.Phase, "SETUP"); tc.verifyEmpty(tc.Launches);
            app.setGrid("alt_agl_m", mean(lim));
            tc.verifyRouteShown(app);
        end

        function tooSmallPolygonIsRejected(tc)
            app = tc.open(); c = mean(app.Survey.polygon_enu_m, 1);
            app.setPolygon(c + [0 0; 5 0; 0 5]);                % 12.5 m^2, below the contract minimum area
            tc.verifyLessThan(12.5, mgv21.contract().limits.min_area_m2);
            tc.verifyEqual(app.ValidationErrorId, "mgv21:InvalidSurvey");
            tc.verifyRouteHidden(app);
            b = findall(app.Figure, 'Tag', 'setup_boundary');
            tc.verifyEqual([b.XData(1:3)' b.YData(1:3)'], c + [0 0; 5 0; 0 5], 'the rejected boundary stays visible for editing');
        end

        function rectangleAndGridEditsRebuildRoute(tc)
            app = tc.open(); P = app.Survey.polygon_enu_m;
            x = [min(P(:, 1)) max(P(:, 1))]; y = [min(P(:, 2)) max(P(:, 2))];
            app.setRectangle(x(1) + 2, x(2) - 2, y(1) + 2, y(2) - 2);
            tc.verifyEqual(string(app.Survey.boundary_kind), "RECTANGLE");
            tc.verifyEqual(app.Survey.polygon_enu_m, mgv21.scenario.validateSurvey(app.Survey, app.PresetId).polygon_enu_m);
            tc.verifyRouteShown(app);
            app.setGrid("line_spacing_m", 2 * app.Survey.line_spacing_m);
            tc.verifyRouteShown(app);
            app.setRectangle(x(2), x(1), y(1), y(2));               % xmin > xmax
            tc.verifyRouteHidden(app);
        end

        function manualAddMoveDelete(tc)
            app = tc.open(); app.setMode("MANUAL"); app.setTool("ADD");
            tc.verifyEqual(app.NumManualTargets, 0); tc.verifyEqual(app.NumSetupMarkers, 0);
            xy = tc.addManual(app, 3);
            tc.verifyEqual(app.NumManualTargets, 3); tc.verifyEqual(app.NumSetupMarkers, 3);
            tc.verifyEqual(sortrows(tc.markerXY(app)), sortrows(xy), 'AbsTol', 1e-9);
            % MOVE: pick the first marker, then a destination accepted by checkLocation
            app.setTool("MOVE");
            app.clickMap(xy(1, 1) + 0.5, xy(1, 2) + 0.5);
            tc.verifyFalse(app.PlacementRefused);
            tc.verifyEqual(app.NumManualTargets, 3);
            dest = xy(1, :) + [0 3.5];
            app.clickMap(dest(1), dest(2));
            if app.PlacementRefused                  % the destination may be blocked by scene content: try the other side
                dest = xy(1, :) - [0 3.5]; app.clickMap(dest(1), dest(2));
            end
            tc.assertFalse(app.PlacementRefused, app.PlacementMessage);
            tc.verifyEqual(app.NumManualTargets, 3);
            tc.verifyEqual(sortrows(tc.markerXY(app)), sortrows([dest; xy(2:3, :)]), 'AbsTol', 1e-9);
            % DELETE: a click away from any marker deletes nothing
            app.setTool("DELETE");
            app.clickMap(dest(1) + 40, dest(2) + 40);
            tc.verifyTrue(app.PlacementRefused); tc.verifyEqual(app.NumManualTargets, 3);
            app.clickMap(xy(2, 1) + 1, xy(2, 2));
            tc.verifyEqual(app.NumManualTargets, 2); tc.verifyEqual(app.NumSetupMarkers, 2);
            tc.verifyEqual(sortrows(tc.markerXY(app)), sortrows([dest; xy(3, :)]), 'AbsTol', 1e-9);
        end

        function invalidLocationIsRefused(tc)
            app = tc.open(); app.setMode("MANUAL"); app.setSignature("NONE");
            P = app.Survey.polygon_enu_m;
            app.clickMap(max(P(:, 1)) + 20, mean(P(:, 2)));        % outside the survey boundary
            tc.verifyTrue(app.PlacementRefused);
            tc.verifyTrue(startsWith(app.PlacementMessage, "REFUSED: "));
            tc.verifyGreaterThan(strlength(app.PlacementMessage), strlength("REFUSED: "), 'the reason is shown');
            tc.verifyEqual(string(app.Controls.placementMsg.Text), app.PlacementMessage);
            tc.verifyEqual(app.NumManualTargets, 0); tc.verifyEqual(app.NumSetupMarkers, 0);
            xy = tc.addManual(app, 1);
            h = findall(app.Figure, 'Tag', 'setup_marker_none');
            tc.verifyEqual([h.XData(:) h.YData(:)], xy, 'AbsTol', 1e-9, 'a NONE-signature target uses the NONE marker style');
            app.clickMap(xy(1) + 0.2, xy(2));                       % closer than min_spacing_m to the first target
            tc.verifyTrue(app.PlacementRefused); tc.verifyEqual(app.NumManualTargets, 1);
        end

        function randomPlacementUsesCountAndSeed(tc)
            app = tc.open(); app.setMode("RANDOM");
            d = mgv21.placement.defaultPlacement("RANDOM");
            tc.verifyEqual(app.Controls.visibleFraction.Value, d.visible_fraction);
            app.setRandom(5, 1234);
            tc.verifyEqual(app.NumSetupMarkers, 0, 'RANDOM targets are never drawn during setup');
            app.clickMap(mean(app.Survey.polygon_enu_m(:, 1)), mean(app.Survey.polygon_enu_m(:, 2)));
            tc.verifyTrue(app.PlacementRefused); tc.verifyEqual(app.NumManualTargets, 0);
            tc.verifyTrue(app.lockAndStart());
            tc.assertNumElements(tc.Launches, 1);
            T = tc.Launches(1).priv.truth;
            tc.verifyEqual(string(T.mode), "RANDOM"); tc.verifyEqual(double(T.seed), 1234);
            tc.verifyEqual(height(T.targets), 5);
            first = T.targets;
            % the same preset, survey, count and seed in a new window give the same private placement
            delete(app); tc.Launches = struct('pub', {}, 'world', {}, 'priv', {});
            app = tc.open(); app.setMode("RANDOM"); app.setRandom(5, 1234); app.lockAndStart();
            tc.assertNumElements(tc.Launches, 1);
            tc.verifyEqual(tc.Launches(1).priv.truth.targets, first);
        end

        function lockLaunchesOnceAndHidesMarkers(tc)
            app = tc.open(); app.setMode("MANUAL"); tc.addManual(app, 2);
            tc.verifyEqual(app.NumSetupMarkers, 2);
            tc.verifyTrue(app.lockAndStart());
            tc.assertNumElements(tc.Launches, 1, 'OnLaunch exactly once');
            L = tc.Launches(1);
            mgv21.scenario.assertPublic(L.pub, "launched pub");
            tc.verifyEqual(L.pub, app.Pub); tc.verifyEqual(L.world, app.World);
            tc.verifyEqual(string(L.priv.schema_version), "mg-v21-private/1.0");
            tc.verifyEqual(string(L.priv.truth.schema_version), "mg-v21-truth/1.0");
            tc.verifyEqual(height(L.priv.truth.targets), 2);
            tc.verifyEqual(app.Phase, "LOCKED");
            tc.verifyEqual(app.NumSetupMarkers, 0); tc.verifyEmpty(tc.markerXY(app), 'every target marker is gone after LOCK');
            for f = string(fieldnames(app.Controls))'
                h = app.Controls.(f);
                if isa(h, 'matlab.ui.control.Label'), continue; end
                tc.verifyEqual(string(h.Enable), "off", f + " must be disabled after LOCK");
            end
            tc.verifyFalse(any(app.Controls.polygon.ColumnEditable));
            tc.verifyFalse(app.lockAndStart()); tc.verifyNumElements(tc.Launches, 1, 'a second lock launches nothing');
            app.clickMap(0, 0); tc.verifyTrue(app.PlacementRefused); tc.verifyEqual(app.NumSetupMarkers, 0);
            tc.verifyError(@() app.setGrid("alt_agl_m", 20), 'mgv21ui:Locked');
            tc.verifyError(@() app.setMode("NONE"), 'mgv21ui:Locked');
        end

        function publicStateNeverHoldsTruth(tc)
            app = tc.open(); app.setMode("MANUAL"); tc.addManual(app, 2);
            mgv21.scenario.assertPublic(app.publicState(), "setup app (SETUP)");
            names = string(properties(app));
            tc.verifyEmpty(intersect(lower(names), ["spec", "privslot", "priv", "truth", "placement"]), 'no private object is a public property');
            for p = names'
                v = app.(p);
                if p == "Controls" || isobject(v) && ~isstring(v), continue; end      % window and control handles
                mgv21.scenario.assertPublic(struct(char(p), {v}), "app." + p);
            end
            app.lockAndStart();
            mgv21.scenario.assertPublic(app.publicState(), "setup app (LOCKED)");
            tc.verifyFalse(contains(app.PlacementMessage, string(height(tc.Launches(1).priv.truth.targets)) + " target"), ...
                'the locked message does not reveal the target count');
        end

        function noneModeLocksAndDefaultLaunchCloses(tc)
            before = numel(findall(groot, 'Type', 'figure'));
            app = mgv21.ui.MissionSetupApp('Visible', "off"); tc.App = app;
            tc.verifyEqual(app.Mode, "NONE");
            tc.verifyTrue(app.lockAndStart());
            tc.verifyFalse(isvalid(app), 'the default OnLaunch closes the setup window');
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), before);
        end

        function closeLeavesNothing(tc)
            before = numel(findall(groot, 'Type', 'figure')); tm = numel(timerfindall);
            app = tc.open(); fig = app.Figure;
            close(fig); drawnow;
            tc.verifyFalse(isvalid(fig)); tc.verifyFalse(isvalid(app));
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), before);
            tc.verifyEqual(numel(timerfindall), tm);
        end

        function guiControlsDriveTheSetup(tc)
            app = tc.open('Visible', "on"); ids = mgv21.scenario.presetIds();
            tc.choose(app.Controls.preset, char(ids(2)));
            tc.verifyEqual(app.PresetId, ids(2)); tc.verifyRouteShown(app);
            lim = mgv21.contract().limits.alt_agl_m;
            tc.type(app.Controls.alt_agl_m, lim(1) - 1);
            tc.verifyEqual(app.ValidationErrorId, "mgv21:InvalidSurvey"); tc.verifyRouteHidden(app);
            tc.type(app.Controls.alt_agl_m, mean(lim));
            tc.verifyRouteShown(app);
            tc.choose(app.Controls.mode, 'MANUAL');
            tc.verifyEqual(app.Mode, "MANUAL");
            xy = tc.addManual(app, 1);
            app.setTool("DELETE"); app.clickMap(xy(1), xy(2)); tc.verifyEqual(app.NumManualTargets, 0);
            tc.choose(app.Controls.tool, 'ADD');
            tc.press(app.MapAxes, xy);                               % a real click on the map at an accepted location
            tc.verifyEqual(app.NumManualTargets, 1, app.PlacementMessage);
            tc.verifyEqual(app.NumSetupMarkers, 1);
            tc.press(app.Controls.lock);
            tc.verifyNumElements(tc.Launches, 1); tc.verifyEqual(app.Phase, "LOCKED"); tc.verifyEmpty(tc.markerXY(app));
        end
    end
end
