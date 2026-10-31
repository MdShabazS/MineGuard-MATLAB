function runBundle = makeRunBundle(publicTrial, events, metadata)
%MAKERUNBUNDLE Redacted, view-only runBundle adapter for the MG-011 dashboard (MG-010 Section 2.2).
%   runBundle = mineguard.app.makeRunBundle(publicTrial, events, metadata)
%   publicTrial - ONLY the observable part of a run: struct with fields scenario_id, geometry,
%                 poses, samples (vertcat thermal+EM) and optionally coverage, route_enu_m.
%                 Passing a full trial (with .private/.hidden_truth) is rejected.
%   events      - MG-009 DetectionEvent table (12 columns; may be zero-row)
%   metadata    - struct with provenance (required) and optionally result (ExperimentResult),
%                 result_report (MG-009 report; only aggregate fields are copied),
%                 comparison, display_settings
%   ALLOWLIST adapter: only named fields are copied, so truth can never pass through. The
%   evaluator's match pairs (event/target indices) are deliberately dropped. Unknown provenance
%   fields become "NOT_RECORDED". The output is checked with validateRunBundle.
id = 'mineguard:InvalidRunBundle';
allowedPublic = ["scenario_id","geometry","poses","samples","coverage","route_enu_m"];
if ~isstruct(publicTrial) || ~isscalar(publicTrial) || ~isempty(setdiff(string(fieldnames(publicTrial))', allowedPublic))
    error(id, 'MineGuard app: publicTrial may contain only %s (never the private/truth part).', strjoin(allowedPublic, ', '));
end
if ~isstruct(metadata) || ~isfield(metadata, 'provenance')
    error(id, 'MineGuard app: metadata.provenance is required.');
end
S = publicTrial.samples;
runBundle = struct();
runBundle.schema_version = "mg-contract/1.0";
runBundle.scenario_id = string(publicTrial.scenario_id);
runBundle.geometry = publicTrial.geometry;
runBundle.poses = publicTrial.poses;
runBundle.thermal_samples = S(S.sensor_kind == "thermal", :);
runBundle.em_samples = S(S.sensor_kind == "em", :);
runBundle.events = events;
if isfield(publicTrial, 'route_enu_m'), runBundle.route_enu_m = publicTrial.route_enu_m; end
if isfield(publicTrial, 'coverage')
    c = publicTrial.coverage;
    runBundle.coverage = struct('coverage_fraction', c.coverage_fraction, 'visited_valid_cells', c.visited_valid_cells, ...
        'total_valid_cells', c.total_valid_cells, 'mission_time_s', c.mission_time_s, 'distance_m', c.distance_m, ...
        'source', "mineguard.navigation.computeCoverage (MG-005)");
end
provKeys = ["scenario_id","seed","noise_seed","model_version","sensor_settings_version","detector_model_version", ...
    "method_name","missing_modality_rule","threshold","matlab_release","git_sha","run_id","run_timestamp_utc", ...
    "toolbox_manifest","split_id","simulation_flags","source_note"];
p = metadata.provenance;
prov = struct();
for k = provKeys
    if isfield(p, k) && ~isempty(p.(k)), prov.(k) = p.(k); else, prov.(k) = "NOT_RECORDED"; end
end
runBundle.provenance = prov;
if isfield(metadata, 'result') && ~isempty(metadata.result)
    runBundle.result = metadata.result;
end
if isfield(metadata, 'result_report') && ~isempty(metadata.result_report)
    rr = metadata.result_report;
    keep = ["metric_unit","cell_size_m","total_legal_cell_count","evaluable_cell_count","excluded_cell_count", ...
        "denominators","specificity","valid_events","object_event_matches","unmatched_events","event_localization_error_m", ...
        "localization_match_radius_m"];
    agg = struct();
    for k = keep
        if isfield(rr, k), agg.(k) = rr.(k); end
    end
    runBundle.result_report = agg;
end
if isfield(metadata, 'comparison'), runBundle.comparison = metadata.comparison; end
if isfield(metadata, 'display_settings'), runBundle.display_settings = metadata.display_settings; end
mineguard.app.validateRunBundle(runBundle);
end
