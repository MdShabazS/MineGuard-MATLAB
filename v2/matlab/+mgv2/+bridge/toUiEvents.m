function [ev, rejected] = toUiEvents(E, runId, det)
%TOUIEVENTS Map V2-006 events to the UI SuspectedEvent schema without changing the detector schema. SIMULATED.
%   [ev, rejected] = mgv2.bridge.toUiEvents(E, runId, det)
%   E         event array from det.events()
%   runId     run the UI session is showing
%   det       the AnomalyDetector that produced E, used to confirm each evidence reference is retained
%   ev        struct array for mgv2.ui.validateEvents (empty struct if none)
%   rejected  event_id of every event left out. A rejected event is never repaired, and the caller must report it.
%   An event is rejected if it fails its contract, has another run_id, has no evidence reference, or has a
%   reference whose retained record is missing or differs.
%   Mapping: t_s = last_t_s (latest sighting), confidence_kind = score_kind, modality_flags = detection_basis.
%   The score stays an uncalibrated heuristic score, never a probability.
ev = struct([]); rejected = strings(0, 1);
for k = 1:numel(E)
    e = E(k);
    if ~eventIsUsable(e, runId, det), rejected(end+1, 1) = string(e.event_id); continue; end %#ok<AGROW>
    x = struct('event_id', e.event_id, 'run_id', e.run_id, 't_s', e.last_t_s, 'x_est_m', e.x_est_m, 'y_est_m', e.y_est_m, ...
        'model_score', e.model_score, 'confidence_kind', e.score_kind, 'modality_flags', e.detection_basis, ...
        'evidence_refs', e.evidence_refs, 'uncertainty_m', e.uncertainty_m, 'status', e.status, 'detector_version', e.detector_version);
    if isempty(ev), ev = x; else, ev(end+1, 1) = x; end %#ok<AGROW>
end
mgv2.sensors.assertPublic(ev, "bridgeEvents");
end

function ok = eventIsUsable(e, runId, det)
ok = false;
try
    mgv2.detect.validateEvent(e);
catch err
    if err.identifier == "mgv2:TruthLeak", rethrow(err); end
    return
end
if e.run_id ~= runId || isempty(e.evidence_refs), return; end
for r = reshape(e.evidence_refs, 1, [])
    try
        R = det.evidence(r.ref_id);
    catch
        return
    end
    if R.frame_id ~= r.frame_id || R.sample_checksum ~= r.sample_checksum || R.tick_id ~= r.tick_id, return; end
end
ok = true;
end
