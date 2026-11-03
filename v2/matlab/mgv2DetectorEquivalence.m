function R = mgv2DetectorEquivalence(outFile, opts)
%MGV2DETECTOREQUIVALENCE Exact-output record of the detector on permitted fixtures (issue #76). SIMULATED.
%   R = mgv2DetectorEquivalence("golden.json")               record from the code on the path
%   R = mgv2DetectorEquivalence("new.json", Compare="golden.json")   record and compare; R.equal is the verdict
%   Permitted fixtures only: TRAIN groups G01 G03 G05 G06 and the DEMO FIXTURE. No VAL or TEST group can run here,
%   and runScenario's seal is not involved because only the listed groups are ever built. Scenario truth is never
%   requested. The study stages are not called and no threshold is selected.
%   Recorded at each CheckEvery ticks and at the end, as SHA-256 of %.17g text: every track table column in order,
%   every event field for all three score modes, every retained evidence record including crops, the ingest log
%   outcomes and candidate counts, and the sample checksums. A stale and an invalid sample are injected once.
arguments
    outFile (1,1) string
    opts.Compare (1,1) string = ""
    opts.CheckEvery (1,1) double = 300
    opts.Groups (1,:) string = ["G01","G03","G05","G06","DEMO"]
end
G = mgv2.eval.scenarioGroups(); R = struct('fingerprint', mgv2.detect.defaultDetectorConfig().parameter_hash, 'runs', []);
for id = opts.Groups
    if id == "DEMO", g = mgv2.eval.demoFixtureGroup(); else, g = G([G.group_id] == id); end
    if ~ismember(g.split, ["TRAIN","DEMO_FIXTURE"]), error('mgv2:NotPermitted', 'Group %s is not a permitted fixture.', id); end
    [pub, fwd] = mgv2.eval.buildScenario(g);                    % truth output deliberately not requested
    eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(pub.world));
    sys = mgv2.sensors.SensorSystem(pub.world, pub.mission, SensorConfig=pub.sensor_config, Environment=pub.environment, SurfaceFeatures=fwd, KeepFrames=4);
    det = mgv2.detect.AnomalyDetector(pub.world, pub.mission); det.attach(sys); sys.attach(eng); eng.start();
    cp = strings(0, 1); k = 0; injected = false;
    while eng.step()
        k = k + 1;
        if mod(k, opts.CheckEvery) == 0
            cp(end+1, 1) = record(det); %#ok<AGROW>
            if ~injected
                s = sys.latest("RGB_NADIR"); det.ingest(s);            % stale: already seen
                x = sys.latest("THERMAL_LWIR"); x.valid = false; x.invalid_reason = "SENSOR_DROPOUT"; x.tick_id = uint64(k + 1); x.pose_id = x.tick_id; x.t_s = (k + 1) * pub.mission.dt_s;
                try, det.ingest(x); catch, end                          % invalid frame through the same path
                injected = true;
            end
        end
    end
    cp(end+1, 1) = record(det);
    run = struct('group', id, 'ticks', k, 'phase', string(eng.Phase), 'tracks', height(det.trackTable()), 'events', numel(det.events()), ...
        'samples_digest', hash(sys.Log.checksum), 'log_digest', hash(string(det.Log.frame_id) + "|" + det.Log.outcome + "|" + string(det.Log.n_candidates)), 'checkpoints', cp);
    if isempty(R.runs), R.runs = run; else, R.runs(end+1) = run; end
    fprintf('%s %d ticks, %d tracks, %d events, %d checkpoints\n', id, k, run.tracks, run.events, numel(cp));
end
fid = fopen(outFile, 'w'); fprintf(fid, '%s', jsonencode(R, PrettyPrint=true)); fclose(fid);
if opts.Compare ~= ""
    A = jsondecode(fileread(opts.Compare)); R.equal = isequal(string(A.fingerprint), R.fingerprint) && numel(A.runs) == numel(R.runs); R.differences = strings(0, 1);
    for q = 1:numel(R.runs)
        a = A.runs(q); b = R.runs(q);
        for f = ["group","ticks","phase","tracks","events","samples_digest","log_digest"]
            if ~isequal(string(a.(f)), string(b.(f))), R.equal = false; R.differences(end+1, 1) = b.group + " " + f; end
        end
        if ~isequal(string(a.checkpoints), b.checkpoints)
            R.equal = false; R.differences(end+1, 1) = b.group + " checkpoints first differ at " + find(string(a.checkpoints) ~= b.checkpoints, 1);
        end
    end
    fprintf('EQUIVALENCE %d, %d difference(s)\n', R.equal, numel(R.differences));
end
end

function d = record(det)
T = det.trackTable(); parts = strings(0, 1);
for v = string(T.Properties.VariableNames)
    x = T.(v); if isnumeric(x), x = compose("%.17g", x); end
    parts(end+1, 1) = v + "=" + hash(string(x)); %#ok<AGROW>
end
for mode = ["FUSED","RGB_ONLY","THERMAL_ONLY"]
    E = det.events(ScoreMode=mode);
    for e = reshape(E, 1, []), parts(end+1, 1) = flat(e); end %#ok<AGROW>
    for e = reshape(E, 1, [])
        for r = reshape(e.evidence_refs, 1, [])
            H = det.evidence(r.ref_id);
            parts(end+1, 1) = r.ref_id + flat(rmfield(H, 'crop')) + hash(compose("%d", double(H.crop(:)))); %#ok<AGROW>
        end
    end
end
d = hash(parts);
end

function s = flat(x)
%FLAT Full-precision text of a nested value, in field order.
if isstruct(x)
    s = ""; for k = 1:numel(x), for f = string(fieldnames(x))', s = s + f + ":" + flat(x(k).(f)) + ";"; end, end
elseif isnumeric(x) || islogical(x)
    s = strjoin(compose("%.17g", double(x(:))), ",");
else
    s = strjoin(string(x(:)), ",");
end
end

function d = hash(x)
d = string(mgv2.eval.sha256(char(strjoin(string(x(:)), newline))));
end
