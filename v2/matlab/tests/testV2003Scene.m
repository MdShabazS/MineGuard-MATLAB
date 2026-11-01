classdef testV2003Scene < matlab.unittest.TestCase
    %TESTV2003SCENE V2-003 terrain, aircraft model, renderer, cameras and sensor geometry. SIMULATION ONLY.
    %   Needs a MATLAB desktop with a display (it renders real figures). From the repository root:
    %     addpath('v2/matlab'); runtests('v2/matlab/tests/testV2003Scene.m')
    %   Engine poses come from V2-002 (mgv2.engine.MissionEngine) flying over this world, plus fixtures.

    properties
        W; Eng; T; R
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
            tc.W = mgv2.scene.buildWorld();
            tc.Eng = mgv2.engine.MissionEngine(mgv2.mission.defaultConfig(), mgv2.scene.terrainProvider(tc.W));
            tc.Eng.run(); tc.T = tc.Eng.poseLog();
            tc.R = mgv2.scene.SceneRenderer(tc.W, Position=[40 40 1200 720]);
            tc.addTeardown(@() delete(tc.R));
        end
    end

    methods (Static)
        function p = pose(T, k)
            row = T(k, :);
            p = struct('position_enu_m', row.position_enu_m, 'orientation_quat', row.orientation_quat, 't_s', row.t_s, ...
                'yaw_rad', row.yaw_rad, 'phase', row.phase, 'altitude_agl_m', row.altitude_agl_m);
        end
        function p = fixture(xyz, yaw, pitch, roll)
            p = struct('position_enu_m', xyz, 'orientation_quat', mgv2.frames.quatFromYawPitchRoll(yaw, pitch, roll), ...
                't_s', 0, 'yaw_rad', yaw);
        end
        function q = pct(x, p)
            x = sort(x(:)); q = x(max(1, min(numel(x), round(p / 100 * numel(x)))));
        end
        function Pw = aircraftWorldVertices(pose)
            parts = mgv2.scene.quadrotorModel(); V = vertcat(parts.V);
            Pw = V * mgv2.frames.quatToRotm(pose.orientation_quat)' + pose.position_enu_m;
        end
    end

    methods (Test)
        function s01_terrainInitialisation(tc)
            w = tc.W; c = w.config;
            tc.verifyEqual(w.schema_version, "mg-v2-scene/0.1");
            tc.verifyEqual(size(w.Z), [numel(w.y) numel(w.x)]);
            tc.verifyEqual(size(w.V, 1), numel(w.Z)); tc.verifyEqual(size(w.F, 1), 2 * (numel(w.x) - 1) * (numel(w.y) - 1));
            tc.verifyTrue(all(isfinite(w.V), 'all')); tc.verifyTrue(all(w.vertex_rgb >= 0 & w.vertex_rgb <= 1, 'all'));
            tc.verifyGreaterThan(max(w.Z(:)) - min(w.Z(:)), 3, 'meaningful relief (not a flat plane)');
            tc.verifyEqual(sort(unique(w.objects.kind))', ["bush","marker","rock"]);
            tc.verifyEqual(height(w.objects), c.n_rocks + c.n_bushes + size(c.survey_polygon_enu_m, 1));
        end

        function s02_deterministicGeometry(tc)
            a = mgv2.scene.buildWorld(); tc.verifyTrue(isequaln(a, tc.W), 'same seed -> identical world');
            b = mgv2.scene.buildWorld(mgv2.scene.defaultSceneConfig('seed', 3004));
            tc.verifyFalse(isequal(b.Z, tc.W.Z)); tc.verifyFalse(isequal(b.objects.x_east_m, tc.W.objects.x_east_m));
        end

        function s03_meshScaleAndRenderedVertices(tc)
            w = tc.W; c = w.config;
            tc.verifyEqual([min(w.V(:,1)) max(w.V(:,1)); min(w.V(:,2)) max(w.V(:,2))], c.extent_enu_m, 'AbsTol', 1e-12);
            tc.verifyEqual(unique(round(diff(w.x), 12)), c.grid_spacing_m); tc.verifyEqual(unique(round(diff(w.y), 12)), c.grid_spacing_m);
            h = tc.R.Handles.terrain;
            tc.verifyEqual(h.Vertices, w.V, 'renderer draws exactly the world vertices'); tc.verifyEqual(h.Faces, w.F);
            parts = mgv2.scene.quadrotorModel(); V = vertcat(parts.V);
            motors = parts(startsWith([parts.name], "motor")); mc = cell2mat(arrayfun(@(p) mean(p.V(:,1:2)), motors', 'UniformOutput', false));
            tc.verifyEqual(norm(mc(1,:) - mc(4,:)), 0.45, 'AbsTol', 0.01, 'motor-to-motor diagonal 0.45 m (F450 class)');
            tc.verifyEqual(min(V(:,3)), 0, 'AbsTol', 1e-12, 'skid bottoms at the body origin');
            tc.verifyLessThan(max(V(:,3)), 0.3); tc.verifyLessThan(max(abs(V(:,1:2)), [], 'all'), 0.4, 'rotor tips within 0.36 m');
        end

        function s04_heightAgreesWithRenderedTriangles(tc)
            w = tc.W; s = RandStream('mt19937ar', 'Seed', 4);
            tc.verifyEqual(mgv2.scene.heightAt(w, w.V(:,1), w.V(:,2)), w.V(:,3), 'AbsTol', 1e-12, 'exact at vertices');
            n = 400; xq = w.x(1) + (w.x(end) - w.x(1)) * rand(s, n, 1); yq = w.y(1) + (w.y(end) - w.y(1)) * rand(s, n, 1);
            zq = mgv2.scene.heightAt(w, xq, yq); F = tc.R.Handles.terrain.Faces; V = tc.R.Handles.terrain.Vertices;
            % independent reference: find the drawn triangle containing (x, y) and evaluate its plane
            dx = w.x(2) - w.x(1); ny = numel(w.y); nq = (numel(w.x) - 1) * (numel(w.y) - 1);
            for k = 1:n
                j = min(floor((xq(k) - w.x(1)) / dx) + 1, numel(w.x) - 1); i = min(floor((yq(k) - w.y(1)) / dx) + 1, ny - 1);
                cand = F([(j - 1) * (ny - 1) + i, nq + (j - 1) * (ny - 1) + i], :);
                found = false;
                for t = 1:2
                    A = V(cand(t,:), :); M = [A(2,1:2) - A(1,1:2); A(3,1:2) - A(1,1:2)]';
                    bc = M \ ([xq(k) yq(k)] - A(1,1:2))';
                    if all(bc >= -1e-9) && sum(bc) <= 1 + 1e-9
                        zr = A(1,3) + bc(1) * (A(2,3) - A(1,3)) + bc(2) * (A(3,3) - A(1,3)); found = true;
                    end
                end
                tc.assertTrue(found, 'query point lies in one of its cell''s two drawn triangles');
                tc.verifyEqual(zq(k), zr, 'AbsTol', 1e-9);
            end
            tc.verifyTrue(all(isnan(mgv2.scene.heightAt(w, [w.x(1) - 1, 0], [0, w.y(end) + 1]))), 'NaN outside the terrain');
        end

        function s05_objectsSeatedAndOffThePad(tc)
            w = tc.W; O = w.objects; c = w.config;
            for k = 1:height(O)
                [V, ~] = mgv2.scene.objectMesh(O(k, :));
                zg = mgv2.scene.heightAt(w, V(:,1), V(:,2));
                tc.verifyLessThanOrEqual(min(V(:,3)) - min(zg), 1e-9, O.object_id(k) + " base not floating above the ground");
                tc.verifyGreaterThanOrEqual(mean(V(:,3) > zg), 0.3, O.object_id(k) + " visible: >= 30% of its vertices above the local ground");
            end
            nonMarker = O.kind ~= "marker";
            tc.verifyTrue(all(max(abs([O.x_east_m(nonMarker) O.y_north_m(nonMarker)] - c.home_enu_m), [], 2) > c.home_pad_m), 'pad kept clear');
            for g = ["rock","bush","marker"]
                tc.verifyEqual(size(tc.R.Handles.("obj_" + g).Faces, 1) > 0, any(O.kind == g), g + " drawn as one patch");
            end
        end

        function s06_aircraftVisibleInEachMode(tc)
            k = find(tc.T.phase == "SURVEY", 1) + 300; p = testV2003Scene.pose(tc.T, k); r = tc.R;
            r.update(p); pos = r.Figure.Position; asp = pos(3) / pos(4);
            for m = ["follow","chase","orbit"]
                r.setCameraMode(m); drawnow;
                v = struct('position', r.Axes.CameraPosition, 'target', r.Axes.CameraTarget, 'up', r.Axes.CameraUpVector, 'view_angle_deg', r.Axes.CameraViewAngle);
                Pw = testV2003Scene.aircraftWorldVertices(p);
                [in, ndc] = mgv2.scene.viewContains(v, Pw, asp, 0.95);
                tc.verifyTrue(all(in), m + ": whole aircraft on screen");
                spanPx = (max(ndc(:,1)) - min(ndc(:,1))) / 2 * min(pos(3), pos(4));
                tc.verifyGreaterThan(spanPx, 15, m + ": aircraft at least 15 px wide");
            end
            tc.verifyTrue(all(isgraphics(findobj(r.Handles.aircraft, 'Type', 'patch'))));
            tc.verifyEqual(numel(findobj(r.Handles.aircraft, 'Type', 'patch')), numel(mgv2.scene.quadrotorModel()));
            for m = ["isometric","topdown"]
                r.setCameraMode(m); drawnow; tc.verifyEqual(string(r.Handles.uavMarker.Visible), "on", m + ": screen-size marker shown");
            end
        end

        function s07_headingAndAttitude(tc)
            r = tc.R;
            p = testV2003Scene.fixture([0 0 20], 0, 0, 0); r.update(p);
            M = r.Handles.aircraft.Matrix; nose = M * [0.2 0 0.17 1]';
            tc.verifyGreaterThan(nose(1), 0.19, 'yaw 0: nose (+x body) points EAST'); tc.verifyLessThan(abs(nose(2)), 1e-9);
            p = testV2003Scene.fixture([5 -3 18], deg2rad(30), deg2rad(-10), deg2rad(12)); r.update(p);
            M = r.Handles.aircraft.Matrix;
            tc.verifyEqual(M(1:3,1:3), mgv2.frames.quatToRotm(p.orientation_quat), 'AbsTol', 1e-12);
            tc.verifyEqual(M(1:3,4)', [5 -3 18], 'AbsTol', 1e-12);
            [y, pt, rl] = mgv2.frames.yawPitchRollFromQuat(rotm2q(M(1:3,1:3)));
            tc.verifyEqual([y pt rl], deg2rad([30 -10 12]), 'AbsTol', 1e-9);
            % red front arms are the +x arms: after yaw 90 deg (north) their centroid points north
            p = testV2003Scene.fixture([0 0 20], pi/2, 0, 0); r.update(p);
            arm = findobj(r.Handles.aircraft, 'Tag', 'arm1'); c = mean(arm.Vertices, 1) * mgv2.frames.quatToRotm(p.orientation_quat)';
            tc.verifyGreaterThan(c(2), 0.05, 'front (red) arm points north for heading 0 deg compass');
            tc.verifyEqual(arm.FaceColor, [0.95 0.30 0.10]);
            function q = rotm2q(R), q = mgv2.frames.rotmToQuat(R); end
        end

        function s08_noBelowGroundDuringNominalFlight(tc)
            T = tc.T; worst = inf; idx = 1:5:height(T);
            for k = idx
                Pw = testV2003Scene.aircraftWorldVertices(testV2003Scene.pose(T, k));
                worst = min(worst, min(Pw(:,3) - mgv2.scene.heightAt(tc.W, Pw(:,1), Pw(:,2))));
            end
            tc.verifyGreaterThanOrEqual(worst, -0.005, sprintf('no mesh vertex below terrain over %d poses (worst %.4f m)', numel(idx), worst));
            tc.verifyEqual(tc.Eng.Phase, "COMPLETE");
        end

        function s09_cameraModesKeepAircraftInView(tc)
            T = tc.T; ph = ["TAKEOFF","CLIMB","TRANSIT","SURVEY","RETURN_HOME","LANDING"];
            ks = [];
            for q = ph, ix = find(T.phase == q); ks = [ks, ix(round(linspace(1, numel(ix), 6)))']; end %#ok<AGROW>
            yawRate = [0; abs(diff(unwrap(T.yaw_rad)))]; [~, turn] = maxk(yawRate, 5); ks = [ks, turn'];
            for m = ["isometric","follow","chase","topdown","orbit"]
                for k = ks
                    p = testV2003Scene.pose(T, k);
                    v = mgv2.scene.cameraView(m, p, tc.W);
                    tc.verifyTrue(mgv2.scene.viewContains(v, p.position_enu_m, 1.6, 0.92), sprintf('%s keeps the aircraft in view at t=%.2f (%s)', m, p.t_s, p.phase));
                end
            end
            v = mgv2.scene.cameraView("isometric", testV2003Scene.pose(T, 1), tc.W);
            P = [tc.W.config.survey_polygon_enu_m, zeros(4, 1) + median(tc.W.Z(:)); tc.W.config.home_enu_m median(tc.W.Z(:))];
            tc.verifyTrue(all(mgv2.scene.viewContains(v, P, 1.6, 0.95)), 'isometric frames the survey area and home');
            tc.verifyError(@() mgv2.scene.cameraView("fisheye", testV2003Scene.pose(T, 1), tc.W), 'mgv2:InvalidCameraMode');
        end

        function s10_followCameraContinuity(tc)
            T = tc.T; ix = find(ismember(T.phase, ["TRANSIT","SURVEY","RETURN_HOME"]));
            for m = ["follow","chase"]
                r = tc.R; r.setCameraMode(m); P = zeros(numel(ix), 3);
                for i = 1:numel(ix), r.update(testV2003Scene.pose(T, ix(i))); P(i,:) = r.Axes.CameraPosition; end
                jump = max(vecnorm(diff(P), 2, 2));
                tc.verifyLessThan(jump, 1.2, sprintf('%s camera moves smoothly (max %.2f m per 0.05 s tick)', m, jump));
            end
        end

        function s11_sensorMountingTransforms(tc)
            rig = mgv2.scene.sensorRig();
            tc.verifyEqual([rig.id], ["rgb_nadir","thermal_nadir","lidar_nadir"]);
            for s = rig
                Rb = s.T_body_sensor(1:3,1:3);
                tc.verifyEqual(Rb' * Rb, eye(3), 'AbsTol', 1e-12); tc.verifyEqual(det(Rb), 1, 'AbsTol', 1e-12);
                tc.verifyEqual(Rb(:,3)', [0 0 -1], 'optical axis = body down');
                tc.verifyEqual(s.status, "PROVISIONAL (pending V2-004)");
            end
            level = testV2003Scene.fixture([10 20 30], deg2rad(40), 0, 0);
            T_ws = mgv2.scene.sensorPose(level, rig(1));
            tc.verifyEqual(T_ws(1:3,3)', [0 0 -1], 'AbsTol', 1e-12, 'level flight: camera looks straight down in ENU');
            f = mgv2.frames.quatToRotm(level.orientation_quat) * [1 0 0]';
            tc.verifyEqual(-T_ws(1:3,2), f, 'AbsTol', 1e-12, 'image up (-y_cam) = aircraft forward');
            tc.verifyEqual(T_ws(1:3,4)', [10 20 30] + (mgv2.frames.quatToRotm(level.orientation_quat) * rig(1).T_body_sensor(1:3,4))', 'AbsTol', 1e-12);
        end

        function s12_landmarkProjectionClosedLoop(tc)
            w = tc.W; L = w.landmarks(1); Pl = [L.xy L.z]; rig = mgv2.scene.sensorRig();
            cams = rig(1:2);
            poses = {testV2003Scene.fixture([Pl(1:2) + [2 -3], Pl(3) + 15], deg2rad(25), deg2rad(-6), deg2rad(4)), ...
                     testV2003Scene.fixture([Pl(1:2) + [-4 1], Pl(3) + 22], deg2rad(-100), deg2rad(3), deg2rad(-5))};
            for c = cams
                for i = 1:numel(poses)
                    T_ws = mgv2.scene.sensorPose(poses{i}, c);
                    [uv, ~, in] = mgv2.scene.projectToImage(c, T_ws, Pl); tc.assertTrue(in, 'landmark in image');
                    [O, D] = mgv2.scene.pixelRays(c, T_ws, uv); [Pg, hit] = mgv2.scene.intersectTerrain(w, O, D);
                    tc.verifyTrue(hit); tc.verifyLessThan(norm(Pg - Pl), 0.01, sprintf('%s back-projection within 1 cm (got %.4f m)', c.id, norm(Pg - Pl)));
                    [corners, ok] = mgv2.scene.cameraFootprint(w, c, T_ws); tc.verifyTrue(ok);
                    tc.verifyTrue(inpolygon(Pl(1), Pl(2), corners(:,1), corners(:,2)), 'landmark inside the ground footprint');
                end
            end
            % rendered raster: landmark-coloured pixels are centred on the projected pixel
            small = cams(2); T_ws = mgv2.scene.sensorPose(poses{1}, small);
            [img, valid] = mgv2.scene.renderNadirRaster(w, small, T_ws);
            tc.verifyEqual(size(img), [small.height_px small.width_px 3]); tc.verifyTrue(all(valid, 'all'));
            uv = mgv2.scene.projectToImage(small, T_ws, Pl);
            col = double(reshape(img, [], 3)) / 255; m = vecnorm(col - L.color, 2, 2) < 0.12;
            [vv, uu] = ind2sub([small.height_px small.width_px], find(m));
            tc.verifyGreaterThan(nnz(m), 3, 'landmark visible in the raster');
            tc.verifyLessThan(norm([mean(uu) mean(vv)] - uv), 1.5, 'landmark centroid within 1.5 px of its projection');
        end

        function s13_enuRenderConsistency(tc)
            r = tc.R; p = testV2003Scene.fixture([10 20 25], 0, 0, 0); r.update(p);
            tc.verifyEqual(r.Handles.aircraft.Matrix(1:3,4)', [10 20 25]);
            tc.verifyEqual(r.Axes.DataAspectRatio, [1 1 1], 'equal metres on all axes');
            tc.verifyEqual(string(r.Axes.XLabel.String), "x east [m]"); tc.verifyEqual(string(r.Axes.YLabel.String), "y north [m]");
            zg = mgv2.scene.heightAt(tc.W, 10, 20);
            tc.verifyEqual(r.Handles.stalk.ZData, [zg 25], 'AbsTol', 1e-12);
            tc.verifyEqual(r.Handles.shadow.Matrix(1:3,4)', [10 20 zg + 0.03], 'AbsTol', 1e-12);
            north = r.Handles.north; tc.verifyGreaterThan(max(north.YData) - min(north.YData), 2.9, 'north arrow points +y');
        end

        function s14_repeatedUpdatesStable(tc)
            r = tc.R; r.setCameraMode("chase"); n0 = r.graphicsCount(); T = tc.T;
            for k = 1:2:min(height(T), 2400), r.update(testV2003Scene.pose(T, k)); if mod(k, 100) == 1, drawnow limitrate; end, end
            drawnow;
            tc.verifyEqual(r.graphicsCount(), n0, 'no graphics objects created per update');
            tc.verifyEqual(numel(r.Handles.trail.XData), 600, 'trail length capped');
        end

        function s15_measuredPerformance(tc)
            r = tc.R; T = tc.T; ix = find(T.phase == "SURVEY"); ix = ix(1:2:min(numel(ix), 1200));
            for m = ["chase","follow","isometric"]
                r.setCameraMode(m); dt = zeros(numel(ix), 1);
                for i = 1:numel(ix), t0 = tic; r.update(testV2003Scene.pose(T, ix(i))); drawnow; dt(i) = toc(t0); end
                med = median(dt(5:end)); p95 = testV2003Scene.pct(dt(5:end), 95);
                tc.log(matlab.unittest.Verbosity.Terse, sprintf('PERF %s: %d frames, median %.1f ms, p95 %.1f ms, max %.1f ms (update+drawnow, visible figure)', ...
                    m, numel(dt), 1e3 * med, 1e3 * p95, 1e3 * max(dt)));
                tc.verifyLessThan(med, 0.1, sprintf('%s: median frame < 100 ms (>= 10 FPS target, AC-025 to be re-measured on Mac)', m));
            end
        end

        function s16_cleanupAndReinitialise(tc)
            before = numel(findall(groot, 'Type', 'figure'));
            for i = 1:3
                r = mgv2.scene.SceneRenderer(tc.W, Visible="off"); f = r.Figure; r.update(testV2003Scene.pose(tc.T, 100)); delete(r);
                tc.verifyFalse(isvalid(f), 'own figure deleted');
            end
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), before);
            f = figure('Visible', 'off'); ax = axes(f); tc.addTeardown(@() delete(f));
            r = mgv2.scene.SceneRenderer(tc.W, Parent=ax); r.update(testV2003Scene.pose(tc.T, 100)); delete(r);
            tc.verifyTrue(isvalid(f), 'a parent axes/figure supplied by the caller is not deleted');
            tc.verifyEqual(numel(ax.Children), 0, 'all renderer objects removed from the caller''s axes');
        end

        function s17_uavToolboxLidarSeesSameGeometry(tc)
            tc.assumeNotEmpty(which('uavLidarPointCloudGenerator'), 'UAV Toolbox not installed');
            w = tc.W; scene = mgv2.scene.toUavScenario(w, 10);
            xy = [12 -7]; zg = mgv2.scene.heightAt(w, xy(1), xy(2)); agl = 15;
            [pn, qn] = mgv2.frames.poseEnuToNed([xy zg + agl], [1 0 0 0]);
            plat = uavPlatform("v2", scene, "ReferenceFrame", "NED", "InitialPosition", pn, "InitialOrientation", qn);
            updateMesh(plat, "cuboid", {[0.01 0.01 0.01]}, [1 0 0], [0 0 0], [1 0 0 0]);   % negligible own body: no self-returns
            lid = uavLidarPointCloudGenerator("UpdateRate", 10, "MaxRange", 60, "RangeAccuracy", 1e-3, ...
                "AzimuthResolution", 1, "ElevationResolution", 1, "AzimuthLimits", [-180 180], "ElevationLimits", [60 90], "HasNoise", false);
            % verified convention: on a NED/FRD platform the sensor frame follows FRD, so +elevation points DOWN;
            % the sensor is mounted 5 cm below the (negligible) body so it never sees its own platform mesh
            sen = uavSensor("lidar", plat, lid, "MountingLocation", [0 0 0.05], "MountingAngles", [0 0 0]);
            setup(scene); updateSensors(scene); [~, ~, pc] = read(sen);
            L = reshape(pc.Location, [], 3); L = L(all(isfinite(L), 2), :);
            tc.assertNotEmpty(L);
            [~, i] = min(hypot(L(:,1), L(:,2)));
            tc.verifyEqual(abs(L(i,3)), agl - 0.05, 'AbsTol', 0.01, 'near-nadir LiDAR range = AGL (from heightAt, same triangles) minus the 5 cm mount');
            tc.verifyGreaterThan(size(L, 1), 1000, 'dense ground returns');
        end

        function s18_truthFirewallAndInputs(tc)
            tc.verifyFalse(any(contains(lower(string(fieldnames(tc.W))), ["target","truth","label","mine"])));
            tc.verifyFalse(any(contains(lower(tc.W.objects.Properties.VariableNames), ["target","truth","label","mine"])));
            c = mgv2.scene.defaultSceneConfig(); c.targets = [1 2];
            tc.verifyError(@() mgv2.scene.buildWorld(c), 'mgv2:InvalidSceneConfig');
            c = mgv2.scene.defaultSceneConfig('grid_spacing_m', 0.01); tc.verifyError(@() mgv2.scene.buildWorld(c), 'mgv2:InvalidSceneConfig');
            c = mgv2.scene.defaultSceneConfig('home_enu_m', [500 0]); tc.verifyError(@() mgv2.scene.buildWorld(c), 'mgv2:InvalidSceneConfig');
        end

        function s19_invalidPoseRejected(tc)
            r = tc.R; good = testV2003Scene.fixture([1 2 20], 0, 0, 0); r.update(good); M = r.Handles.aircraft.Matrix;
            bad = {rmfield(good, 'orientation_quat'), setfield(good, 'position_enu_m', [NaN 0 1]), ...
                setfield(good, 'orientation_quat', [2 0 0 0]), setfield(good, 't_s', Inf)}; %#ok<SFLD>
            for i = 1:numel(bad)
                tc.verifyError(@() r.update(bad{i}), 'mgv2:InvalidPose');
            end
            tc.verifyEqual(r.Handles.aircraft.Matrix, M, 'rejected poses leave the scene unchanged');
            good.phase = "RETURN_HOME"; r.update(good);
            tc.verifySubstring(char(r.Handles.hud.String), 'RETURN\_HOME', 'phase underscore escaped for the TeX HUD');
        end
    end
end
