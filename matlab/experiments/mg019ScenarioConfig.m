function c = mg019ScenarioConfig(seed, set)
%MG019SCENARIOCONFIG Config for one preregistered MG019-SPLIT-1 scenario (experiments/mg019/mg019_scenario_manifest.json).
%   c = mg019ScenarioConfig(seed)                  evaluation set ("MG019-<seed>", split "test")
%   c = mg019ScenarioConfig(seed, "replication")   MG-013 TEST replication ("MG019-REPL-<seed>", split "test")
%   The geometry and no-fly zones come from mg013ScenarioConfig(seed) (unchanged). Synthetic objects
%   are target_count = 1 + mod(seed,2) and clutter_count = mod(seed,3); these reach only the generator.
%   Sensors: mg007FixtureSettings. Detector: the frozen MG014-RUNLOCK-1 model (2 m altitude),
%   weighted / single_valid.
if nargin < 2, set = "evaluation"; end
if string(set) == "replication", id = "MG019-REPL-" + seed; else, id = "MG019-" + seed; end
c = mg013ScenarioConfig(seed, id);
c.target_count = 1 + mod(seed, 2);
c.clutter_count = mod(seed, 3);
c.model_version = "mg019-scenario-1.0";
c.sensor_settings = mg007FixtureSettings();
c.detector_settings = mg015DetectorSettings("RUNLOCK", "weighted", "single_valid");
c.run_options = struct('split_id', "test", 'group_id', id, 'evaluate', true);
end
