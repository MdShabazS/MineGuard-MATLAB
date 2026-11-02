% One fresh desktop process through a sequence of missions; calibration between each. No study stage, no TEST.
here = fileparts(mfilename('fullpath')); repo = fullfile(here, 'clean-perf'); addpath(here); cd(repo); addpath(fullfile(repo, 'v2', 'matlab'));
fid = fopen(fullfile(here, 'logs-perf', 'seq_process.jsonl'), 'a');
log1 = @(s) fprintf(fid, '%s\n', jsonencode(s));
seq = ["H_NULL","UI_NULL","UI_NULL","UI_NULL","H_NULL"];
try
    m = memory; log1(struct('step', "start", 'cal', cal2(), 'mem_MB', m.MemUsedMATLAB / 1e6, 'jvm_MB', javaUsed()));
    for k = 1:numel(seq)
        R = mgv2PerfRun(seq(k)); m = memory; drawnow;
        log1(struct('step', seq(k), 'n', k, 'sim_to_wall', R.sim_to_wall, 'wall_s', R.wall_s, 'worst_ms', R.worst_block_ms, 'startup_s', R.startup_s, 'cal', cal2(), 'mem_MB', m.MemUsedMATLAB / 1e6, 'jvm_MB', javaUsed(), 'graphics', numel(findall(groot))));
    end
catch err
    log1(struct('error', err.message, 'id', err.identifier));
end
fclose(fid); exit
function v = javaUsed(), r = java.lang.Runtime.getRuntime; v = (r.totalMemory - r.freeMemory) / 1e6; end
