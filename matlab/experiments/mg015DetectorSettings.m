function ds = mg015DetectorSettings(source, method, rule)
%MG015DETECTORSETTINGS Frozen detector settings for runExperiment.
%   ds = mg015DetectorSettings("MG009")    frozen MG-009 model (tasks/evidence/MG-009), selected in
%                                         the MG-009 0.3 m-altitude experiment; used for the S0 demo fixture
%   ds = mg015DetectorSettings("RUNLOCK")  MG014-RUNLOCK-1 model (tasks/evidence/MG-015), fitted on
%                                         GF TRAIN with thresholds selected on GF VALIDATION
%   method (default "weighted"), rule (default "single_valid"). Values are read from frozen files and
%   never refitted here.
if nargin < 2, method = "weighted"; end
if nargin < 3, rule = "single_valid"; end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
switch string(source)
    case "MG009"
        f = fullfile(root, 'tasks', 'evidence', 'MG-009', 'MG-009-frozen-model.json');
        F = jsondecode(fileread(f)); m = F.model; thr = F.method_thresholds; tol = F.declared.association_tolerance_s;
    case "RUNLOCK"
        f = fullfile(root, 'tasks', 'evidence', 'MG-015', 'MG014-RUNLOCK-1.json');
        F = jsondecode(fileread(f)); m = F.detector_model; thr = F.method_thresholds; tol = F.association_tolerance_s;
    otherwise
        error('mineguard:InvalidExperimentConfig', 'source must be "MG009" or "RUNLOCK".');
end
m.version = string(m.version);
m.provenance.normaliser_split = string(m.provenance.normaliser_split);
m.provenance.threshold_split = string(m.provenance.threshold_split);
ds = struct('method_name', string(method), 'missing_modality_rule', string(rule), 'association_tolerance_s', tol, ...
    'threshold', thr.(char(method)), 'model', m, 'model_id', string(source) + ":" + m.version);
end
