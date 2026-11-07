function priv = lockScenario(spec, pub, world)
%LOCKSCENARIO LOCK the guide's setup: PrivateScenario (mg-v21-private/1.0) for the session's private slot.
%   priv = mgv21.placement.lockScenario(spec, pub, world)
%   priv fields: schema_version, truth (PrivateTargetTruth, evaluator only), surface_features (for
%   mgv2.sensors.SensorSystem(..., SurfaceFeatures=priv.surface_features) only), n_clutter.
%   pub is checked public and is NOT changed; after LOCK the UI shows no target marker
%   (setupMarkers(spec, "LOCKED") is empty). priv itself is private and fails mgv21.scenario.assertPublic.
mgv21.scenario.assertPublic(pub, "PublicMissionConfig");
truth = mgv21.placement.placeTargets(spec, pub, world);
[fwd, info] = mgv21.placement.forwardFeatures(truth, spec, pub, world);
mgv2.sensors.assertPublic(fwd, "SurfaceFeatures");
priv = struct('schema_version', mgv21.contract().schemas.private, 'truth', truth, 'surface_features', fwd, ...
    'n_clutter', info.n_clutter);
end
