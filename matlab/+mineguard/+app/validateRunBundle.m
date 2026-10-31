function validateRunBundle(rb)
%VALIDATERUNBUNDLE Strict schema, identity and privacy validation of a redacted runBundle (MG-011).
%   mineguard.app.validateRunBundle(runBundle)   throws mineguard:InvalidRunBundle with a reason.
%   - Top-level fields are ALLOWLISTED. A restricted wrapper (config, environment, hidden_truth,
%     private, ...) is rejected.
%   - A recursive scan of every nested struct and cell rejects truth field names (the MG-003
%     firewall list), and tables anywhere other than the four typed contract slots.
%   - The typed tables must have the exact contract columns: PoseSample (required core columns),
%     SensorSample (11), DetectionEvent (12). A TargetTruth table therefore cannot hide in any slot.
%   - Identity: schema "mg-contract/1.0"; the scenario_id must match geometry and provenance.
%   - Pose IDs are unique, t_s is finite and nondecreasing, and ENU positions are finite.
%   - Sample IDs are unique, sensor_kind matches its table, every pose reference exists, and each
%     sample time equals its pose time (1e-9 s). Invalid samples are NaN in the active channel
%     with a reason; units are channel-separated.
%   - Events: status is only "SUSPECTED"; any thermal/EM sample reference exists or is empty; t_s is finite.
%   - The optional result has exactly the 21 frozen ExperimentResult fields, with a matching scenario_id.
%   - The optional comparison table must pass validateComparisonTable, which enforces the EXACT public
%     metric allowlist (MG-019 review correction).
id = 'mineguard:InvalidRunBundle';
if ~isstruct(rb) || ~isscalar(rb)
    error(id, 'Invalid run bundle: runBundle must be a scalar struct.');
end
required = ["schema_version","scenario_id","geometry","poses","thermal_samples","em_samples","events","provenance"];
optional = ["result","result_report","comparison","display_settings","coverage","route_enu_m"];
names = string(fieldnames(rb))';
if ~isempty(setdiff(required, names))
    error(id, 'Invalid run bundle: missing required field(s) %s.', strjoin(setdiff(required, names), ', '));
end
if ~isempty(setdiff(names, [required optional]))
    error(id, 'Invalid run bundle: non-allowlisted field(s) %s (restricted/truth wrappers are not accepted).', ...
        strjoin(setdiff(names, [required optional]), ', '));
end
if string(rb.schema_version) ~= "mg-contract/1.0"
    error(id, 'Invalid run bundle: schema_version must be "mg-contract/1.0".');
end
sid = string(rb.scenario_id);
forbidden = setdiff(mineguard.contract.truthFieldNames(), ["x_east_m","y_north_m"]);
forbidden = [forbidden "environment" "config" "private" "Scenario"];
for f = setdiff(names, ["poses","thermal_samples","em_samples","events","comparison"])
    leak = scan(rb.(f), f, forbidden);
    if strlength(leak) > 0
        error(id, 'Invalid run bundle: restricted content at %s (truth must never reach the dashboard).', leak);
    end
end
if isfield(rb, 'comparison')
    % Exact public allowlist (mineguard.contract.comparisonColumns); not a denylist.
    try
        mineguard.app.validateComparisonTable(rb.comparison);
    catch cerr
        error(id, 'Invalid run bundle: %s', cerr.message);
    end
end
g = rb.geometry;
if ~isstruct(g) || ~isfield(g, 'scenario_id') || string(g.scenario_id) ~= sid || ~isfield(g, 'bounds_enu_m')
    error(id, 'Invalid run bundle: geometry scenario_id does not match "%s".', sid);
end
if ~isfield(rb.provenance, 'scenario_id') || string(rb.provenance.scenario_id) ~= sid
    error(id, 'Invalid run bundle: provenance scenario_id does not match "%s".', sid);
end

P = rb.poses;
pc = {'pose_sample_id','t_s','x_east_m','y_north_m','z_up_m'};
if ~istable(P) || ~all(ismember(pc, P.Properties.VariableNames))
    error(id, 'Invalid run bundle: poses must be a PoseSample table with %s.', strjoin(pc, ', '));
end
extraPose = setdiff(string(P.Properties.VariableNames), ["pose_sample_id","t_s","x_east_m","y_north_m","z_up_m", ...
    "roll_rad","pitch_rad","yaw_rad","virtual_lat_deg","virtual_lon_deg","gps_sigma_m","waypoint_id","mission_state"]);
if ~isempty(extraPose)
    error(id, 'Invalid run bundle: poses has non-PoseSample column(s) %s.', strjoin(extraPose, ', '));
end
pid = string(P.pose_sample_id);
if numel(unique(pid)) ~= height(P) || any(strlength(pid) == 0)
    error(id, 'Invalid run bundle: duplicate or empty pose_sample_id.');
end
if any(~isfinite(P.t_s)) || any(diff(P.t_s) < 0)
    error(id, 'Invalid run bundle: pose t_s must be finite and nondecreasing.');
end
if any(~isfinite([P.x_east_m; P.y_north_m; P.z_up_m]))
    error(id, 'Invalid run bundle: pose ENU positions must be finite.');
end
sc = ["sample_id","pose_sample_id","t_s","sensor_kind","temperature_K","response_norm","noise_sigma", ...
    "standoff_m","footprint_radius_m","valid","invalid_reason"];
allIds = strings(0,1);
for kind = ["thermal","em"]
    S = rb.(kind + "_samples");
    if ~istable(S) || ~isequal(string(S.Properties.VariableNames), sc)
        error(id, 'Invalid run bundle: %s_samples must be a SensorSample table with exactly the 11 contract columns.', kind);
    end
    if any(string(S.sensor_kind) ~= kind)
        error(id, 'Invalid run bundle: %s_samples contains a row with a different sensor_kind.', kind);
    end
    [ok, row] = ismember(string(S.pose_sample_id), pid);
    if ~all(ok)
        error(id, 'Invalid run bundle: %s sample references an unknown pose_sample_id.', kind);
    end
    if any(abs(S.t_s - P.t_s(row)) > 1e-9)
        error(id, 'Invalid run bundle: %s sample t_s disagrees with its pose time.', kind);
    end
    active = S.temperature_K; other = S.response_norm;
    if kind == "em", active = S.response_norm; other = S.temperature_K; end
    if any(~isnan(other)) || any(~isnan(active(~S.valid))) || any(~isfinite(active(S.valid))) || ...
            any(strlength(S.invalid_reason(~S.valid)) == 0)
        error(id, 'Invalid run bundle: %s channel/unit or invalid-reading convention violated.', kind);
    end
    allIds = [allIds; string(S.sample_id)]; %#ok<AGROW>
end
if numel(unique(allIds)) ~= numel(allIds)
    error(id, 'Invalid run bundle: duplicate sample_id across sensor tables.');
end
E = rb.events;
ec = ["event_id","t_s","x_est_m","y_est_m","confidence_0_1","uncertainty_m","thermal_sample_id","em_sample_id", ...
    "method_name","threshold","status","valid"];
if ~istable(E) || ~isequal(string(E.Properties.VariableNames), ec)
    error(id, 'Invalid run bundle: events must be a DetectionEvent table with exactly the 12 contract columns.');
end
if any(string(E.status) ~= "SUSPECTED")
    error(id, 'Invalid run bundle: only SUSPECTED events may be displayed.');
end
if numel(unique(string(E.event_id))) ~= height(E) || any(~isfinite(E.t_s))
    error(id, 'Invalid run bundle: duplicate event_id or non-finite event time.');
end
refT = string(E.thermal_sample_id); refE = string(E.em_sample_id);
if any(refT ~= "" & ~ismember(refT, string(rb.thermal_samples.sample_id))) || any(refE ~= "" & ~ismember(refE, string(rb.em_samples.sample_id)))
    error(id, 'Invalid run bundle: event references a sample that is not in the bundle.');
end
if isfield(rb, 'result')
    frozen = ["schema_version","scenario_id","seed","algorithm","coverage_fraction","mission_time_s","distance_m", ...
        "tp","fp","tn","fn","precision","recall","f1","false_alarm_rate","localization_error_m","matlab_release", ...
        "toolbox_manifest","git_sha","split_id","scenario_seed"];
    if ~isstruct(rb.result) || ~isequal(string(fieldnames(rb.result))', frozen) || string(rb.result.scenario_id) ~= sid
        error(id, 'Invalid run bundle: result must be the frozen 21-field ExperimentResult for this scenario.');
    end
end
end

function leak = scan(v, path, forbidden)
leak = "";
if istable(v)
    leak = path + " (table)"; return
end
if iscell(v)
    for i = 1:numel(v)
        leak = scan(v{i}, path + "{" + i + "}", forbidden); if strlength(leak) > 0, return; end
    end
    return
end
if ~isstruct(v), return; end
f = string(fieldnames(v))';
bad = intersect(f, forbidden);
if ~isempty(bad), leak = path + "." + bad(1); return; end
for k = 1:numel(f)
    for i = 1:numel(v)
        leak = scan(v(i).(f(k)), path + "." + f(k), forbidden); if strlength(leak) > 0, return; end
    end
end
end
