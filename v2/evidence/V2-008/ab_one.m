function ab_one(repo, tag, out)
%AB_ONE One paced UI_R100 mission from one tree, appended as a JSON line. Used to compare V2-007 and V2-008 code.
cd(repo); addpath(fullfile(repo, 'v2', 'matlab'));
[~, h] = system('git rev-parse --short HEAD');
pause(20);                                       % let the desktop settle, as run_bench does
R = mgv2PerfRun("UI_R100", RealTime=1);
R.tag = string(tag); R.sha = strtrim(string(h)); R.started_after_s = 20;
fid = fopen(out, 'a'); fprintf(fid, '%s\n', jsonencode(R)); fclose(fid);
end
