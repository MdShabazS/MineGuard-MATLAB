function f = listFiles(folder)
%LISTFILES Package-relative paths (forward slashes) of every file under folder except files.sha256, sorted.
%   f = mgv2.run.listFiles(folder)
d = dir(fullfile(folder, '**', '*')); d = d(~[d.isdir]);
f = strings(numel(d), 1); base = string(folder);
for k = 1:numel(d)
    p = string(fullfile(d(k).folder, d(k).name));
    f(k) = replace(extractAfter(p, strlength(base) + 1), "\", "/");
end
f = sort(f(f ~= "files.sha256"));
end
