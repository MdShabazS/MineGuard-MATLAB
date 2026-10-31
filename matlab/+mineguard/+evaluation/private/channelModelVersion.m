function v = channelModelVersion(ss, channel)
%CHANNELMODELVERSION Sensor channel model version, or "UNCONFIGURED" when the channel is absent.
%   MG-007 deliberately supports a missing channel (UNCONFIGURED_SENSOR rows); provenance must
%   record that state rather than crash. (MG-015 defect fix to the MG-009 orchestrator.)
if isstruct(ss) && isfield(ss, channel) && isstruct(ss.(channel)) && isfield(ss.(channel), 'model_version')
    v = string(ss.(channel).model_version);
else
    v = "UNCONFIGURED";
end
end
