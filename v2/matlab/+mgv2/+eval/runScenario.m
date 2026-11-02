function out = runScenario(g, opts)
%RUNSCENARIO Simulate one scenario group end-to-end with the PUBLIC pipeline (no truth inside). SIMULATED.
%   out = mgv2.eval.runScenario(g)
%   out = mgv2.eval.runScenario(g, DetectorConfig=cfg, KeepFrames=n, MaxTicks=n)
%   g    one mgv2.eval.scenarioGroups entry (TRAIN / VAL) or mgv2.eval.demoFixtureGroup
%   Pipeline: MissionEngine -> SensorSystem (forward model receives the PRIVATE surface features) ->
%   AnomalyDetector and MissionMap (receive ONLY public samples/poses). The TargetTruth output of the scenario
%   builder is discarded here; evaluation is a separate call (mgv2.eval.evaluateEvents) on frozen output.
%   TEST groups are SEALED in V2-006: requesting one throws mgv2:TestSealed (one-time use belongs to V2-008).
%   out: group_id, split, engine, sensors, detector, map, events (frozen config), track_table, wall_s, sim_s.
arguments
    g struct
    opts.DetectorConfig struct = mgv2.detect.defaultDetectorConfig()
    opts.KeepFrames (1,1) double = 8
    opts.MaxTicks (1,1) double = inf
end
if g.split == "TEST"
    error('mgv2:TestSealed', 'Group %s is a reserved held-out TEST group; V2-006 never runs TEST (EVAL-09 is V2-008).', g.group_id);
end
[pub, fwd] = mgv2.eval.buildScenario(g);             % third output (TargetTruth) intentionally not requested
eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world));
sys = mgv2.sensors.SensorSystem(pub.world, pub.mission, SensorConfig=pub.sensor_config, Environment=pub.environment, ...
    SurfaceFeatures=fwd, KeepFrames=opts.KeepFrames);
det = mgv2.detect.AnomalyDetector(pub.world, pub.mission, Config=opts.DetectorConfig);
map = mgv2.map.MissionMap(pub.world, pub.mission);
map.attach(eng); det.attach(sys); sys.subscribe(@(s) map.addSample(s)); sys.attach(eng);
t0 = tic;
if isfinite(opts.MaxTicks), eng.run(opts.MaxTicks); else, eng.run(); end
wall = toc(t0);
E = det.events(); map.setEvents(E);
out = struct('group_id', g.group_id, 'split', g.split, 'engine', eng, 'sensors', sys, 'detector', det, 'map', map, ...
    'world', pub.world, 'mission', pub.mission, 'events', E, 'track_table', det.trackTable(), 'wall_s', wall, 'sim_s', eng.time());
end
