function ev = validateEvents(ev)
%VALIDATEEVENTS Reject V2-006 event records the console must not show (SuspectedEvent, architecture section 4).
%   ev = mgv2.ui.validateEvents(ev)   ev: empty or struct array. Throws mgv2:InvalidEvent or mgv2:TruthLeak.
id = 'mgv2:InvalidEvent';
if isempty(ev), ev = struct([]); return; end
if ~isstruct(ev), error(id, 'Events must be a struct array.'); end
need = ["event_id","run_id","t_s","x_est_m","y_est_m","model_score","confidence_kind","modality_flags","evidence_refs","uncertainty_m","status","detector_version"];
miss = setdiff(need, string(fieldnames(ev))');
if ~isempty(miss), error(id, 'Event is missing field "%s".', miss(1)); end
mgv2.sensors.assertPublic(ev, "event");
for k = 1:numel(ev)
    e = ev(k);
    if string(e.status) ~= "SUSPECTED", error(id, 'Event %s: status must be SUSPECTED, got "%s".', string(e.event_id), string(e.status)); end
    if strlength(string(e.detector_version)) == 0, error(id, 'Event %s: detector_version is required.', string(e.event_id)); end
    if ~(isscalar(e.x_est_m) && isscalar(e.y_est_m) && isfinite(e.x_est_m) && isfinite(e.y_est_m))
        error(id, 'Event %s: x_est_m and y_est_m must be finite scalars.', string(e.event_id));
    end
end
end
