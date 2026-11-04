function mc = missionFor(s, p, runId, seed)
%MISSIONFOR V2 MissionConfig for a normalised SurveySpec s and preset p, validated by mgv2.mission.validateConfig.
mc = mgv2.mission.defaultConfig('run_id', string(runId), 'scenario_id', "V21-" + p.preset_id, 'seed', seed, ...
    'bounds_enu_m', p.bounds_enu_m, 'survey_polygon_enu_m', s.polygon_enu_m, 'home_enu_m', s.home_enu_m, ...
    'alt_agl_setpoint_m', s.alt_agl_m, 'speed_mps', s.speed_mps, 'line_spacing_m', s.line_spacing_m, ...
    'survey_heading_deg', s.heading_deg);
try
    mc = mgv2.mission.validateConfig(mc);
catch err
    error('mgv21:InvalidSurvey', 'The V2 mission validator refused this survey: %s', err.message);
end
end
