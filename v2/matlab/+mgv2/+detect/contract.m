function c = contract()
%CONTRACT Versioned V2-006 detector/event contract mg-v2-detector/1.0 (public, observation-derived only).
%   c = mgv2.detect.contract()
%   inputs          - the ONLY inputs a detector may consume: public mg-v2-sensors/1.0 samples (validated by
%                     mgv2.sensors.validateSample), the public V2-003 terrain/landmark geometry and the mission
%                     run_id/dt. No scenario builder output, forward-model feature or evaluator truth.
%   event_fields    - exact, ordered field set of a SUSPECTED event (mgv2.detect.validateEvent)
%   statuses        - the only status value: SUSPECTED
%   bases           - detection_basis values (fused or explicitly single-channel)
%   reject_reasons  - ingest outcome per sample (logged)
%   banned_words    - words that must never appear in any event/map/inspector text (SC-22)
c.schema_version = "mg-v2-detector/1.0";
c.inputs = ["RGB_NADIR","THERMAL_LWIR","LIDAR_TERRAIN","VIRTUAL_GNSS_INS"];
c.event_fields = ["schema_version","event_id","status","simulated","detection_basis","x_est_m","y_est_m","z_est_m", ...
    "position_frame","uncertainty_m","uncertainty_status","model_score","score_kind","score_components","features", ...
    "modality_validity","missing_modalities","first_tick","last_tick","first_t_s","last_t_s","n_observations", ...
    "evidence_frame_ids","evidence_refs","detector_id","detector_version","detector_fingerprint","run_id","scenario_id","label_text"];
c.statuses = "SUSPECTED";
c.bases = ["FUSED_RGB_THERMAL","SINGLE_CHANNEL_RGB","SINGLE_CHANNEL_THERMAL"];
c.score_kind = "UNCALIBRATED_HEURISTIC_SCORE (not a probability)";
c.uncertainty_statuses = ["MODEL_PLUS_SCATTER","MODEL_ONLY_SINGLE_OBSERVATION"];
c.reject_reasons = ["ACCEPTED","INVALID_SAMPLE","RUN_MISMATCH","TIMESTAMP_MISMATCH","STALE_OR_DUPLICATE","STALE_DATA"];
c.label_text = "SIMULATED | SUSPECTED ANOMALY | uncalibrated score | not a hazard confirmation | unobserved or event-free ground is not certified";
c.banned_words = ["safe","cleared","clearance","confirmed","mine-free","hazard-free","probability of"];
end
