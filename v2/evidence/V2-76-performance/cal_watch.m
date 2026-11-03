function cal_watch(tag, seconds)
%CAL_WATCH Sample a small project-free workload with timestamps, to a CSV. Uses little CPU between samples.
here = fileparts(mfilename('fullpath')); f = fullfile(here, 'logs-perf', "watch_" + tag + ".csv");
fid = fopen(f, 'w'); fprintf(fid, 't_utc,loop_ms,map_ms\n'); t0 = tic;
while toc(t0) < seconds
    a = tic; s = 0; for k = 1:5e5, s = s + mod(k, 7) * 0.5; end, l = 1e3 * toc(a); if s < 0, disp(s); end
    a = tic; m = containers.Map('KeyType', 'double', 'ValueType', 'any'); for k = 1:1500, m(k) = k; end, q = 1e3 * toc(a);
    fprintf(fid, '%s,%.2f,%.2f\n', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'HH:mm:ss')), l, q); pause(2);
end
fclose(fid);
end
