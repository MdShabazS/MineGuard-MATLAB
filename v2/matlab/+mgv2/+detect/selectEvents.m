function [keep, score] = selectEvents(T, mode, thr, cfg)
%SELECTEVENTS The single event-emission rule shared by AnomalyDetector.events and the TRAIN/VAL study.
%   [keep, score] = mgv2.detect.selectEvents(T, mode, thr, cfg)
%   T     track table (AnomalyDetector.trackTable)       mode  FUSED | RGB_ONLY | THERMAL_ONLY
%   thr   score threshold                                 cfg   validated detector config
%   keep  logical per track: score available, score >= thr, >= cfg.event.min_detections observations in the
%         scored modalities, not at a public calibration landmark, and (FUSED, emit_single_channel false)
%         evidence from both modalities.
switch mode
    case "FUSED", score = T.score_fused; nd = T.n_obs_rgb + T.n_obs_thermal;
    case "RGB_ONLY", score = T.score_rgb; nd = T.n_obs_rgb;
    case "THERMAL_ONLY", score = T.score_thermal; nd = T.n_obs_thermal;
    otherwise, error('mgv2:InvalidDetectorConfig', 'Unknown score mode %s.', mode);
end
keep = ~isnan(score) & score >= thr & nd >= cfg.event.min_detections & T.known_landmark == "";
if mode == "FUSED" && ~cfg.event.emit_single_channel
    keep = keep & T.n_obs_rgb > 0 & T.n_obs_thermal > 0;
end
end
