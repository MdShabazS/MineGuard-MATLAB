function validateScenario(config, geometry, truth)
%VALIDATESCENARIO Check a generated scenario against mg-contract/1.0 (MG-004).
%   mineguard.scenario.validateScenario(config, geometry, truth)
%   Throws mineguard:InvalidScenario when the bounds, seed, IDs, geometry, truth
%   columns or types, object overlap, or ground-truth firewall are invalid.
%   Returns nothing on success.

config = validateConfig(config);
bounds = [config.x_min_m config.x_max_m config.y_min_m config.y_max_m];

% ScenarioGeometry: exact field set, which is also the ground-truth firewall.
allowed = ["schema_version","scenario_id","bounds_enu_m","terrain_id","terrain_model","exclusion_polygons_enu_m"];
if ~isstruct(geometry) || ~isscalar(geometry)
    invalidScenario('geometry must be a scalar ScenarioGeometry struct.');
end
names = string(fieldnames(geometry))';
if ~isempty(setdiff(allowed, names))
    invalidScenario('geometry is missing field(s): %s.', strjoin(setdiff(allowed, names), ', '));
end
extra = setdiff(names, allowed);
if ~isempty(extra)
    invalidScenario('geometry has non-contract field(s) %s; it must not carry truth, labels, counts or object coordinates.', strjoin(extra, ', '));
end
forbidden = ["hidden_truth","TargetTruth","truth","label","target_count","clutter_count", ...
    "target_id","x_east_m","y_north_m","burial_depth_m","material_type"];
leaked = intersect(nestedFieldNames(geometry.terrain_model), forbidden);
if ~isempty(leaked)
    invalidScenario('geometry.terrain_model leaks truth field(s): %s.', strjoin(leaked, ', '));
end
if string(geometry.schema_version) ~= config.schema_version
    invalidScenario('geometry.schema_version does not match config.schema_version.');
end
if string(geometry.scenario_id) ~= config.scenario_id
    invalidScenario('geometry.scenario_id "%s" does not match config.scenario_id "%s".', string(geometry.scenario_id), config.scenario_id);
end
if ~(isnumeric(geometry.bounds_enu_m) && isequal(size(geometry.bounds_enu_m), [1 4]) && isequal(double(geometry.bounds_enu_m), bounds))
    invalidScenario('geometry.bounds_enu_m must be the 1x4 [x_min x_max y_min y_max] taken from config.');
end
if string(geometry.terrain_id) ~= config.terrain_id
    invalidScenario('geometry.terrain_id does not match config.terrain_id.');
end
if ~isstruct(geometry.terrain_model)
    invalidScenario('geometry.terrain_model must be a struct.');
end
checkExclusions(geometry.exclusion_polygons_enu_m, bounds, 'geometry.exclusion_polygons_enu_m');

% TargetTruth: columns, types, values.
template = truthTemplate(0);
if ~istable(truth)
    invalidScenario('truth must be a TargetTruth table.');
end
need = string(template.Properties.VariableNames);
have = string(truth.Properties.VariableNames);
if ~isempty(setdiff(need, have))
    invalidScenario('truth is missing column(s): %s.', strjoin(setdiff(need, have), ', '));
end
if ~isstring(truth.target_id) || any(ismissing(truth.target_id)) || any(strlength(truth.target_id) == 0)
    invalidScenario('truth.target_id must be nonempty strings.');
end
if numel(unique(truth.target_id)) ~= height(truth)
    invalidScenario('truth.target_id values must be unique.');
end
for c = ["x_east_m","y_north_m","burial_depth_m"]
    v = truth.(c);
    if ~(isa(v,'double') && isreal(v)) || any(~isfinite(v))
        invalidScenario('truth.%s must be finite real doubles.', c);
    end
end
if any(truth.x_east_m < bounds(1) | truth.x_east_m > bounds(2) | truth.y_north_m < bounds(3) | truth.y_north_m > bounds(4))
    invalidScenario('truth contains coordinates outside bounds_enu_m [%g %g %g %g].', bounds(1), bounds(2), bounds(3), bounds(4));
end
if any(truth.burial_depth_m < 0)
    invalidScenario('truth.burial_depth_m must be nonnegative.');
end
if ~isstring(truth.material_type) || ~isstring(truth.soil_class)
    invalidScenario('truth.material_type and truth.soil_class must be string columns.');
end
if ~iscategorical(truth.label) || any(isundefined(truth.label)) || ~all(ismember(string(truth.label), ["target","clutter"]))
    invalidScenario('truth.label must be categorical with values target or clutter.');
end
if ~islogical(truth.surface_exposed)
    invalidScenario('truth.surface_exposed must be logical.');
end
nT = nnz(truth.label == "target");
nC = nnz(truth.label == "clutter");
if nT ~= config.target_count || nC ~= config.clutter_count
    invalidScenario('truth has %d target(s) and %d clutter object(s); config requests %d and %d.', nT, nC, config.target_count, config.clutter_count);
end

% Minimum separation, with a small numerical tolerance.
sep = config.min_separation_m;
if sep > 0 && height(truth) > 1
    xy = [truth.x_east_m truth.y_north_m];
    for i = 1:height(truth)-1
        d = sqrt(sum((xy(i+1:end,:) - xy(i,:)).^2, 2));
        j = find(d < sep - 1e-9, 1);
        if ~isempty(j)
            invalidScenario('objects %s and %s overlap: separation %.4g m < min_separation_m %g.', truth.target_id(i), truth.target_id(i+j), d(j), sep);
        end
    end
end

% Objects must not lie inside exclusion polygons.
polys = geometry.exclusion_polygons_enu_m;
for k = 1:numel(polys)
    in = inpolygon(truth.x_east_m, truth.y_north_m, polys{k}(:,1), polys{k}(:,2));
    if any(in)
        invalidScenario('truth object %s lies inside exclusion polygon %d.', truth.target_id(find(in,1)), k);
    end
end
end

function names = nestedFieldNames(s)
names = strings(1,0);
if ~isstruct(s), return; end
f = string(fieldnames(s))';
names = f;
for k = 1:numel(f)
    v = s(1).(f(k));
    if isstruct(v)
        names = [names nestedFieldNames(v)]; %#ok<AGROW>
    end
end
end
