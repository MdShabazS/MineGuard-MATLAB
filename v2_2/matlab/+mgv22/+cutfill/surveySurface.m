function S = surveySurface(opts)
%SURVEYSURFACE Elevation surface from a SIMULATED drone LiDAR survey of the V2.1 field (V22-T9).
%   S = mgv22.cutfill.surveySurface()                        full TRAINING_FIELD_A survey, 1 m cells, cached in tempdir
%   S = mgv22.cutfill.surveySurface(Preset=..., MaxTicks=n, CellM=0.5, Cache=false)
%   Flies the V2.1 public mission headless (MissionEngine + SensorSystem), keeps the valid LIDAR_TERRAIN returns
%   (points_enu_m) and averages them per grid cell. Cells without returns are NaN (no extrapolation).
%   The result is SIMULATED TERRAIN of the virtual field, not BITM's real ground; it is cached only in tempdir
%   (never in Git). S: x, y (cell centres, ENU m), Z (ny-by-nx), count, cell_m, n_points, source, label,
%   preset_id, ticks, phase.
arguments
    opts.Preset (1,1) string = "TRAINING_FIELD_A"
    opts.MaxTicks (1,1) double {mustBePositive} = inf
    opts.CellM (1,1) double {mustBePositive} = 1
    opts.Cache (1,1) logical = true
end
key = sprintf('surface-v1_%s_c%g_t%g', opts.Preset, opts.CellM, opts.MaxTicks);   % bump v1 when the survey or world changes
file = fullfile(tempdir, "mineguard_v22_survey_" + regexprep(key, '[^A-Za-z0-9_]', '_') + ".mat");
if opts.Cache && isfile(file)
    c = load(file, 'S'); S = c.S; return
end
pub = mgv21.scenario.buildPublicMission(opts.Preset, mgv21.scenario.defaultSurvey(opts.Preset));
world = mgv21.scenario.buildWorld(pub);
sys = mgv2.sensors.SensorSystem(world, pub.mission);
pts = cell(0, 1);
sys.subscribe(@keep);
eng = mgv2.engine.MissionEngine(pub.mission, mgv2.scene.terrainProvider(world));
sys.attach(eng); eng.start();
while eng.TickId < opts.MaxTicks && eng.step(), end
P = vertcat(pts{:});
if isempty(P), error('mgv22:NoSurveyData', 'The simulated flight produced no LiDAR returns.'); end
poly = pub.mission.survey_polygon_enu_m; m = 10;                       % survey area plus a 10 m margin
lo = floor((min(poly) - m) / opts.CellM) * opts.CellM; hi = ceil((max(poly) + m) / opts.CellM) * opts.CellM;
x = lo(1) + opts.CellM / 2 : opts.CellM : hi(1); y = lo(2) + opts.CellM / 2 : opts.CellM : hi(2);
ix = floor((P(:, 1) - lo(1)) / opts.CellM) + 1; iy = floor((P(:, 2) - lo(2)) / opts.CellM) + 1;
in = ix >= 1 & ix <= numel(x) & iy >= 1 & iy <= numel(y);
sz = [numel(y) numel(x)];
count = accumarray([iy(in) ix(in)], 1, sz);
Z = accumarray([iy(in) ix(in)], P(in, 3), sz) ./ count;
Z(count == 0) = NaN;
S = struct('x', x, 'y', y, 'Z', Z, 'count', count, 'cell_m', opts.CellM, 'n_points', nnz(in), ...
    'source', "SIMULATED_LIDAR", 'label', "SIMULATED TERRAIN (not BITM ground)", 'preset_id', string(opts.Preset), ...
    'ticks', eng.TickId, 'phase', string(eng.Phase));
if opts.Cache, save(file, 'S'); end

    function keep(s)
        if string(s.sensor_id) ~= "LIDAR_TERRAIN" || ~isfield(s, 'points_enu_m') || isempty(s.points_enu_m), return; end
        p = s.points_enu_m;
        if isfield(s, 'valid_ray_mask') && numel(s.valid_ray_mask) == size(p, 1), p = p(s.valid_ray_mask(:), :); end
        pts{end+1, 1} = p(all(isfinite(p), 2), :);
    end
end
