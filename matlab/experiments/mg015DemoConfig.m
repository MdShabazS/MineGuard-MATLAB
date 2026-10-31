function c = mg015DemoConfig(name)
%MG015DEMOCONFIG Configs for the one-command demo (MG-015).
%   c = mg015DemoConfig("S0")      safe S0 demonstration fixture: 10x10 m, 0.5 m cells, 0.3 m altitude,
%                                  seed 3001 / noise 53001 (the MG-009 TEST family MG009-3001, already
%                                  inspected; display only, no tuning). Frozen MG-009 detector.
%   c = mg015DemoConfig("GF-0xx")  an MG-014 locked TRAIN or VALIDATION family with the MG014-RUNLOCK-1
%                                  detector. Sealed TEST families GF-025..030 are refused here.
name = string(name);
if name == "S0"
    c = struct('schema_version', "mg-contract/1.0", 'scenario_id', "MG015-DEMO-S0", 'seed', 3001, 'x_min_m', 0, 'x_max_m', 10, ...
        'y_min_m', 0, 'y_max_m', 10, 'terrain_id', "flat-datum", 'grid_spacing_m', 0.5, 'dt_s', 0.1, 'sampling_hz', 10, ...
        'altitude_m', 0.3, 'speed_mps', 2, 'noise_seed', 53001, 'target_count', 1, 'clutter_count', 3, ...
        'min_separation_m', 0.5, 'soil_class', "synthetic_loam", 'model_version', "mg015-demo-S0");
    c.sensor_settings = mg007FixtureSettings();
    c.detector_settings = mg015DetectorSettings("MG009");
    c.run_options = struct('split_id', "test", 'group_id', "MG015-DEMO-S0 (=MG009-3001 layout)", 'evaluate', true);
elseif startsWith(name, "GF-")
    [c, row] = mg015GroupConfig(name, mg015DetectorSettings("RUNLOCK"));
    if string(row.split_id) == "test"
        error('mineguard:SealedTest', '%s is a sealed TEST family; the demo never opens TEST (use runMG015Locked("heldout", ...) after run-lock review).', name);
    end
else
    error('mineguard:InvalidExperimentConfig', 'Unknown demo config "%s".', name);
end
end
