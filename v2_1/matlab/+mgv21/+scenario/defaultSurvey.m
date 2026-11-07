function s = defaultSurvey(id)
%DEFAULTSURVEY Default SurveySpec (mg-v21-survey/1.0) of an environment preset.
%   s = mgv21.scenario.defaultSurvey()      default preset
%   s = mgv21.scenario.defaultSurvey(id)
%   s fields: schema_version, boundary_kind ("RECTANGLE"|"POLYGON"), polygon_enu_m (N-by-2, ENU m),
%             home_enu_m [x y], line_spacing_m, heading_deg (compass), alt_agl_m, speed_mps.
if nargin < 1, id = mgv21.contract().default_preset; end
s = mgv21.scenario.environmentPreset(id).default_survey;
end
