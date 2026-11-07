function p = environmentPreset(id)
%ENVIRONMENTPRESET One synthetic environment preset: V2 scene config, lighting, geofence and default survey.
%   p = mgv21.scenario.environmentPreset()        default preset (TRAINING_FIELD_A = the V2 training field)
%   p = mgv21.scenario.environmentPreset(id)      id from mgv21.scenario.presetIds; else mgv21:UnknownPreset
%   p fields: preset_id, title, description, scene_config (mgv2.scene.defaultSceneConfig struct),
%             environment_mode (mgv2.sensors.defaultEnvironment mode), bounds_enu_m (3x2 geofence),
%             default_survey (SurveySpec).
%   Presets differ in terrain seed, relief, large-scale slope, rock/bush density and lighting. The V2 soil and
%   grass palette is fixed in mgv2.scene.buildWorld and is NOT changed by a preset. All values are synthetic.
if nargin < 1, id = mgv21.contract().default_preset; end
id = string(id);
if ~isscalar(id) || ~ismember(id, mgv21.scenario.presetIds())
    error('mgv21:UnknownPreset', 'Unknown environment preset "%s"; use one of: %s.', strjoin(id, ","), strjoin(mgv21.scenario.presetIds(), ", "));
end
v2m = mgv2.mission.defaultConfig();
switch id
    case "TRAINING_FIELD_A"     % exactly the V2 default field, survey and geofence
        sc = mgv2.scene.defaultSceneConfig();
        ttl = "Training field A (V2 default)";
        desc = "Gently rolling grass and soil field, moderate rocks and bushes, clear day.";
        env = "DAY_CLEAR"; bounds = v2m.bounds_enu_m;
        poly = v2m.survey_polygon_enu_m; home = v2m.home_enu_m; sp = v2m.line_spacing_m; alt = v2m.alt_agl_setpoint_m;
    case "ROCKY_UPLAND"         % steeper, tilted, rock-strewn ground at dawn
        sc = mgv2.scene.defaultSceneConfig('scene_id', "V21-ROCKY-UPLAND", 'seed', 4104, 'relief_m', 7, ...
            'slope', [0.05 -0.03], 'n_rocks', 110, 'n_bushes', 12);
        ttl = "Rocky upland";
        desc = "Higher relief on a tilted slope, dense rocks, sparse bushes, low sun (low thermal contrast).";
        env = "LOW_CONTRAST"; bounds = [-70 70; -70 70; -30 150];
        poly = [-35 -25; 35 -25; 35 25; -35 25]; home = [-55 -50]; sp = 10; alt = 18;
    case "DRY_FLATS"            % nearly flat open ground under overcast sky
        sc = mgv2.scene.defaultSceneConfig('scene_id', "V21-DRY-FLATS", 'seed', 5205, 'relief_m', 0.8, ...
            'slope', [0.004 0], 'n_rocks', 14, 'n_bushes', 5);
        ttl = "Dry flats";
        desc = "Almost flat open ground, few rocks and bushes, overcast sky (weak solar loading).";
        env = "OVERCAST"; bounds = [-75 75; -75 75; -10 120];
        poly = [-50 -35; 50 -35; 50 35; -50 35]; home = [-60 -55]; sp = 10; alt = 15;
end
sc.home_enu_m = home; sc.survey_polygon_enu_m = poly;
s = struct('schema_version', mgv21.contract().schemas.survey, 'boundary_kind', "RECTANGLE", 'polygon_enu_m', poly, ...
    'home_enu_m', home, 'line_spacing_m', sp, 'heading_deg', v2m.survey_heading_deg, 'alt_agl_m', alt, 'speed_mps', v2m.speed_mps);
p = struct('preset_id', id, 'title', ttl, 'description', desc, 'scene_config', sc, 'environment_mode', env, ...
    'bounds_enu_m', bounds, 'default_survey', s);
end
