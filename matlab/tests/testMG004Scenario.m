classdef testMG004Scenario < matlab.unittest.TestCase
    %TESTMG004SCENARIO MG-004 contract tests C-01..C-05 and C-07 (mg-contract/1.0).
    %   Run from the repository root:
    %     addpath('matlab'); results = runtests('matlab/tests/testMG004Scenario.m')
    %   SIMULATION ONLY. These tests check software contracts, not mine detection.

    methods (TestClassSetup)
        function addSourcePath(tc)
            src = fullfile(fileparts(fileparts(mfilename('fullpath'))));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(src));
        end
    end

    methods (Static)
        function c = fixture()
            % Default academic test fixture from MG003_INTERFACE_FREEZE Section 4 (test only).
            c = struct('schema_version', "mg-contract/1.0", 'scenario_id', "S0-seed42", ...
                'seed', 42, 'x_min_m', 0, 'x_max_m', 20, 'y_min_m', 0, 'y_max_m', 20, ...
                'terrain_id', "flat-datum", 'grid_spacing_m', 1, 'dt_s', 0.1, ...
                'sampling_hz', 10, 'altitude_m', 2, 'speed_mps', 1, 'noise_seed', 7, ...
                'target_count', 1, 'clutter_count', 1, 'min_separation_m', 0.5, ...
                'soil_class', "synthetic_loam", 'model_version', "mg004-0.1");
        end
    end

    methods (Test)
        % ---------------- C-01: config rejection ----------------
        function c01_rejectsInvalidConfig(tc)
            base = testMG004Scenario.fixture();
            cases = { ...
                'seed NaN',            @(c) setf(c,'seed',NaN); ...
                'seed Inf',            @(c) setf(c,'seed',Inf); ...
                'seed negative',       @(c) setf(c,'seed',-1); ...
                'seed non-integer',    @(c) setf(c,'seed',1.5); ...
                'x bounds inverted',   @(c) setf(setf(c,'x_min_m',20),'x_max_m',0); ...
                'x bounds zero width', @(c) setf(c,'x_max_m',0); ...
                'y bounds inverted',   @(c) setf(setf(c,'y_min_m',5),'y_max_m',1); ...
                'x_max Inf',           @(c) setf(c,'x_max_m',Inf); ...
                'y_min NaN',           @(c) setf(c,'y_min_m',NaN); ...
                'target_count neg',    @(c) setf(c,'target_count',-1); ...
                'target_count frac',   @(c) setf(c,'target_count',1.5); ...
                'clutter_count NaN',   @(c) setf(c,'clutter_count',NaN); ...
                'grid_spacing zero',   @(c) setf(c,'grid_spacing_m',0); ...
                'min_sep negative',    @(c) setf(c,'min_separation_m',-0.1); ...
                'schema wrong',        @(c) setf(c,'schema_version',"mg-contract/0.9"); ...
                'scenario_id empty',   @(c) setf(c,'scenario_id',""); ...
                'missing field',       @(c) rmfield(c,'soil_class'); ...
                'exclusion not cell',  @(c) setf(c,'exclusion_polygons_enu_m',[1 2; 3 4; 5 6]); ...
                'exclusion 2 vertices',@(c) setf(c,'exclusion_polygons_enu_m',{[1 1; 2 2]}); ...
                'exclusion NaN',       @(c) setf(c,'exclusion_polygons_enu_m',{[1 1; 2 NaN; 3 1]}); ...
                'exclusion outside',   @(c) setf(c,'exclusion_polygons_enu_m',{[1 1; 30 1; 1 5]})};
            for k = 1:size(cases,1)
                bad = cases{k,2}(base);
                tc.verifyError(@() mineguard.scenario.generateScenario(bad), ...
                    'mineguard:InvalidScenario', cases{k,1});
            end
            % Error messages name the offending field (actionable).
            try
                mineguard.scenario.generateScenario(setf(base,'seed',-1));
                tc.verifyFail('expected error');
            catch e
                tc.verifySubstring(e.message, 'config.seed');
            end
            % Malformed geometry exclusions are rejected by validateScenario.
            [g, t] = mineguard.scenario.generateScenario(base);
            g.exclusion_polygons_enu_m = {[0 0; 1 1]};
            tc.verifyError(@() mineguard.scenario.validateScenario(base, g, t), 'mineguard:InvalidScenario');
        end

        % ---------------- C-02: determinism ----------------
        function c02_sameSeedIsBitwiseEqual(tc)
            c = testMG004Scenario.fixture();
            c.target_count = 5; c.clutter_count = 7;
            globalBefore = rng;
            [g1, t1, e1] = mineguard.scenario.generateScenario(c);
            [g2, t2, e2] = mineguard.scenario.generateScenario(c);
            tc.verifyTrue(isequal(g1, g2), 'geometry differs');
            tc.verifyTrue(isequal(t1, t2), 'truth differs');
            tc.verifyTrue(isequaln(e1, e2), 'environment differs'); % isequaln: placeholders are NaN
            tc.verifyEqual(rng, globalBefore, 'global RNG state was modified');
            % Different seeds give different layouts (statistical check over a sample set).
            layouts = zeros(10, 2*height(t1));
            for s = 1:10
                c.seed = s;
                [~, t] = mineguard.scenario.generateScenario(c);
                layouts(s,:) = [t.x_east_m' t.y_north_m'];
            end
            tc.verifyEqual(size(unique(layouts,'rows'),1), 10, 'seeds 1..10 should give distinct layouts');
        end

        % ---------------- C-03: geometry ----------------
        function c03_coordinatesInBoundsAndUniqueIds(tc)
            c = testMG004Scenario.fixture();
            for s = [0 1 42 999 2^32-1]
                c.seed = s; c.target_count = 20; c.clutter_count = 30; c.min_separation_m = 1;
                [g, t] = mineguard.scenario.generateScenario(c);
                b = g.bounds_enu_m;
                tc.verifyTrue(all(isfinite([t.x_east_m; t.y_north_m; t.burial_depth_m])));
                tc.verifyTrue(all(t.x_east_m >= b(1) & t.x_east_m <= b(2)));
                tc.verifyTrue(all(t.y_north_m >= b(3) & t.y_north_m <= b(4)));
                tc.verifyTrue(all(t.burial_depth_m >= 0));
                tc.verifyEqual(numel(unique(t.target_id)), height(t));
                tc.verifyEqual(nnz(t.label=="target"), 20);
                tc.verifyEqual(nnz(t.label=="clutter"), 30);
                d = pdist2local([t.x_east_m t.y_north_m]);
                tc.verifyGreaterThanOrEqual(min(d), 1 - 1e-9);
                mineguard.scenario.validateScenario(c, g, t);   % must not throw
            end
            % Exclusion zones are respected.
            c.seed = 3; c.exclusion_polygons_enu_m = {[0 0; 10 0; 10 10; 0 10]};
            [g, t] = mineguard.scenario.generateScenario(c);
            tc.verifyFalse(any(inpolygon(t.x_east_m, t.y_north_m, [0 10 10 0], [0 0 10 10])));
            mineguard.scenario.validateScenario(c, g, t);
            % Duplicate IDs and out-of-bounds truth are rejected.
            t2 = t; t2.target_id(2) = t2.target_id(1);
            tc.verifyError(@() mineguard.scenario.validateScenario(c, g, t2), 'mineguard:InvalidScenario');
            t3 = t; t3.x_east_m(1) = 25;
            tc.verifyError(@() mineguard.scenario.validateScenario(c, g, t3), 'mineguard:InvalidScenario');
            t4 = t; t4.x_east_m(2) = t4.x_east_m(1) + 0.1; t4.y_north_m(2) = t4.y_north_m(1);
            tc.verifyError(@() mineguard.scenario.validateScenario(c, g, t4), 'mineguard:InvalidScenario');
        end

        % ---------------- C-04: empty field ----------------
        function c04_emptyFieldTypedZeroRowTruth(tc)
            c = testMG004Scenario.fixture();
            c.target_count = 0; c.clutter_count = 0;
            [g, t, e] = mineguard.scenario.generateScenario(c);
            tc.verifyClass(t, 'table');
            tc.verifyEqual(height(t), 0);
            tc.verifyEqual(string(t.Properties.VariableNames), ["target_id","x_east_m","y_north_m", ...
                "burial_depth_m","material_type","label","soil_class","surface_exposed"]);
            tc.verifyClass(t.target_id, 'string');
            tc.verifyClass(t.x_east_m, 'double');
            tc.verifyClass(t.label, 'categorical');
            tc.verifyClass(t.surface_exposed, 'logical');
            mineguard.scenario.validateScenario(c, g, t);       % must not throw
            % Typical downstream operations must not crash on the empty table.
            tc.verifyEqual(height(t(t.label=="target",:)), 0);
            tc.verifyEqual(nnz(t.burial_depth_m > 0.1), 0);
            tc.verifyNotEmpty(jsonencode(g));
            tc.verifyTrue(isstruct(e));
        end

        % ---------------- C-05: truth firewall ----------------
        function c05_geometryCarriesNoTruth(tc)
            c = testMG004Scenario.fixture();
            c.target_count = 4; c.clutter_count = 3;
            [g, t] = mineguard.scenario.generateScenario(c);
            tc.verifyEqual(sort(string(fieldnames(g)))', sort(["schema_version","scenario_id", ...
                "bounds_enu_m","terrain_id","terrain_model","exclusion_polygons_enu_m"]));
            json = jsonencode(g);
            for bad = ["hidden_truth","TargetTruth","label","target_count","clutter_count", ...
                       "target_id","x_east_m","y_north_m","burial_depth_m","OBJ-"]
                tc.verifyFalse(contains(json, bad), "geometry JSON leaks " + bad);
            end
            % No object coordinate appears anywhere in the serialised geometry.
            for k = 1:height(t)
                tc.verifyFalse(contains(json, sprintf('%.6g', t.x_east_m(k))), 'object x leaked');
            end
            % validateScenario rejects geometry with smuggled truth.
            g2 = g; g2.hidden_truth = t;
            tc.verifyError(@() mineguard.scenario.validateScenario(c, g2, t), 'mineguard:InvalidScenario');
            g3 = g; g3.terrain_model.label = "target";
            tc.verifyError(@() mineguard.scenario.validateScenario(c, g3, t), 'mineguard:InvalidScenario');
            % Navigation APIs (MG-005) are not built yet, so the signature part of C-05
            % is checked when they are introduced. Confirm here that they do not exist yet.
            tc.verifyEmpty(which('mineguard.navigation.makeGridRoute'));
        end

        % ---------------- C-07: impossible placement ----------------
        function c07_overcrowdingFailsFastAndBounded(tc)
            c = testMG004Scenario.fixture();
            c.x_max_m = 2; c.y_max_m = 2; c.min_separation_m = 1;
            c.target_count = 50; c.clutter_count = 50;    % far above packing capacity
            t0 = tic;
            tc.verifyError(@() mineguard.scenario.generateScenario(c), 'mineguard:InvalidScenario');
            tc.verifyLessThan(toc(t0), 5, 'capacity precheck should fail quickly');
            % Near capacity: passes the precheck, but random placement cannot succeed.
            % It must stop at the attempt budget, not hang.
            c.target_count = 8; c.clutter_count = 0;      % hex bound is 10 for 2x2 m, 1 m sep
            t0 = tic;
            try
                [g, t] = mineguard.scenario.generateScenario(c);
                mineguard.scenario.validateScenario(c, g, t);   % if placed, it must be valid
            catch e
                tc.verifyEqual(e.identifier, 'mineguard:InvalidScenario');
                tc.verifySubstring(e.message, 'attempts');
            end
            tc.verifyLessThan(toc(t0), 30, 'bounded attempt budget exceeded time limit');
        end
    end
end

function c = setf(c, f, v)
c.(f) = v;
end

function d = pdist2local(xy)
n = size(xy,1); d = inf;
for i = 1:n-1
    d = min(d, min(sqrt(sum((xy(i+1:end,:) - xy(i,:)).^2, 2))));
end
end
