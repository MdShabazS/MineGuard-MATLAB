function rs = sensorStream(seed, scenarioId, sensorId, substream)
%SENSORSTREAM Independent deterministic random stream for one sensor (and one sample).
%   rs = mgv2.sensors.sensorStream(seed, scenarioId, sensorId, substream)
%   Seed = FNV-1a 32-bit hash of "<seed>|<scenario_id>|<sensor_id>|rng-v1"; generator mrg32k3a, whose
%   substreams are statistically independent and directly addressable. Using Substream = sample_seq + 1
%   makes every sample's noise depend only on (seed, scenario, sensor, sample_seq): enabling or disabling
%   another sensor, or changing the order in which sensors are sampled, cannot change it (V2-004 §2.1).
key = uint8(char(sprintf('%d|%s|%s|rng-v1', round(double(seed)), string(scenarioId), string(sensorId))));
h = 2166136261;                          % FNV offset basis; prime 16777619 = 2^24 + 403
for b = double(key)
    h = double(bitxor(uint32(h), uint32(b)));
    h = mod(mod(h * 2^24, 2^32) + h * 403, 2^32);   % exact in double (all terms < 2^53)
end
rs = RandStream('mrg32k3a', 'Seed', h);
rs.Substream = double(substream);
end
