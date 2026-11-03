function pkg = verifyPackage(folder)
%VERIFYPACKAGE Read a run package back and check it completely before anything uses it. SIMULATION ONLY.
%   pkg = mgv2.run.verifyPackage(folder)
%   Checks, in order, and stops at the first failure:
%     1. files.sha256 lists exactly the files present (none missing, none extra) and every SHA-256 matches;
%     2. manifest schema is mg-v2-runpkg/1.0 and its counts match the files;
%     3. every sample passes mgv2.sensors.validateSample, and its mgv2.run.digest and position match samples/index.csv;
%     4. poses are one per tick from 0 without gaps; samples refer to recorded poses at the same time;
%     5. no forbidden truth name anywhere (mgv2.sensors.assertPublic).
%   Errors: mgv2:PackageTampered (a hash, file set or digest differs), mgv2:PackageInvalid (structure or content),
%   mgv2:TruthLeak. Nothing is repaired. pkg: folder, manifest, config, poses, phases, index, samples, events (JSON),
%   event_list (exact), evidence.
id = 'mgv2:PackageInvalid'; tid = 'mgv2:PackageTampered';
folder = string(folder);
if ~isfolder(folder), error(id, 'No package folder at %s.', folder); end
sumFile = fullfile(folder, "files.sha256");
if ~isfile(sumFile), error(tid, 'files.sha256 is missing.'); end
txt = strtrim(string(fileread(sumFile))); lines = splitlines(txt); lines = lines(strlength(lines) > 0);
tok = regexp(lines, '^([0-9a-f]{64})  (\S.*)$', 'tokens', 'once');
if any(cellfun(@isempty, tok)), error(tid, 'files.sha256 has a malformed line.'); end
tok = vertcat(tok{:}); listed = string(tok(:, 2)); want = string(tok(:, 1));
have = mgv2.run.listFiles(folder);
if ~isequal(sort(listed), have)
    error(tid, 'Package files differ from files.sha256 (missing: %s; extra: %s).', ...
        strjoin(setdiff(listed, have), ', '), strjoin(setdiff(have, listed), ', '));
end
for k = 1:numel(listed)
    if mgv2.run.fileSha256(fullfile(folder, listed(k))) ~= want(k), error(tid, 'SHA-256 of %s does not match files.sha256.', listed(k)); end
end

m = jsondecode(fileread(fullfile(folder, "manifest.json")));
if ~isfield(m, 'schema_version') || string(m.schema_version) ~= "mg-v2-runpkg/1.0", error(id, 'Unknown package schema.'); end
if ~isfield(m, 'simulation_only') || m.simulation_only ~= true, error(id, 'Package is not marked simulation only.'); end
cfg = load(fullfile(folder, "config", "run_config.mat"));
P = load(fullfile(folder, "telemetry", "poses.mat")); poses = P.poses;
nT = height(poses);                         % an abort records the last tick once more, as ABORTED
if nT > 1 && poses.tick_id(nT) == poses.tick_id(nT - 1) && poses.phase(nT) == "ABORTED", nT = nT - 1; end
if ~isequal(poses.tick_id(1:nT)', 0:nT - 1), error(id, 'Poses are not one per tick from tick 0.'); end
e = m.end_state;
if ~ismember(string(e.phase), ["COMPLETE","FAILED","ABORTED"]) || string(e.phase) ~= poses.phase(end), error(id, 'The recorded end state is not terminal or differs from the last pose.'); end
if height(poses) ~= m.counts.poses, error(id, 'Pose count differs from the manifest.'); end
idx = readtable(fullfile(folder, "samples", "index.csv"), 'TextType', 'string', 'Delimiter', ',');
samples = struct();
for sid = mgv2.sensors.SensorSystem.Order
    S = load(fullfile(folder, "samples", sid + ".mat")); C = S.samples; rows = find(idx.sensor_id == sid);
    if numel(C) ~= numel(rows) || numel(C) ~= m.counts.samples.(sid), error(id, '%s: sample count differs from the index or manifest.', sid); end
    for k = 1:numel(C)
        s = C{k}; r = rows(k);
        mgv2.sensors.validateSample(s);
        if string(s.frame_id) ~= idx.frame_id(r) || double(s.sample_seq) ~= idx.sample_seq(r) || double(s.tick_id) ~= idx.tick_id(r)
            error(id, '%s: sample %d is not the indexed frame.', sid, k);
        end
        if mgv2.run.digest(s) ~= idx.sample_sha256(r), error(tid, '%s: digest of %s differs from the index.', sid, s.frame_id); end
        if mgv2.sensors.checksum(mgv2.sensors.SensorSystem.payload(s)) ~= idx.checksum(r), error(tid, '%s: producer checksum of %s differs from the index.', sid, s.frame_id); end
        t = double(s.tick_id);
        if t >= height(poses) || abs(poses.t_s(t + 1) - s.t_s) > 1e-9, error(id, '%s: %s has no recorded pose at its time.', sid, s.frame_id); end
    end
    samples.(sid) = C;
end
E = jsondecode(fileread(fullfile(folder, "events", "events.json")));
V = load(fullfile(folder, "events", "evidence.mat")); X = load(fullfile(folder, "events", "events.mat"));
if numel(X.events) ~= m.counts.events, error(id, 'Event count differs from the manifest.'); end
pkg = struct('folder', folder, 'manifest', m, 'config', cfg, 'poses', poses, ...
    'phases', readtable(fullfile(folder, "telemetry", "phases.csv"), 'TextType', 'string'), 'index', idx, ...
    'samples', samples, 'events', E, 'event_list', X.events, 'evidence', V.evidence);
mgv2.sensors.assertPublic(rmfield(pkg, 'samples'), "package");
end
