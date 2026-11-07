% Fresh MATLAB process: same calibration and H_NULL mission as the MCP session, for comparison. Default scene only.
here = fileparts(mfilename('fullpath')); repo = fullfile(here, 'clean-perf'); addpath(here); cd(repo); addpath(fullfile(repo, 'v2', 'matlab'));
c0 = cal2(); m0 = memory;
R = mgv2PerfRun("H_NULL");
c1 = cal2(); m1 = memory;
fid = fopen(fullfile(here, 'logs-perf', 'fresh_process.jsonl'), 'a');
fprintf(fid, '%s\n', jsonencode(struct('where', "fresh matlab -batch", 'cal_before', c0, 'cal_after', c1, 'mem_before_MB', m0.MemUsedMATLAB / 1e6, 'mem_after_MB', m1.MemUsedMATLAB / 1e6, 'run', R))); fclose(fid);
