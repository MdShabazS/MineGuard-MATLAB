function g = demoFixtureGroup()
%DEMOFIXTUREGROUP DEMO FIXTURE scenario (V2-004 §4): one deliberately strong synthetic surface feature at a
%   known location [5.5 3.25] m ENU. Used only to show that a SUSPECTED event can arise through detector
%   computation and to measure geolocation error. EXCLUDED from every accuracy/TRAIN/VAL/TEST report.
g = mgv2.eval.scenarioGroups(); g = g(1);
g.group_id = "DEMO"; g.split = "DEMO_FIXTURE"; g.family = "DEMO_FIXTURE"; g.environment = "DAY_CLEAR";
g.scene_seed = 6001; g.layout_seed = 7001; g.mission_seed = 8001;
g.n_visible_targets = 0; g.n_blind_targets = 0; g.n_wet = 0; g.n_soil = 0; g.n_scrap = 0; g.thermal_dropout_s = zeros(0, 2);
g.demo_fixture = true;
end
