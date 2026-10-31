function [app, runBundle, record] = mineguardDemo(scenario, varargin)
%MINEGUARDDEMO One-command MineGuard end-to-end demonstration (MG-015). SIMULATION ONLY.
%   mineguardDemo                    run the safe S0 fixture end to end and open the mission dashboard
%   mineguardDemo("GF-002")          run an MG-014 locked TRAIN/VALIDATION family (TEST is refused)
%   mineguardDemo(..., 'Play', true)            start replay automatically
%   mineguardDemo(..., 'ExportTo', folder)      also export verified CSV/MAT/JSON/PNG to folder
%   [app, runBundle, record] = mineguardDemo(...)
%
%   From the repository root:   addpath('matlab'); mineguardDemo
%   Steps: 1 scenario (MG-004), 2 fixed-grid route + virtual UAV poses + coverage (MG-005),
%   3 thermal [K] / EM [dimensionless] readings (MG-007), 4 frozen detector -> SUSPECTED events
%   (MG-009, observables only), 5 separate ground-truth evaluation (aggregate only), 6 redacted bundle,
%   then the MG-011 desktop replay. No hardware, flight controller or network is used.
if nargin < 1 || isempty(scenario), scenario = "S0"; end
p = inputParser; p.addParameter('Play', false); p.addParameter('ExportTo', ""); p.parse(varargin{:});
here = fileparts(mfilename('fullpath'));
addpath(here, fullfile(here, 'experiments'));
fprintf('\n=== MineGuard MATLAB demo — SIMULATION ONLY (synthetic data; not validated for real landmine detection or clearance) ===\n');
rel = mineguard.releaseInfo();
fprintf('%s %s | default planner: fixed grid | PPO: %s (see mineguardPPODemo)\n', rel.name, rel.version, rel.ppo_status);
config = mg015DemoConfig(scenario);
fprintf('[1/6] Scenario %s | seed %d | noise_seed %d | field %gx%g m | cell %g m | altitude %g m\n', config.scenario_id, ...
    config.seed, config.noise_seed, config.x_max_m - config.x_min_m, config.y_max_m - config.y_min_m, config.grid_spacing_m, config.altitude_m);
t0 = tic;
[runBundle, record] = mineguard.runExperiment(config);
fprintf('[2/6] Fixed-grid survey: %d poses, %.1f m, %.1f s simulated, coverage %.3f (%d/%d cells)\n', height(runBundle.poses), ...
    runBundle.coverage.distance_m, runBundle.coverage.mission_time_s, runBundle.coverage.coverage_fraction, ...
    runBundle.coverage.visited_valid_cells, runBundle.coverage.total_valid_cells);
th = runBundle.thermal_samples; em = runBundle.em_samples;
fprintf('[3/6] Sensors: thermal %d valid / %d (K, %.2f..%.2f) | EM %d valid / %d (dimensionless)\n', nnz(th.valid), height(th), ...
    min(th.temperature_K), max(th.temperature_K), nnz(em.valid), height(em));
fprintf('[4/6] Detector %s / %s (%s): %d SUSPECTED events\n', runBundle.provenance.method_name, runBundle.provenance.missing_modality_rule, ...
    runBundle.provenance.detector_model_version, height(runBundle.events));
if isfield(runBundle, 'result')
    r = runBundle.result;
    fprintf('[5/6] Aggregate synthetic evaluation (cell-level, %d evaluable cells): TP %d FP %d TN %d FN %d | precision %s recall %s F1 %s FPR %s\n', ...
        record.evaluable_cells, r.tp, r.fp, r.tn, r.fn, fmt(r.precision), fmt(r.recall), fmt(r.f1), fmt(r.false_alarm_rate));
end
if startsWith(string(config.scenario_id), "MG015-DEMO")
    fprintf('      NOTE: S0 is a DISPLAY FIXTURE (0.3 m altitude, 0.5 m cells); its numbers are NOT held-out performance.\n');
end
h = rel.heldout;
fprintf('      Locked held-out TEST (%s, %s/%s, run once): TP %d FP %d TN %d FN %d -> %s.\n', h.families, h.method, h.rule, ...
    h.tp, h.fp, h.tn, h.fn, h.verdict);
fprintf('[6/6] Redacted bundle validated; run_id %s; git %s; end-to-end %.1f s. Opening dashboard...\n', runBundle.provenance.run_id, ...
    runBundle.provenance.git_sha, toc(t0));
app = mineguard.app.openMissionApp(runBundle);
if strlength(string(p.Results.ExportTo)) > 0
    ok = app.exportRun(p.Results.ExportTo); fprintf('Export: %s\n', app.StatusText); if ~ok, warning('mineguard:ExportFailed', 'Export failed.'); end
end
if p.Results.Play, app.play(); end
fprintf('Dashboard ready: use Play Simulation / Pause / Step / Seek / Reset / Export. Only SUSPECTED events are shown.\n\n');
end

function s = fmt(v)
if isnan(v), s = "undefined"; else, s = sprintf('%.3f', v); end
end
