function S = runSurvey(P, opts)
%RUNSURVEY Headless simulated drone survey of an operator-drawn field (V22-T11). SIMULATION ONLY.
%   S = mgv22.field.runSurvey(P)
%   S = mgv22.field.runSurvey(P, TargetCount=6, Seed=1, VisibleFraction=0.75, MaxTicks=inf, CoverageCellM=1, Progress=fh)
%   P     plan from mgv22.field.surveyPlan; uses only P.pub (V2.1 PublicMissionConfig), P.poly_enu (N-by-2 ENU m),
%         P.area_m2 and P.field_anchor_lla.
%   Pipeline (as mgv2.eval.runScenario): MissionEngine -> SensorSystem (forward model gets the PRIVATE surface
%   features) -> mgv2.detect.AnomalyDetector, which sees only public samples. Synthetic targets are RANDOM
%   placements inside the field (mgv21.placement.lockScenario); their truth is used only for S.evaluation.
%   Progress, if given, is called as Progress(tick, estTicks) every 100 ticks.
%   S public part: events (x_est_m, y_est_m, model_score, lat, lon, event_id), coverage (x, y, count, cell_m,
%   in_field, frac_covered, low_mask), ticks, sim_s, phase, stopped_early, wall_s, label, no_detection_text.
%   S.evaluation is PRIVATE (evaluation toggle only): R, truth_ll, detection_ci, tp_visible, n_visible, fa, curve.
%   Every mark is a "suspected anomaly" from simulation; nothing here measures real detection capability.
arguments
    P struct
    opts.TargetCount (1,1) double {mustBeInteger, mustBeBetween(opts.TargetCount, 0, 30)} = 6
    opts.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 1
    opts.VisibleFraction (1,1) double {mustBeBetween(opts.VisibleFraction, 0, 1)} = 0.75
    opts.MaxTicks (1,1) double {mustBePositive} = inf
    opts.CoverageCellM (1,1) double {mustBePositive, mustBeFinite} = 1
    opts.Progress = []
end
if ~all(isfield(P, {'pub', 'poly_enu', 'area_m2', 'field_anchor_lla'}))
    error('mgv22:InvalidPlan', 'P needs pub, poly_enu, area_m2 and field_anchor_lla.');
end
if ~isempty(opts.Progress) && ~isa(opts.Progress, 'function_handle')
    error('mgv22:InvalidPlan', 'Progress must be empty or a function handle.');
end
pub = P.pub; poly = double(P.poly_enu);
w = mgv22.wording();

% 1. world and private synthetic targets
world = mgv21.scenario.buildWorld(pub);
if opts.TargetCount == 0
    spec = mgv21.placement.defaultPlacement("NONE");
else
    spec = mgv21.placement.defaultPlacement("RANDOM");
    spec.count = opts.TargetCount; spec.seed = opts.Seed; spec.visible_fraction = opts.VisibleFraction;
end
priv = mgv21.placement.lockScenario(spec, pub, world);

% 2. public pipeline
env = mgv2.sensors.defaultEnvironment(pub.environment_mode);
eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(world));
sys = mgv2.sensors.SensorSystem(world, pub.mission, Environment=env, SurfaceFeatures=priv.surface_features);
det = mgv2.detect.AnomalyDetector(world, pub.mission);
det.attach(sys);

cell_m = opts.CoverageCellM;
xs = (min(poly(:, 1)) - 2 + cell_m / 2):cell_m:(max(poly(:, 1)) + 2);
ys = (min(poly(:, 2)) - 2 + cell_m / 2):cell_m:(max(poly(:, 2)) + 2);
[GX, GY] = meshgrid(xs, ys);
count = zeros(numel(ys), numel(xs));
sys.subscribe(@onSample);
sys.attach(eng);

estTicks = estimateTicks(pub, poly, pub.mission);
if isfinite(opts.MaxTicks), estTicks = min(estTicks, opts.MaxTicks); end
t0 = tic;
eng.start();
while eng.TickId < opts.MaxTicks && eng.step()
    if ~isempty(opts.Progress) && mod(eng.TickId, 100) == 0
        opts.Progress(eng.TickId, estTicks);
    end
end
wall = toc(t0);
stoppedEarly = ~eng.isTerminal();
if stoppedEarly, eng.abort("survey stopped at MaxTicks", "MAX_TICKS"); end

% 3. public events
E = det.events();
n = numel(E);
if n == 0
    ev = repmat(struct('event_id', "", 'x_est_m', 0, 'y_est_m', 0, 'model_score', 0, 'lat', 0, 'lon', 0), 0, 1);
else
    xy = [[E.x_est_m]' [E.y_est_m]'];
    lla = mgv22.geo.enuToWgs84([xy zeros(n, 1)], P.field_anchor_lla);
    ev = repmat(struct('event_id', "", 'x_est_m', 0, 'y_est_m', 0, 'model_score', 0, 'lat', 0, 'lon', 0), n, 1);
    for k = 1:n
        if isfield(E, 'event_id'), ev(k).event_id = string(E(k).event_id); end
        ev(k).x_est_m = E(k).x_est_m; ev(k).y_est_m = E(k).y_est_m; ev(k).model_score = E(k).model_score;
        ev(k).lat = lla(k, 1); ev(k).lon = lla(k, 2);
    end
end

inField = inpolygon(GX, GY, poly(:, 1), poly(:, 2));
covg = struct('x', xs, 'y', ys, 'count', count, 'cell_m', cell_m, 'in_field', inField, ...
    'frac_covered', nnz(count >= 1 & inField) / max(nnz(inField), 1), 'low_mask', count < 2 & inField);

% 4. PRIVATE evaluation (only for the evaluation toggle)
truth = priv.truth;
R = mgv21.evaluation.evaluateRun(ev, truth, eng.Phase);
T = truth.targets; nT = height(T);
matched = false(nT, 1); matched(R.matched_target_index) = true;
visible = T.surface_signature == "VISIBLE_DISTURBANCE";
nVisible = nnz(visible); tpVisible = nnz(matched & visible);
if nVisible > 0
    [lo, hi] = mgv22.evaluation.clopperPearson(tpVisible, nVisible);
else
    lo = NaN; hi = NaN;
end
if nT > 0
    tl = mgv22.geo.enuToWgs84([T.x_east_m T.y_north_m zeros(nT, 1)], P.field_anchor_lla);
else
    tl = zeros(0, 3);
end
truth_ll = table(tl(:, 1), tl(:, 2), double(T.x_east_m), double(T.y_north_m), string(T.surface_signature), matched, ...
    'VariableNames', ["lat", "lon", "x_east_m", "y_north_m", "surface_signature", "matched"]);
fa = mgv22.evaluation.falseAlarmRate(R.FP, P.area_m2);
if n > 0
    isTP = false(n, 1); isTP(R.matched_event_index) = true;
    curve = mgv22.evaluation.detectionCurve([ev.model_score], isTP, nT, P.area_m2);
else
    curve = [];
end
evaluation = struct('R', R, 'truth_ll', truth_ll, 'detection_ci', [lo hi], 'tp_visible', tpVisible, ...
    'n_visible', nVisible, 'fa', fa, 'curve', curve);

% 5. output; the public parts carry no truth
mgv21.scenario.assertPublic(ev, "events");
mgv21.scenario.assertPublic(covg, "coverage");
S = struct('events', ev, 'coverage', covg, 'ticks', eng.TickId, 'sim_s', eng.time(), 'phase', string(eng.Phase), ...
    'stopped_early', stoppedEarly, 'wall_s', wall, 'label', w.suspected, 'no_detection_text', w.no_detection, ...
    'evaluation', evaluation);

    function onSample(s)
        if ~(isfield(s, 'sensor_id') && s.sensor_id == "RGB_NADIR" && s.valid), return; end
        fp = s.footprint_enu_m;
        if size(fp, 1) < 3 || any(~isfinite(fp), 'all'), return; end
        ix = xs >= min(fp(:, 1)) & xs <= max(fp(:, 1));
        iy = ys >= min(fp(:, 2)) & ys <= max(fp(:, 2));
        if ~any(ix) || ~any(iy), return; end
        sub = inpolygon(GX(iy, ix), GY(iy, ix), fp(:, 1), fp(:, 2));
        count(iy, ix) = count(iy, ix) + sub;
    end
end

function est = estimateTicks(pub, poly, mission)
%ESTIMATETICKS Rough tick count for the progress display: lawnmower length / speed plus a fixed overhead.
dt = 0.05; if isfield(mission, 'dt_s'), dt = mission.dt_s; end
spacing = 6; speed = 2;
if isfield(pub, 'survey')
    if isfield(pub.survey, 'line_spacing_m'), spacing = pub.survey.line_spacing_m; end
    if isfield(pub.survey, 'speed_mps'), speed = pub.survey.speed_mps; end
end
area = polyarea(poly(:, 1), poly(:, 2));
perim = sum(hypot(diff([poly(:, 1); poly(1, 1)]), diff([poly(:, 2); poly(1, 2)])));
est = ceil(((area / spacing + perim) / speed + 60) / dt);
end
