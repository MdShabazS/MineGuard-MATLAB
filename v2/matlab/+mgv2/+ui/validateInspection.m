function ins = validateInspection(ins, eventId)
%VALIDATEINSPECTION Check one evidence record before EventInspectorPanel shows it. SIMULATED.
%   ins = mgv2.ui.validateInspection(ins, eventId)   Throws mgv2:InvalidInspection or mgv2:TruthLeak.
%   ins fields: event_id, status, simulated, time_window_s, sensors_used, score_text, estimated_enu_m, uncertainty_m,
%   missing_modalities, items. items fields: ref_id, frame_id, sensor_id, tick_id, pose_id, t_s, sample_checksum,
%   verified_against_sensor_log, crop. A crop is an RGB image or a Kelvin raster. Every item must be verified.
id = 'mgv2:InvalidInspection';
if ~isstruct(ins) || ~isscalar(ins), error(id, 'An inspection must be a scalar struct.'); end
need = ["event_id","status","simulated","time_window_s","sensors_used","score_text","estimated_enu_m","uncertainty_m","missing_modalities","items"];
miss = setdiff(need, string(fieldnames(ins))');
if ~isempty(miss), error(id, 'Inspection is missing field "%s".', miss(1)); end
mgv2.sensors.assertPublic(ins, "inspection");
if string(ins.event_id) ~= string(eventId), error(id, 'Inspection is for event %s, not %s.', string(ins.event_id), string(eventId)); end
if string(ins.status) ~= "SUSPECTED" || ~isequal(ins.simulated, true), error(id, 'Inspection of %s must be SUSPECTED and simulated.', string(eventId)); end
if isempty(ins.items), error(id, 'Inspection of %s has no evidence records.', string(eventId)); end
need = ["ref_id","frame_id","sensor_id","tick_id","pose_id","t_s","sample_checksum","verified_against_sensor_log","crop"];
miss = setdiff(need, string(fieldnames(ins.items))');
if ~isempty(miss), error(id, 'Evidence record is missing field "%s".', miss(1)); end
if ~all([ins.items.verified_against_sensor_log]), error(id, 'Inspection of %s has an unverified evidence record.', string(eventId)); end
end
