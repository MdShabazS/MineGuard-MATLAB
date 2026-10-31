function checkProvenance(bundle, config, detectorConfig, runMetadata)
%CHECKPROVENANCE Reject any mismatch between the run's data, configs and metadata (MG-009 integration).
%   mineguard.evaluation.checkProvenance(bundle, config, detectorConfig, runMetadata)
%   Checks that the scenario_id agrees across config, bundle, samples' run, detectorConfig and
%   runMetadata, and that the schema version agrees. The thermal, EM and navigation seeds must
%   equal the MG-004 derivation mod(noise_seed + k*1000003, 2^32) for k = 1, 2, 3, the sensor
%   settings and model versions must equal the config's, and the config checksum must equal
%   configChecksum(config). Any mismatch throws mineguard:ProvenanceMismatch.
id = 'mineguard:ProvenanceMismatch';
p = bundle.provenance;
sid = string(config.scenario_id);
ids = [string(p.scenario_id), string(bundle.public.scenario_id), string(detectorConfig.scenario_id), string(runMetadata.scenario_id)];
if any(ids ~= sid)
    error(id, 'MineGuard provenance: scenario_id mismatch (config %s vs %s).', sid, strjoin(unique(ids), ', '));
end
if string(p.schema_version) ~= string(config.schema_version) || string(detectorConfig.schema_version) ~= string(config.schema_version)
    error(id, 'MineGuard provenance: schema_version mismatch.');
end
if p.scenario_seed ~= config.seed || p.noise_seed ~= config.noise_seed
    error(id, 'MineGuard provenance: scenario/noise seed mismatch.');
end
d = @(k) mod(double(config.noise_seed) + k * 1000003, 2^32);
if p.thermal_seed ~= d(1) || p.em_seed ~= d(2) || p.navigation_seed ~= d(3)
    error(id, 'MineGuard provenance: channel seeds do not match the MG-004 derivation from noise_seed.');
end
ss = config.sensor_settings;
if p.sensor_settings_version ~= string(ss.version) || p.thermal_model_version ~= channelModelVersion(ss, 'thermal') || ...
        p.em_model_version ~= channelModelVersion(ss, 'em')
    error(id, 'MineGuard provenance: sensor settings/model version mismatch.');
end
if p.config_checksum ~= mineguard.evaluation.configChecksum(config)
    error(id, 'MineGuard provenance: config checksum mismatch; the data was generated with a different configuration.');
end
end
