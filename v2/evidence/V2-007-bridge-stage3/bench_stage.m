function bench_stage(repo, outFile)
%BENCH_STAGE Windows benchmark matrix for the bridge on the published UI. Default scene only; no study stage runs.
cd(repo); addpath(fullfile(repo, 'v2', 'matlab'));
[~, h] = system('git rev-parse HEAD'); head = string(strtrim(h));
% UI Stage 3: three alternating rounds, then one paced run per setup.
plan = strings(0, 2);
for round = 1:3
    plan = [plan; ["UI_NULL" "0"]; ["UI_R100" "0"]; ["UI_R20" "0"]; ["H_R100" "0"]; ["H_R20" "0"]]; %#ok<AGROW>
end
plan = [plan; ["UI_NULL" "1"]; ["UI_R100" "1"]; ["UI_R20" "1"]];
for k = 1:size(plan, 1)
    c = plan(k, 1); rt = str2double(plan(k, 2));
    try
        R = mgv2PerfRun(c, RealTime=rt); R.run_index = k; R.real_time = rt; R.sha = head; R.finished = string(datetime);
        if ismissing(R.sha), R.sha = ""; end
        line = jsonencode(R);
        fprintf('%d %s rt=%g: x%.3f wall %.1f s worst %.0f ms\n', k, c, rt, R.sim_to_wall, R.wall_s, R.worst_block_ms);
    catch ME
        line = jsonencode(struct('run_index', k, 'cond', c, 'real_time', rt, 'error', string(ME.identifier), 'message', string(ME.message)));
        fprintf('%d %s rt=%g: ERROR %s\n', k, c, rt, ME.message);
    end
    fid = fopen(outFile, 'a'); fprintf(fid, '%s\n', line); fclose(fid);
end
disp('DONE');
end
