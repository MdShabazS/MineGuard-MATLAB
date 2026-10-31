function [geometry, truth, environment] = generateScenario(config)
%GENERATESCENARIO Generate a seeded synthetic survey scenario (mg-contract/1.0, MG-004).
%   [geometry, truth, environment] = mineguard.scenario.generateScenario(config)
%
%   config      - ExperimentConfig struct (see docs/MG003_INTERFACE_FREEZE.md).
%                 An optional field exclusion_polygons_enu_m (cell of Nx2) may be
%                 supplied. Objects are never placed inside these polygons.
%   geometry    - ScenarioGeometry. Safe to share with the planner and plots, because it
%                 contains no targets, labels, counts or object coordinates.
%   truth       - TargetTruth table. RESTRICTED: only forward physics and the evaluator
%                 may use it. With zero objects it is a typed zero-row table.
%   environment - Soil and terrain description, plus model-parameter PLACEHOLDERS with units.
%                 None of the parameters are calibrated physical constants.
%
%   Determinism: uses a local RandStream('mt19937ar', Seed=config.seed). The global
%   RNG is never read or changed, so the same config gives bitwise-equal outputs.
%   Placement: uniform rejection sampling with a minimum-separation rule. A packing
%   capacity precheck and a fixed attempt budget mean an impossible request fails
%   with mineguard:InvalidScenario instead of looping forever.
%
%   SIMULATION ONLY. Objects are synthetic surrogates, not real mines or real sites.

config = validateConfig(config);

bounds = [config.x_min_m config.x_max_m config.y_min_m config.y_max_m];
exclusions = {};
if isfield(config, 'exclusion_polygons_enu_m')
    exclusions = reshape(config.exclusion_polygons_enu_m, 1, []);
end

nTarget = config.target_count;
nClutter = config.clutter_count;
nTotal = nTarget + nClutter;
sep = config.min_separation_m;
maxObjects = 10000;
if nTotal > maxObjects
    invalidScenario('target_count + clutter_count = %d exceeds the supported maximum of %d.', nTotal, maxObjects);
end

% Capacity precheck: hexagonal packing of disks with diameter sep in the bounds
% enlarged by sep/2 on every side. This is an upper bound on what can be placed.
width = bounds(2) - bounds(1);
height = bounds(4) - bounds(3);
if sep > 0 && nTotal > 0
    capacity = floor((width + sep) * (height + sep) * 2 / (sqrt(3) * sep^2));
    if nTotal > capacity
        invalidScenario(['cannot place %d objects with min_separation_m = %g in a %g x %g m field ' ...
            '(packing upper bound %d). Reduce counts or separation, or enlarge the bounds.'], ...
            nTotal, sep, width, height, capacity);
    end
end

stream = RandStream('mt19937ar', 'Seed', config.seed);

% Rejection sampling with a bounded attempt budget.
attemptsPerObject = 2000;
maxAttempts = attemptsPerObject * max(nTotal, 1);
xy = zeros(nTotal, 2);
placed = 0;
attempts = 0;
while placed < nTotal
    if attempts >= maxAttempts
        invalidScenario(['placement failed: only %d of %d objects placed after %d attempts ' ...
            '(min_separation_m = %g). Reduce counts or separation.'], placed, nTotal, attempts, sep);
    end
    attempts = attempts + 1;
    candidate = [bounds(1) + width * rand(stream), bounds(3) + height * rand(stream)];
    if placed > 0 && sep > 0
        d2 = sum((xy(1:placed,:) - candidate).^2, 2);
        if any(d2 < sep^2)
            continue
        end
    end
    if insideAny(candidate, exclusions)
        continue
    end
    placed = placed + 1;
    xy(placed,:) = candidate;
end

% Object attributes. These are illustrative synthetic placeholders, not measured values.
truth = truthTemplate(nTotal);
isTarget = [true(nTarget,1); false(nClutter,1)];
order = randperm(stream, nTotal);   % mix the order of targets and clutter
isTarget = isTarget(order);
clutterMaterials = ["synthetic_metal_debris" "synthetic_rock" "synthetic_root"];
for k = 1:nTotal
    truth.target_id(k) = sprintf("OBJ-%04d", k);
    truth.x_east_m(k) = xy(k,1);
    truth.y_north_m(k) = xy(k,2);
    if isTarget(k)
        truth.burial_depth_m(k) = 0.05 + 0.15 * rand(stream);   % 0.05..0.20 m
        truth.material_type(k) = "synthetic_cased_surrogate";
        truth.label(k) = "target";
    else
        truth.burial_depth_m(k) = 0.10 * rand(stream);          % 0..0.10 m
        truth.material_type(k) = clutterMaterials(randi(stream, numel(clutterMaterials)));
        truth.label(k) = "clutter";
    end
end
truth.soil_class(:) = config.soil_class;
truth.surface_exposed = truth.burial_depth_m == 0;

geometry = struct( ...
    'schema_version', config.schema_version, ...
    'scenario_id', config.scenario_id, ...
    'bounds_enu_m', bounds, ...
    'terrain_id', config.terrain_id, ...
    'terrain_model', struct('type', "flat", 'datum_height_m', 0, ...
        'description', "Flat synthetic datum at z_up_m = 0 (test fixture)."), ...
    'exclusion_polygons_enu_m', {exclusions});

placeholder = @(units, desc) struct('value', NaN, 'units', string(units), ...
    'status', "PLACEHOLDER_NOT_CALIBRATED", 'description', string(desc));
environment = struct( ...
    'schema_version', config.schema_version, ...
    'scenario_id', config.scenario_id, ...
    'soil_class', config.soil_class, ...
    'terrain_id', config.terrain_id, ...
    'datum_height_m', 0, ...
    'rng', struct('algorithm', "mt19937ar", 'scenario_seed', config.seed, ...
        'noise_seed', config.noise_seed, ...
        'thermal_seed', deriveSeed(config.noise_seed, 1), ...
        'em_seed', deriveSeed(config.noise_seed, 2), ...
        'navigation_seed', deriveSeed(config.noise_seed, 3), ...
        'derivation', "mod(noise_seed + k*1000003, 2^32), k = 1 thermal, 2 em, 3 navigation"), ...
    'thermal', struct( ...
        'ambient_temperature_K', placeholder('K', 'Ambient surface temperature, set by MG-006/MG-007'), ...
        'soil_thermal_diffusivity_m2_per_s', placeholder('m^2/s', 'Soil thermal diffusivity')), ...
    'em', struct( ...
        'soil_conductivity_S_per_m', placeholder('S/m', 'Soil electrical conductivity'), ...
        'soil_relative_permittivity', placeholder('1', 'Soil relative permittivity (dimensionless)')), ...
    'model_version', config.model_version, ...
    'notes', "Synthetic simulation scenario. Parameters are placeholders; no physical calibration is claimed.");
end

function s = deriveSeed(noiseSeed, k)
s = mod(noiseSeed + k * 1000003, 2^32);
end

function tf = insideAny(p, polys)
tf = false;
for k = 1:numel(polys)
    if inpolygon(p(1), p(2), polys{k}(:,1), polys{k}(:,2))
        tf = true;
        return
    end
end
end
