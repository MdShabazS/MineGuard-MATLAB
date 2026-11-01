function ins = inspectEvent(e, det, sensorLog)
%INSPECTEVENT Evidence inspector record for one SUSPECTED event, built from its EXACT sample references.
%   ins = mgv2.detect.inspectEvent(e, det)               e: event from det.events(); det: AnomalyDetector
%   ins = mgv2.detect.inspectEvent(e, det, sensorLog)    also cross-check every reference against the
%                                                        SensorSystem.Log row of the same frame_id
%   For every e.evidence_refs entry the retained record det.evidence(ref_id) is fetched and verified:
%   same frame_id, sensor_id, tick_id, pose_id, t_s and sample checksum as the event reference; with a
%   sensor log, the checksum must also equal the producer's checksum for that frame_id (the crop shown
%   comes from exactly that sample). A failed check raises mgv2:EvidenceMismatch; nothing is substituted.
%   ins: event_id, status, time window, sensors_used, score text ("uncalibrated"), estimated location with
%   1-sigma uncertainty, missing modalities, LiDAR context, items (crop, units, frame/tick/time) and a text
%   summary. Passes mgv2.sensors.assertPublic and mgv2.detect.assertNoBannedWords.
mgv2.detect.validateEvent(e);
refs = e.evidence_refs; items = struct('ref_id', {}, 'frame_id', {}, 'sensor_id', {}, 'tick_id', {}, 'pose_id', {}, 't_s', {}, ...
    'sample_checksum', {}, 'verified_against_sensor_log', {}, 'u_px', {}, 'v_px', {}, 'strength', {}, 'strength_unit', {}, ...
    'crop', {}, 'crop_mask', {}, 'crop_origin_px', {});
for k = 1:numel(refs)
    r = refs(k); R = det.evidence(r.ref_id);
    same = R.frame_id == r.frame_id && R.sensor_id == r.sensor_id && R.tick_id == r.tick_id && R.pose_id == r.pose_id ...
        && R.t_s == r.t_s && R.sample_checksum == r.sample_checksum;
    if ~same, error('mgv2:EvidenceMismatch', 'Evidence %s does not match its event reference.', r.ref_id); end
    v = false;
    if nargin > 2
        row = sensorLog(sensorLog.frame_id == r.frame_id, :);
        if height(row) ~= 1 || row.checksum ~= r.sample_checksum || row.tick_id ~= r.tick_id
            error('mgv2:EvidenceMismatch', 'Evidence %s does not match the producer log for %s.', r.ref_id, r.frame_id);
        end
        v = true;
    end
    items(k) = struct('ref_id', r.ref_id, 'frame_id', r.frame_id, 'sensor_id', r.sensor_id, 'tick_id', r.tick_id, ...
        'pose_id', r.pose_id, 't_s', r.t_s, 'sample_checksum', r.sample_checksum, 'verified_against_sensor_log', v, ...
        'u_px', R.u_px, 'v_px', R.v_px, 'strength', R.strength, 'strength_unit', R.strength_unit, 'crop', R.crop, ...
        'crop_mask', R.crop_mask, 'crop_origin_px', R.crop_origin_px);
end
used = unique([items.sensor_id]);
txt = [sprintf("%s  |  %s (SIMULATED)", e.event_id, e.status)
    sprintf("time %.2f-%.2f s (ticks %d-%d), %d observations", e.first_t_s, e.last_t_s, e.first_tick, e.last_tick, e.n_observations)
    sprintf("basis %s  |  sensors with evidence: %s", e.detection_basis, strjoin(used, ", "))
    sprintf("model score %.3f (UNCALIBRATED heuristic score, not a probability)", e.model_score)
    sprintf("estimated ENU (%.2f, %.2f) m  +/- %.2f m (1-sigma, %s)", e.x_est_m, e.y_est_m, e.uncertainty_m, e.uncertainty_status)
    sprintf("RGB contrast z %.1f | thermal deviation %.2f K | LiDAR context %s (max height %.2f m, %d returns)", ...
        e.features.rgb_contrast_z, e.features.thermal_deviation_K, e.features.lidar_context, ...
        e.features.lidar_height_above_terrain_m, e.features.lidar_returns)
    "missing/invalid: " + strjoin([e.missing_modalities(:); "none"], "; ")
    e.label_text];
ins = struct('event_id', e.event_id, 'status', e.status, 'simulated', true, 'time_window_s', [e.first_t_s e.last_t_s], ...
    'sensors_used', used, 'model_score', e.model_score, 'score_text', sprintf("%.3f (uncalibrated)", e.model_score), ...
    'estimated_enu_m', [e.x_est_m e.y_est_m e.z_est_m], 'uncertainty_m', e.uncertainty_m, ...
    'missing_modalities', e.missing_modalities, 'features', e.features, 'detector_fingerprint', e.detector_fingerprint, ...
    'items', items, 'summary_text', txt);
mgv2.sensors.assertPublic(ins, "inspector"); mgv2.detect.assertNoBannedWords(rmfield(ins, 'items'), "inspector");
end
