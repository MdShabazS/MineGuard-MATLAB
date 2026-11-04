function [pub, plan] = buildPublicMission(id, s, opts)
%BUILDPUBLICMISSION PublicMissionConfig (mg-v21-public/1.0) for a preset and SurveySpec. PUBLIC, no truth.
%   [pub, plan] = mgv21.scenario.buildPublicMission(id, s)
%   [pub, plan] = mgv21.scenario.buildPublicMission(id, s, RunId="V21RUN-0001", MissionSeed=2002, World=world)
%   pub   schema_version, preset_id, scene_config (V2 scene config with this survey's home and boundary),
%         mission (V2 MissionConfig, mgv2.mission.validateConfig passed), environment_mode, survey (normalised).
%   plan  mgv2.mission.planSurvey(pub.mission): the exact lawnmower route the V2 engine flies.
%   Throws mgv21:InvalidSurvey (see validateSurvey) instead of returning a plan it cannot fly.
%   pub never depends on placement: it is built without a PlacementSpec and passes mgv21.scenario.assertPublic.
arguments
    id
    s struct
    opts.RunId = "V21RUN-0001"
    opts.MissionSeed (1,1) double = 2002
    opts.World = []
end
p = mgv21.scenario.environmentPreset(id);
[s, rep] = mgv21.scenario.validateSurvey(s, p.preset_id, opts.World);
mc = missionFor(s, p, opts.RunId, opts.MissionSeed);
sc = p.scene_config; sc.home_enu_m = s.home_enu_m; sc.survey_polygon_enu_m = s.polygon_enu_m;
pub = struct('schema_version', mgv21.contract().schemas.public, 'preset_id', p.preset_id, 'scene_config', sc, ...
    'mission', mc, 'environment_mode', p.environment_mode, 'survey', s);
mgv21.scenario.assertPublic(pub, "PublicMissionConfig");
plan = rep.plan;
end
