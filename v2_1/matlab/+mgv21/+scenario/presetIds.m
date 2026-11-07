function ids = presetIds()
%PRESETIDS Identifiers of the V2.1 synthetic environment presets (first = default). SIMULATION ONLY.
%   ids = mgv21.scenario.presetIds()      -> ["TRAINING_FIELD_A","ROCKY_UPLAND","DRY_FLATS"]
ids = mgv21.contract().preset_ids;
end
