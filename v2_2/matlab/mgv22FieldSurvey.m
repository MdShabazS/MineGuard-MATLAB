function v = mgv22FieldSurvey(varargin)
%MGV22FIELDSURVEY Open the BITM field survey view: draw a field, fly a SIMULATED drone survey of it (V22-T11).
%   From the repository root:  mineguard_setup; addpath('v2_2/matlab'); v = mgv22FieldSurvey();
%   v = mgv22FieldSurvey(Theme="light", Visible="off")   Name=Value pairs go to mgv22.field.FieldSurveyView.
%   Real imagery, SIMULATED flight: marks are SUSPECTED anomalies (SIMULATION) only; this is not a hazard map.
v = mgv22.field.FieldSurveyView(varargin{:});
end
