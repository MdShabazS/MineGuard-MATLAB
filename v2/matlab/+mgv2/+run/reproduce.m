function r = reproduce(pkg)
%REPRODUCE Simulate a package's recorded configuration again, headless, and compare it with the package. SIMULATION ONLY.
%   r = mgv2.run.reproduce(pkg)      pkg from mgv2.run.verifyPackage
%   This is the determinism check, separate from replay: replay shows the recorded data and simulates nothing, while
%   this runs the V2-002 engine and V2-005 sensors again with the same world, configuration and seed, to the same last
%   tick (and the same abort, if the run was aborted), and compares:
%     poses   - every recorded PoseSample row, bit for bit (isequaln)
%     samples - mgv2.run.digest of every sample against samples/index.csv
%     end     - final phase and fault code
%   r: match (all equal), poses_equal, samples_compared, samples_equal, first_mismatch, end_equal, world_equal.
%   Operator pauses do not change a simulation, so they need not be reproduced.
w = mgv2.scene.buildWorld(); r = struct('world_equal', mgv2.run.digest(w) == string(pkg.manifest.world_digest));
c = pkg.config; m = c.mission; e = pkg.manifest.end_state;
sys = mgv2.sensors.SensorSystem(w, m, SensorConfig=c.sensors, Environment=c.environment);
eng = mgv2.engine.MissionEngine(m, mgv2.scene.terrainProvider(w));
rec = mgv2.run.Recorder(); sys.subscribe(@(s) rec.add(s)); sys.attach(eng);
P = pkg.poses; last = P.tick_id(end);
eng.start();
while eng.TickId < last && eng.step(), end
if string(e.phase) == "ABORTED", eng.abort(string(e.fault_message), string(e.fault_code)); end
r.poses_equal = isequaln(eng.poseLog(), P);
idx = pkg.index; n = 0; nEq = 0; r.first_mismatch = "";
for sid = mgv2.sensors.SensorSystem.Order
    C = rec.samples(sid); rows = find(idx.sensor_id == sid);
    for k = 1:max(numel(C), numel(rows))
        n = n + 1;
        if k <= numel(C) && k <= numel(rows) && mgv2.run.digest(C{k}) == idx.sample_sha256(rows(k)), nEq = nEq + 1;
        elseif r.first_mismatch == "", r.first_mismatch = sid + " #" + k;
        end
    end
end
r.samples_compared = n; r.samples_equal = nEq;
r.end_equal = eng.Phase == string(e.phase) && eng.FaultCode == string(e.fault_code);
r.match = r.world_equal && r.poses_equal && n == nEq && r.end_equal;
end
