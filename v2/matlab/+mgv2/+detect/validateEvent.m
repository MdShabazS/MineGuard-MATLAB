function validateEvent(e)
%VALIDATEEVENT Check one SUSPECTED event against mg-v2-detector/1.0. Throws mgv2:InvalidEvent / mgv2:TruthLeak.
%   mgv2.detect.validateEvent(e)
%   Exact ordered field set; status SUSPECTED; simulated true; finite observation-derived position;
%   uncertainty finite and > 0; model_score in [0,1] with the uncalibrated score_kind; detection_basis in the
%   contract list; evidence references with frame ids; detector fingerprint present; no truth field anywhere
%   (mgv2.sensors.assertPublic); no banned word (safe, cleared, confirmed, ...) in any text field (SC-22).
c = mgv2.detect.contract(); id = 'mgv2:InvalidEvent';
if ~isstruct(e) || ~isscalar(e), error(id, 'Event must be a scalar struct.'); end
mgv2.sensors.assertPublic(e, "event");
if ~isequal(string(fieldnames(e))', c.event_fields), error(id, 'Event fields must be exactly the mg-v2-detector/1.0 fields.'); end
if e.schema_version ~= c.schema_version, error(id, 'schema_version must be %s.', c.schema_version); end
if e.status ~= "SUSPECTED", error(id, 'status must be SUSPECTED.'); end
if e.simulated ~= true, error(id, 'simulated must be true.'); end
if ~ismember(e.detection_basis, c.bases), error(id, 'Unknown detection_basis.'); end
if ~all(isfinite([e.x_est_m e.y_est_m e.z_est_m])), error(id, 'Estimated position must be finite.'); end
if ~(isfinite(e.uncertainty_m) && e.uncertainty_m > 0) || ~ismember(e.uncertainty_status, c.uncertainty_statuses)
    error(id, 'uncertainty_m must be finite and positive with a declared status.');
end
if ~(isscalar(e.model_score) && e.model_score >= 0 && e.model_score <= 1) || e.score_kind ~= c.score_kind
    error(id, 'model_score must be an uncalibrated score in [0, 1].');
end
if isempty(e.evidence_frame_ids) || e.n_observations < 1, error(id, 'An event needs observation evidence.'); end
if strlength(e.detector_fingerprint) == 0, error(id, 'detector_fingerprint missing.'); end
mgv2.detect.assertNoBannedWords(e, "event");
end
