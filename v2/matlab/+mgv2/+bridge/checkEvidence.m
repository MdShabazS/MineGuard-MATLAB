function ins = checkEvidence(e, det, sensorLog, runId)
%CHECKEVIDENCE Verified evidence for one V2-006 event in the UI session's run. SIMULATED.
%   ins = mgv2.bridge.checkEvidence(e, det, sensorLog, runId)
%   e          original V2-006 event (not the UI mapping)
%   det        AnomalyDetector holding the retained records
%   sensorLog  SensorSystem.Log of the same run
%   runId      run the UI session is showing
%   Raises mgv2:BridgeRunMismatch for another run, mgv2:EvidenceMissing for a record no longer retained, and
%   mgv2:EvidenceMismatch for any difference from the event or the producer's log. Nothing is ever substituted.
if e.run_id ~= runId
    error('mgv2:BridgeRunMismatch', 'Event %s belongs to run %s, not %s.', e.event_id, e.run_id, runId);
end
ins = mgv2.detect.inspectEvent(e, det, sensorLog);
end
