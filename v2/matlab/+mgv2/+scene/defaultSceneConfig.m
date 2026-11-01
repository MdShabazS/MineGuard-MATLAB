function cfg = defaultSceneConfig(varargin)
%DEFAULTSCENECONFIG Configuration of the seeded synthetic survey field (V2-003). SIMULATION ONLY.
%   cfg = mgv2.scene.defaultSceneConfig()
%   cfg = mgv2.scene.defaultSceneConfig(Name=Value, ...)
%   All lengths in metres (ENU). The scene contains only OBSERVABLE surface geometry (ground, rocks,
%   vegetation, markers, landmarks); hidden scenario truth such as buried targets is never part of it.
cfg = struct();
cfg.schema_version = "mg-v2-scene/0.1";       % provisional, V2-003 owned
cfg.scene_id = "V2-TRAINING-FIELD-A";
cfg.seed = 3003;
cfg.extent_enu_m = [-80 80; -80 80];          % [xmin xmax; ymin ymax]
cfg.grid_spacing_m = 1.0;                     % terrain vertex spacing
cfg.relief_m = 3.0;                           % peak amplitude of the rolling relief
cfg.slope = [0.02 0.01];                      % large-scale gradient dz/dx, dz/dy
cfg.home_enu_m = [-55 -50];                   % landing pad centre (matches mgv2.mission.defaultConfig)
cfg.home_pad_m = 4;                           % pad side length (flat)
cfg.survey_polygon_enu_m = [-40 -30; 40 -30; 40 30; -40 30];   % drawn as the survey boundary
cfg.n_rocks = 45;
cfg.n_bushes = 30;
cfg.landmarks = struct('id', {"LM-1","LM-2"}, 'xy', {[12.5 -7.25], [-22 18]}, 'radius_m', {0.6, 0.6}, ...
    'color', {[0.95 0.10 0.85], [0.10 0.85 0.95]});   % painted calibration discs (observable, not hazards)
for k = 1:2:numel(varargin)
    cfg.(string(varargin{k})) = varargin{k+1};
end
end
