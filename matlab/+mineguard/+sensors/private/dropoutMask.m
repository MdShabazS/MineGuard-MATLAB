function drop = dropoutMask(ch, channel, ids, u)
%DROPOUTMASK Configured sample dropouts (an optional feature, off when the fields are absent).
%   dropout_probability   - seeded per-row probability, compared with the uniform draws u
%   dropout_pose_sample_ids - explicit pose IDs to drop (deterministic injection for tests)
drop = false(size(u));
if isfield(ch, 'dropout_probability')
    p = requireParam(ch, channel, 'dropout_probability', "prob");
    drop = drop | (u < p);
end
if isfield(ch, 'dropout_pose_sample_ids')
    list = ch.dropout_pose_sample_ids;
    if ~(isstring(list) || iscellstr(list) || ischar(list))
        error('mineguard:InvalidSensorConfig', 'MineGuard sensors: sensor_settings.%s.dropout_pose_sample_ids must be text.', channel);
    end
    drop = drop | ismember(ids, string(list));
end
end
