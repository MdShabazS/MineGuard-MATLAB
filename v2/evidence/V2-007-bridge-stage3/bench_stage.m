function bench_stage(repo, outFile, planName, priority)
%BENCH_STAGE Windows benchmark matrix for the bridge on the published UI. Default scene only; no study stage runs.
%   bench_stage(repo, outFile, "paced", "normal")   paced 1x: UI_NULL, UI_R100, UI_R20, three alternating rounds
%   bench_stage(repo, outFile, "diag", "normal")    unpaced diagnostics: UI and headless R100, R20, three rounds
%   priority is the label recorded in each result: "normal" or "highqos". The runner applies it.
if nargin < 3, planName = "paced"; end
if nargin < 4, priority = "normal"; end
cd(repo); addpath(fullfile(repo, 'v2', 'matlab'));
[~, h] = system('git rev-parse HEAD'); head = string(strtrim(h));
plan = strings(0, 2);
for round = 1:3
    switch string(planName)
        case "paced", plan = [plan; ["UI_NULL" "1"]; ["UI_R100" "1"]; ["UI_R20" "1"]]; %#ok<AGROW>
        case "diag", plan = [plan; ["UI_R100" "0"]; ["UI_R20" "0"]; ["H_R100" "0"]; ["H_R20" "0"]]; %#ok<AGROW>
        otherwise, error('bench:plan', 'Unknown plan %s.', planName);
    end
end
for k = 1:size(plan, 1)
    c = plan(k, 1); rt = str2double(plan(k, 2));
    try
        started = string(datetime('now', 'TimeZone', 'UTC', 'Format', 'HH:mm:ss'));
        R = mgv2PerfRun(c, RealTime=rt); R.run_index = k; R.real_time = rt; R.sha = head; R.priority = string(priority); R.plan = string(planName);
        R.started_utc = started; R.finished_utc = string(datetime('now', 'TimeZone', 'UTC', 'Format', 'HH:mm:ss'));
        line = jsonencode(R);
        fprintf('%d %s rt=%g %s: x%.3f wall %.1f s worst %.0f ms\n', k, c, rt, priority, R.sim_to_wall, R.wall_s, R.worst_block_ms);
    catch ME
        line = jsonencode(struct('run_index', k, 'cond', c, 'real_time', rt, 'priority', string(priority), 'error', string(ME.identifier), 'message', string(ME.message)));
        fprintf('%d %s rt=%g: ERROR %s\n', k, c, rt, ME.message);
    end
    fid = fopen(outFile, 'a'); fprintf(fid, '%s\n', line); fclose(fid);
end
disp('DONE');
end
