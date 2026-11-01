classdef AnomalyDetector < handle
    %ANOMALYDETECTOR Interpretable multimodal SUSPECTED-anomaly detector on PUBLIC samples only (V2-006). SIMULATED.
    %   det = mgv2.detect.AnomalyDetector(world, missionCfg)
    %   det = mgv2.detect.AnomalyDetector(world, missionCfg, Config=cfg)
    %   det.attach(sensorSystem)    subscribe to every emitted public sample (or call det.ingest(sample))
    %   E = det.events()            SUSPECTED events (mg-v2-detector/1.0, mgv2.detect.validateEvent)
    %   T = det.trackTable()        all association tracks with features and scores (public)
    %   R = det.evidence(ref_id)    retained evidence record (exact frame reference + crop)
    %   Q = det.landmarkResiduals() georegistration check on the PUBLIC calibration landmarks
    %
    %   Inputs are restricted by contract (mgv2.detect.contract): validated mg-v2-sensors/1.0 samples, the
    %   public V2-003 terrain/landmarks and run_id/dt of the mission. The constructor rejects truth fields and
    %   objects in its inputs (mgv2.sensors.assertPublic); there is no argument through which scenario truth,
    %   forward-model features or evaluator data could enter.
    %
    %   Ingest policy (each sample, logged in det.Log):
    %     INVALID_SAMPLE      sample.valid false: no candidates; invalid_reason kept (no imputation)
    %     RUN_MISMATCH        run_id differs from the mission
    %     TIMESTAMP_MISMATCH  |t_s - tick_id * dt| > timing.timestamp_tolerance_s
    %     STALE_OR_DUPLICATE  tick_id not newer than the last accepted tick of that sensor
    %     STALE_DATA          tick_id older than the detector clock by more than timing.tolerance_ticks
    %   Camera frames -> mgv2.detect.frameCandidates (own intrinsics/extrinsics, public terrain) -> greedy
    %   nearest association (gate_m, one observation per track per frame) -> merge (merge_m, older id kept).
    %   LiDAR scans -> height above the public terrain on a grid (terrain context only, not scored).
    %   Navigation samples are logged; georegistration uses each camera sample's own T_world_sensor.

    properties (SetAccess = private)
        Config; Fingerprint; RunId; ScenarioId; Dt
        Log               % table: one row per ingested sample
        CurrentTick = -1  % detector clock: newest accepted tick_id
    end
    properties (Access = private)
        World; Landmarks
        LastTick          % struct sensor_id -> last accepted tick
        Ob                % observations (struct of column vectors)
        Tr                % tracks (struct of column vectors)
        Looks             % valid camera frames: modality (1 RGB, 2 thermal), footprint
        Ev                % containers.Map obs number -> evidence record
        Lg                % LiDAR grid accumulator
    end
    properties (Constant)
        Modalities = ["RGB_NADIR","THERMAL_LWIR"]
    end

    methods
        function det = AnomalyDetector(world, missionCfg, opts)
            arguments
                world struct
                missionCfg struct
                opts.Config struct = mgv2.detect.defaultDetectorConfig()
            end
            mgv2.sensors.assertPublic(rmfield(world, intersect(fieldnames(world), {'V','F','Z','vertex_rgb','material_weights','x','y'})), "world");
            mgv2.sensors.assertPublic(missionCfg, "missionConfig");
            det.Config = mgv2.detect.validateDetectorConfig(opts.Config);
            det.Fingerprint = det.Config.parameter_hash;
            det.RunId = string(missionCfg.run_id); det.ScenarioId = string(missionCfg.scenario_id); det.Dt = missionCfg.dt_s;
            det.World = struct('x', world.x, 'y', world.y, 'Z', world.Z);          % geometry only
            det.Landmarks = world.landmarks;
            det.LastTick = struct('RGB_NADIR', -1, 'THERMAL_LWIR', -1, 'LIDAR_TERRAIN', -1, 'VIRTUAL_GNSS_INS', -1);
            z = zeros(0, 1);
            det.Ob = struct('track', z, 'mod', z, 'frame', strings(0, 1), 'tick', z, 't', z, 'pose', z, 'x', z, 'y', z, 'z', z, ...
                'sigma', z, 'strength', z, 'polarity', z, 'diameter', z, 'u', z, 'v', z);
            det.Tr = struct('no', z, 'alive', false(0, 1), 'x', z, 'y', z, 'z', z, 'sigma', z, 'merged_into', z);
            det.Looks = struct('mod', z, 'tick', z, 'fp', {cell(0, 1)});
            det.Ev = containers.Map('KeyType', 'double', 'ValueType', 'any');
            c = det.Config.lidar.cell_m; nx = ceil((world.x(end) - world.x(1)) / c); ny = ceil((world.y(end) - world.y(1)) / c);
            det.Lg = struct('x0', world.x(1), 'y0', world.y(1), 'c', c, 'n', zeros(ny, nx), 's', zeros(ny, nx), 's2', zeros(ny, nx), 'mx', -inf(ny, nx));
            det.Log = table('Size', [0 7], 'VariableTypes', ["string","string","uint64","double","string","double","double"], ...
                'VariableNames', ["sensor_id","frame_id","tick_id","t_s","outcome","n_candidates","proc_ms"]);
        end

        function attach(det, sensorSystem)
            sensorSystem.subscribe(@(s) det.ingest(s));
        end

        function outcome = ingest(det, s)
            %INGEST Validate, time-check and process one public sample. Returns the logged outcome string.
            mgv2.sensors.validateSample(s);                 % schema + truth firewall (throws mgv2:TruthLeak)
            t0 = tic; nC = 0; id = char(s.sensor_id); tk = double(s.tick_id); tol = det.Config.timing;
            if s.run_id ~= det.RunId
                outcome = "RUN_MISMATCH";
            elseif abs(s.t_s - tk * det.Dt) > tol.timestamp_tolerance_s
                outcome = "TIMESTAMP_MISMATCH";
            elseif tk <= det.LastTick.(id)
                outcome = "STALE_OR_DUPLICATE";
            elseif tk < det.CurrentTick - tol.tolerance_ticks
                outcome = "STALE_DATA";
            else
                det.LastTick.(id) = tk; det.CurrentTick = max(det.CurrentTick, tk);
                if ~s.valid
                    outcome = "INVALID_SAMPLE";
                else
                    outcome = "ACCEPTED";
                    switch s.sensor_id
                        case {"RGB_NADIR","THERMAL_LWIR"}, nC = det.processCamera(s);
                        case "LIDAR_TERRAIN", det.processLidar(s);
                    end
                end
            end
            det.Log(end+1, :) = {s.sensor_id, s.frame_id, s.tick_id, s.t_s, outcome, nC, 1e3 * toc(t0)};
        end

        function T = trackTable(det)
            %TRACKTABLE All live tracks with per-modality looks, detections, strengths, supports and scores.
            c = det.Config; tr = det.Tr; live = find(tr.alive); n = numel(live); ob = det.Ob;
            T = table('Size', [n 0]);
            T.track_no = tr.no(live); T.x_m = tr.x(live); T.y_m = tr.y(live); T.z_m = tr.z(live); T.sigma_m = tr.sigma(live);
            looks = zeros(n, 2); detF = zeros(n, 2); str = nan(n, 2); nObs = zeros(n, 2); pol = zeros(n, 1);
            ft = inf(n, 1); lt = -inf(n, 1);
            for k = 1:size(det.Looks.mod, 1)
                fp = det.Looks.fp{k}; in = inpolygon(T.x_m, T.y_m, fp(:,1), fp(:,2));
                looks(in, det.Looks.mod(k)) = looks(in, det.Looks.mod(k)) + 1;
            end
            ref = [c.rgb.z_reference, c.thermal.dT_reference_K];
            sup = nan(n, 2);
            for i = 1:n
                j = find(ob.track == T.track_no(i));
                ft(i) = min(ob.tick(j)); lt(i) = max(ob.tick(j));
                for m = 1:2
                    q = j(ob.mod(j) == m); nObs(i, m) = numel(q);
                    if isempty(q), continue; end
                    detF(i, m) = numel(unique(ob.frame(q))); str(i, m) = median(ob.strength(q));
                    if m == 2, pol(i) = sign(sum(ob.polarity(q) .* ob.strength(q))); end
                    looks(i, m) = max(looks(i, m), detF(i, m));          % a detecting frame is a look
                    sup(i, m) = min(detF(i, m) / looks(i, m), 1) * mean(min(ob.strength(q) / ref(m), 1));
                end
                for m = 1:2, if looks(i, m) > 0 && isnan(sup(i, m)), sup(i, m) = 0; end, end
            end
            T.n_obs_rgb = nObs(:,1); T.n_obs_thermal = nObs(:,2);
            T.looks_rgb = looks(:,1); T.looks_thermal = looks(:,2); T.det_frames_rgb = detF(:,1); T.det_frames_thermal = detF(:,2);
            T.rgb_contrast_z = str(:,1); T.thermal_deviation_K = str(:,2); T.thermal_polarity = pol;
            T.support_rgb = sup(:,1); T.support_thermal = sup(:,2);
            T.score_fused = mean(sup, 2, 'omitnan'); T.score_rgb = sup(:,1); T.score_thermal = sup(:,2);
            T.first_tick = ft; T.last_tick = lt; T.first_t_s = ft * det.Dt; T.last_t_s = lt * det.Dt;
            [T.lidar_returns, T.lidar_height_m, T.lidar_roughness_m] = det.lidarContext(T.x_m, T.y_m);
            T.known_landmark = strings(n, 1);
            for q = 1:numel(det.Landmarks)
                L = det.Landmarks(q); near = hypot(T.x_m - L.xy(1), T.y_m - L.xy(2)) <= L.radius_m + c.landmark_exclusion_m;
                T.known_landmark(near) = L.id;
            end
        end

        function E = events(det, opts)
            %EVENTS SUSPECTED events from the current tracks (stable ids: SUS-<track number>).
            %   E = det.events()                              frozen config score_mode and threshold
            %   E = det.events(ScoreMode="RGB_ONLY", Threshold=0.4)   study/baseline use only
            arguments
                det
                opts.ScoreMode (1,1) string = ""
                opts.Threshold double = []
            end
            c = det.Config; mode = opts.ScoreMode; if mode == "", mode = c.score_mode; end
            thr = opts.Threshold; if isempty(thr), thr = c.event.score_threshold.(char(mode)); end
            T = det.trackTable();
            [keep, sc] = mgv2.detect.selectEvents(T, mode, thr, c);
            E = repmat(det.emptyEvent(), 0, 1);
            for i = reshape(find(keep), 1, [])
                r = T(i, :);
                hasR = r.n_obs_rgb > 0 && mode ~= "THERMAL_ONLY"; hasT = r.n_obs_thermal > 0 && mode ~= "RGB_ONLY";
                if hasR && hasT, basis = "FUSED_RGB_THERMAL"; elseif hasR, basis = "SINGLE_CHANNEL_RGB"; else, basis = "SINGLE_CHANNEL_THERMAL"; end
                E(end+1, 1) = det.makeEvent(r, sc(i), basis, mode); %#ok<AGROW>
            end
        end

        function R = evidence(det, refId)
            %EVIDENCE Retained evidence record for an evidence_refs.ref_id (error if not retained).
            k = sscanf(char(refId), 'OBS-%d');
            if isempty(k) || ~isKey(det.Ev, k), error('mgv2:EvidenceMissing', 'Evidence %s is not retained.', refId); end
            R = det.Ev(k);
        end

        function Q = landmarkResiduals(det)
            %LANDMARKRESIDUALS Distance between each public calibration landmark and the nearest track (m).
            T = det.trackTable(); n = numel(det.Landmarks);
            Q = table(strings(n, 1), zeros(n, 2), nan(n, 2), nan(n, 1), zeros(n, 1), 'VariableNames', ...
                ["landmark_id","landmark_xy_m","estimated_xy_m","error_m","n_obs"]);
            for q = 1:n
                L = det.Landmarks(q); Q.landmark_id(q) = L.id; Q.landmark_xy_m(q, :) = L.xy;
                j = find(T.known_landmark == L.id);
                if isempty(j), continue; end
                [~, b] = max(T.n_obs_rgb(j) + T.n_obs_thermal(j)); j = j(b);
                Q.estimated_xy_m(q, :) = [T.x_m(j) T.y_m(j)]; Q.error_m(q) = hypot(T.x_m(j) - L.xy(1), T.y_m(j) - L.xy(2));
                Q.n_obs(q) = T.n_obs_rgb(j) + T.n_obs_thermal(j);
            end
        end
    end

    methods (Access = private)
        function nC = processCamera(det, s)
            c = det.Config; m = 1 + (s.sensor_id == "THERMAL_LWIR");
            if size(s.footprint_enu_m, 1) >= 3
                det.Looks.mod(end+1, 1) = m; det.Looks.tick(end+1, 1) = double(s.tick_id); det.Looks.fp{end+1, 1} = s.footprint_enu_m;
            end
            C = mgv2.detect.frameCandidates(s, det.World, c); nC = numel(C.u_px);
            if nC == 0, return; end
            used = false(numel(det.Tr.no), 1); touched = zeros(0, 1); chk = "";
            for i = 1:nC
                live = find(det.Tr.alive & ~used);
                d = hypot(det.Tr.x(live) - C.x_m(i), det.Tr.y(live) - C.y_m(i));
                [dm, b] = min(d);
                if ~isempty(dm) && dm <= c.association.gate_m
                    k = live(b);
                else
                    k = numel(det.Tr.no) + 1;
                    det.Tr.no(k, 1) = k; det.Tr.alive(k, 1) = true; det.Tr.x(k, 1) = C.x_m(i); det.Tr.y(k, 1) = C.y_m(i);
                    det.Tr.z(k, 1) = C.z_m(i); det.Tr.sigma(k, 1) = C.sigma_m(i); det.Tr.merged_into(k, 1) = 0; used(k, 1) = false;
                end
                used(k) = true; touched(end+1, 1) = k; %#ok<AGROW>
                o = numel(det.Ob.track) + 1;
                vals = {k, m, s.frame_id, double(s.tick_id), s.t_s, double(s.pose_id), C.x_m(i), C.y_m(i), C.z_m(i), C.sigma_m(i), ...
                    C.strength(i), C.polarity(i), C.diameter_m(i), C.u_px(i), C.v_px(i)};
                f = fieldnames(det.Ob);
                for q = 1:numel(f), det.Ob.(f{q})(o, 1) = vals{q}; end
                if chk == "", chk = mgv2.sensors.checksum(mgv2.sensors.SensorSystem.payload(s)); end
                det.Ev(o) = det.makeEvidence(s, C, i, o, chk);
            end
            for k = reshape(unique(touched), 1, []), det.updateTrack(k); end
            for k = reshape(unique(touched), 1, []), if det.Tr.alive(k), det.mergeNear(k); end, end
            for k = reshape(unique(det.Ob.track(end - nC + 1:end)), 1, []), det.pruneEvidence(k); end
        end

        function updateTrack(det, k)
            j = det.Ob.track == k; w = 1 ./ det.Ob.sigma(j) .^ 2; sw = sum(w);
            x = sum(w .* det.Ob.x(j)) / sw; y = sum(w .* det.Ob.y(j)) / sw;
            scat = sum(w .* ((det.Ob.x(j) - x) .^ 2 + (det.Ob.y(j) - y) .^ 2)) / sw / 2;
            det.Tr.x(k) = x; det.Tr.y(k) = y; det.Tr.z(k) = sum(w .* det.Ob.z(j)) / sw;
            det.Tr.sigma(k) = sqrt(1 / sw + scat);        % per-axis 1-sigma: model term + observed spread (conservative)
        end

        function mergeNear(det, k)
            live = find(det.Tr.alive); live = live(live ~= k);
            d = hypot(det.Tr.x(live) - det.Tr.x(k), det.Tr.y(live) - det.Tr.y(k));
            for j = reshape(live(d <= det.Config.association.merge_m), 1, [])
                keep = min(j, k); drop = max(j, k);
                det.Ob.track(det.Ob.track == drop) = keep; det.Tr.alive(drop) = false; det.Tr.merged_into(drop) = keep;
                det.updateTrack(keep); det.pruneEvidence(keep);
                k = keep;
            end
        end

        function pruneEvidence(det, k)
            K = det.Config.evidence.max_per_modality;
            for m = 1:2
                j = find(det.Ob.track == k & det.Ob.mod == m);
                j = j(arrayfun(@(o) isKey(det.Ev, o), j));
                if numel(j) <= K, continue; end
                [~, ord] = sort(det.Ob.strength(j), 'descend');
                for o = reshape(j(ord(K+1:end)), 1, []), remove(det.Ev, o); end
            end
        end

        function R = makeEvidence(det, s, C, i, o, chk)
            h = det.Config.evidence.crop_half_px; u = round(C.u_px(i)); v = round(C.v_px(i));
            r1 = max(1, v - h); r2 = min(s.image_height, v + h); c1 = max(1, u - h); c2 = min(s.image_width, u + h);
            if s.sensor_id == "RGB_NADIR", crop = s.image_rgb_uint8(r1:r2, c1:c2, :); else, crop = s.temperature_K(r1:r2, c1:c2); end
            R = struct('ref_id', sprintf("OBS-%d", o), 'frame_id', s.frame_id, 'sensor_id', s.sensor_id, 'run_id', s.run_id, ...
                'tick_id', s.tick_id, 'pose_id', s.pose_id, 't_s', s.t_s, 'sample_checksum', chk, ...
                'sensor_model_version', s.sensor_model_version, 'u_px', C.u_px(i), 'v_px', C.v_px(i), 'strength', C.strength(i), ...
                'strength_unit', det.unitOf(s.sensor_id), 'x_m', C.x_m(i), 'y_m', C.y_m(i), 'crop', crop, 'crop_origin_px', [c1 r1], ...
                'crop_mask', s.valid_pixel_mask(r1:r2, c1:c2));
        end

        function processLidar(det, s)
            P = s.points_enu_m(s.valid_ray_mask, :);
            if isempty(P), return; end
            h = P(:,3) - mgv2.scene.heightAt(det.World, P(:,1), P(:,2)); ok = isfinite(h); P = P(ok, :); h = h(ok);
            g = det.Lg; j = floor((P(:,1) - g.x0) / g.c) + 1; i = floor((P(:,2) - g.y0) / g.c) + 1;
            in = i >= 1 & i <= size(g.n, 1) & j >= 1 & j <= size(g.n, 2); ix = sub2ind(size(g.n), i(in), j(in)); h = h(in);
            g.n = g.n + reshape(accumarray(ix, 1, [numel(g.n) 1]), size(g.n));
            g.s = g.s + reshape(accumarray(ix, h, [numel(g.n) 1]), size(g.n));
            g.s2 = g.s2 + reshape(accumarray(ix, h .^ 2, [numel(g.n) 1]), size(g.n));
            g.mx = max(g.mx, reshape(accumarray(ix, h, [numel(g.n) 1], @max, -inf), size(g.n)));
            det.Lg = g;
        end

        function [n, hmax, rough] = lidarContext(det, x, y)
            g = det.Lg; R = det.Config.lidar.context_radius_m; k = numel(x); n = zeros(k, 1); hmax = nan(k, 1); rough = nan(k, 1);
            [J, I] = meshgrid(1:size(g.n, 2), 1:size(g.n, 1)); cx = g.x0 + (J - 0.5) * g.c; cy = g.y0 + (I - 0.5) * g.c;
            for q = 1:k
                sel = abs(cx - x(q)) <= R & abs(cy - y(q)) <= R; sel(sel) = hypot(cx(sel) - x(q), cy(sel) - y(q)) <= R;
                N = sum(g.n(sel)); n(q) = N;
                if N > 0
                    mu = sum(g.s(sel)) / N; hmax(q) = max(g.mx(sel)); rough(q) = sqrt(max(sum(g.s2(sel)) / N - mu ^ 2, 0));
                end
            end
        end

        function e = makeEvent(det, r, score, basis, mode)
            c = mgv2.detect.contract(); cf = det.Config; ob = det.Ob;
            j = find(ob.track == r.track_no); [~, o] = sort(ob.tick(j)); j = j(o);
            refs = j(arrayfun(@(q) isKey(det.Ev, q), j));
            er = repmat(struct('ref_id', "", 'frame_id', "", 'sensor_id', "", 'tick_id', uint64(0), 'pose_id', uint64(0), 't_s', 0, ...
                'sample_checksum', ""), numel(refs), 1);
            for q = 1:numel(refs)
                R = det.Ev(refs(q));
                er(q) = struct('ref_id', R.ref_id, 'frame_id', R.frame_id, 'sensor_id', R.sensor_id, 'tick_id', R.tick_id, ...
                    'pose_id', R.pose_id, 't_s', R.t_s, 'sample_checksum', R.sample_checksum);
            end
            miss = strings(0, 1);
            if r.looks_rgb == 0, miss(end+1) = "RGB_NADIR: no valid frame covered this location"; end
            if r.looks_thermal == 0, miss(end+1) = "THERMAL_LWIR: no valid frame covered this location"; end
            if r.lidar_returns == 0, miss(end+1) = "LIDAR_TERRAIN: no valid returns within context radius"; end
            ctx = "UNAVAILABLE"; if r.lidar_returns > 0, ctx = "FLAT"; if r.lidar_height_m > cf.lidar.protrusion_m, ctx = "PROTRUDING_OBJECT"; end, end
            nobs = r.n_obs_rgb + r.n_obs_thermal; us = c.uncertainty_statuses(1 + (nobs == 1));
            e = struct('schema_version', c.schema_version, 'event_id', sprintf("SUS-%05d", r.track_no), 'status', "SUSPECTED", ...
                'simulated', true, 'detection_basis', basis, 'x_est_m', r.x_m, 'y_est_m', r.y_m, 'z_est_m', r.z_m, ...
                'position_frame', "ENU local virtual frame (m), observation-derived", 'uncertainty_m', r.sigma_m, ...
                'uncertainty_status', us, 'model_score', score, 'score_kind', c.score_kind, ...
                'score_components', struct('score_mode', mode, 'rgb_support', r.support_rgb, 'thermal_support', r.support_thermal), ...
                'features', struct('rgb_contrast_z', r.rgb_contrast_z, 'thermal_deviation_K', r.thermal_deviation_K, ...
                    'thermal_polarity', r.thermal_polarity, 'lidar_height_above_terrain_m', r.lidar_height_m, ...
                    'lidar_roughness_m', r.lidar_roughness_m, 'lidar_returns', r.lidar_returns, 'lidar_context', ctx), ...
                'modality_validity', struct('RGB_NADIR', struct('valid_looks', r.looks_rgb, 'detecting_frames', r.det_frames_rgb), ...
                    'THERMAL_LWIR', struct('valid_looks', r.looks_thermal, 'detecting_frames', r.det_frames_thermal), ...
                    'LIDAR_TERRAIN', struct('returns_in_context', r.lidar_returns)), ...
                'missing_modalities', miss, 'first_tick', r.first_tick, 'last_tick', r.last_tick, 'first_t_s', r.first_t_s, ...
                'last_t_s', r.last_t_s, 'n_observations', nobs, 'evidence_frame_ids', unique(ob.frame(j), 'stable'), ...
                'evidence_refs', er, 'detector_id', cf.detector_id, 'detector_version', cf.detector_version, ...
                'detector_fingerprint', det.Fingerprint, 'run_id', det.RunId, 'scenario_id', det.ScenarioId, 'label_text', c.label_text);
        end

        function e = emptyEvent(det)
            r = table(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NaN, NaN, 0, NaN, NaN, 0, 0, 0, 0, 0, NaN, NaN, 0, 'VariableNames', ...
                ["track_no","x_m","y_m","z_m","sigma_m","n_obs_rgb","n_obs_thermal","looks_rgb","looks_thermal","det_frames_rgb", ...
                "det_frames_thermal","rgb_contrast_z","thermal_deviation_K","thermal_polarity","support_rgb","support_thermal", ...
                "first_tick","last_tick","first_t_s","last_t_s","lidar_returns","lidar_height_m","lidar_roughness_m","score_fused"]);
            e = det.makeEvent(r, 0, "FUSED_RGB_THERMAL", "FUSED");
        end
    end

    methods (Static)
        function u = unitOf(id)
            if id == "RGB_NADIR", u = "contrast z (dimensionless, robust-MAD units)"; else, u = "K (local apparent-temperature deviation)"; end
        end
    end
end
