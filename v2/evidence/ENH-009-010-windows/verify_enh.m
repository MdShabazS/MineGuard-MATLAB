function verify_enh(root, tag, out)
%VERIFY_ENH Exact-SHA functional checks of ENH-009 and, when present, ENH-010. Base graphics only.
p = strsplit(path, pathsep);
for k = 1:numel(p), if contains(p{k}, ["MineGuard-V2", "MineGuard-ENH-verify"]), rmpath(p{k}); end, end
clear mgenh009.renderOfflineCampusContext
addpath(fullfile(root, 'v2', 'enhancements'));
if ~isfolder(out), mkdir(out); end
fid = fopen(fullfile(out, tag + "_results.txt"), 'w'); c = onCleanup(@() fclose(fid));
[~, h] = system(sprintf('git -C "%s" rev-parse HEAD', root)); [~, st] = system(sprintf('git -C "%s" status --short', root));
log(fid, 'SHA %s clean=%d desktop=%d %s', strtrim(h), isempty(strtrim(st)), usejava('desktop'), version);
has10 = isfolder(fullfile(root, 'v2', 'enhancements', '+mgenh010'));

suites = "testENH009OfflineContext"; if has10, suites(end+1) = "testENH010Storyboard"; end
for s = suites
    r = runtests(fullfile(root, 'v2', 'enhancements', 'tests', s + ".m"));
    log(fid, '%s run=%d pass=%d fail=%d incomplete=%d', s, numel(r), nnz([r.Passed]), nnz([r.Failed]), nnz([r.Incomplete]));
    for b = r([r.Failed] | [r.Incomplete]), log(fid, '  NOTPASS %s', b.Name); end
end
for f = dir(fullfile(root, 'v2', 'enhancements', '**', '*.m'))'
    I = checkcode(fullfile(f.folder, f.name)); log(fid, 'checkcode %s: %d', f.name, numel(I));
    for i = I', log(fid, '  L%d %s', i.line, i.message); end
end

% asset fallback
missing = [tempname '.png']; bad = [tempname '.png']; w = fopen(bad, 'w'); fwrite(w, uint8('NOT-A-PNG')); fclose(w);
good = [tempname '.png']; imwrite(uint8(255 * ones(8, 8, 3)), good); before = fileread(bad);
cases = {'' 'NOT_REQUESTED'; missing 'MISSING_SCHEMATIC_USED'; bad 'PRESENT_NOT_APPROVED_SCHEMATIC_USED'; good 'PRESENT_NOT_APPROVED_SCHEMATIC_USED'; tempdir 'MISSING_SCHEMATIC_USED'};
for k = 1:size(cases, 1)
    [f, i] = mgenh009.renderOfflineCampusContext('Visible', 'off', 'AssetPath', cases{k, 1});
    log(fid, 'asset case %d expected=%s got=%s images=%d rectangles=%d georef=%d', k, cases{k, 2}, i.asset_status, numel(findall(f, 'Type', 'image')), numel(findall(f, 'Type', 'rectangle')), i.georeferenced);
    close(f);
end
log(fid, 'corrupt asset unchanged=%d', isequal(before, fileread(bad))); delete(bad); delete(good);

% repeated initialisation and cleanup
f0 = numel(findall(groot, 'Type', 'figure')); t0 = numel(timerfindall); m0 = memory; T = zeros(60, 1);
for k = 1:60
    t = tic; [f, ~] = mgenh009.renderOfflineCampusContext('Visible', 'off'); drawnow; close(f); T(k) = toc(t);
    if has10
        for st2 = ["CITY_CONTEXT", "CAMPUS_CONTEXT", "SIMULATION_HANDOFF"], [f, ~] = mgenh010.renderStoryboardFrame(st2, 'Visible', 'off'); close(f); end
    end
end
m1 = memory; log(fid, 'repeat 60: figures delta=%d timers delta=%d memory delta MB=%.1f render median ms=%.1f max ms=%.1f', numel(findall(groot, 'Type', 'figure')) - f0, numel(timerfindall) - t0, (m1.MemUsedMATLAB - m0.MemUsedMATLAB) / 1e6, 1e3 * median(T), 1e3 * max(T));

% offline: shadow the network and imagery functions, and watch this process's TCP connections
sd = tempname; mkdir(sd); calls = fullfile(sd, 'calls.txt');
for n = ["webread", "websave", "webwrite", "urlread", "urlwrite", "geobasemap", "readBasemapImage", "imread", "geoaxes", "system", "timer"]
    w = fopen(fullfile(sd, n + ".m"), 'w');
    fprintf(w, 'function varargout = %s(varargin)\nw = fopen(''%s'', ''a''); fprintf(w, ''%s\\n''); fclose(w); error(''offline:Blocked'', ''%s blocked'');\nend\n', n, strrep(calls, '\', '\\'), n, n); fclose(w);
end
tcp = @() tcpCount();
a = tcp(); addpath(sd); cl = onCleanup(@() rmpath(sd));
err = "";
try
    [f, ~] = mgenh009.renderOfflineCampusContext('Visible', 'off', 'AssetPath', missing); drawnow; close(f);
    if has10
        s = mgenh010.advanceStoryboard([], "RESET");
        for k = 1:3, [f, ~] = mgenh010.renderStoryboardFrame(s, 'Visible', 'off'); drawnow; close(f); s = mgenh010.advanceStoryboard(s, "NEXT"); end
    end
catch ME, err = string(ME.identifier);
end
rmpath(sd); log(fid, 'offline shadow: blocked calls=%d error="%s"', isfile(calls), err); b = tcp();
log(fid, 'process TCP connections before=%d after=%d (not an OS network-denied run)', a, b);

% visual: screenshots, text fit and contrast in both themes
jobs = {"ENH009_schematic", @() mgenh009.renderOfflineCampusContext('Visible', 'off')};
if has10
    s = ["CITY_CONTEXT", "CAMPUS_CONTEXT", "SIMULATION_HANDOFF"];
    for k = 1:3, x = s(k); jobs(end+1, :) = {"ENH010_" + x, @() mgenh010.renderStoryboardFrame(x, 'Visible', 'off')}; end %#ok<AGROW>
    x = "CITY_CONTEXT"; y = mgenh010.advanceStoryboard(x, "NEXT"); z = mgenh010.advanceStoryboard(y, "NEXT");
    log(fid, 'state walk %s>%s>%s>%s back=%s reset=%s', x, y, z, mgenh010.advanceStoryboard(z, "NEXT"), mgenh010.advanceStoryboard(z, "BACK"), mgenh010.advanceStoryboard(z, "RESET"));
end
for k = 1:size(jobs, 1)
    for th = ["light", "dark"]
        [f, i] = jobs{k, 2}(); theme(f, th); drawnow;
        exportgraphics(f, fullfile(out, tag + "_" + jobs{k, 1} + "_" + th + ".png"), 'Resolution', 110);
        ax = findall(f, 'Type', 'axes');
        for tx = findall(f, 'Type', 'text')'
            if strlength(string(tx.String)) == 0, continue; end
            e = tx.Extent; xl = ax(1).XLim; card = [xl(1) + 0.03 * diff(xl), xl(2) - 0.03 * diff(xl)];
            bg = cardColour(f);
            log(fid, '%s %s text "%s" extent x=[%.3f %.3f] of card [%.3f %.3f] fits=%d contrast=%.2f', jobs{k, 1}, th, extractBefore(string(tx.String) + "                                ", 32), e(1), e(1) + e(3), card(1), card(2), e(1) >= card(1) && e(1) + e(3) <= card(2), contrast(tx.Color, bg));
        end
        for tb = findall(f, 'Type', 'textboxshape')', log(fid, '%s %s banner "%s" contrast=%.2f against figure', jobs{k, 1}, th, string(tb.String), contrast(tb.Color, f.Color)); end
        close(f); %#ok<NASGU>
        if isfield(i, 'stage'), end
    end
end
log(fid, 'DONE');
end

function n = tcpCount()
[~, o] = builtin('system', sprintf('powershell -NoProfile -Command "(Get-NetTCPConnection -OwningProcess %d -State Established -ErrorAction SilentlyContinue | Where-Object RemoteAddress -notin ''127.0.0.1'',''::1'').Count"', feature('getpid')));
n = str2double(strtrim(o)); if isnan(n), n = 0; end
end

function c = cardColour(f)
r = findall(f, 'Type', 'rectangle'); c = r(end).FaceColor;
end

function r = contrast(a, b)
L = @(c) sum([0.2126 0.7152 0.0722] .* ((c <= 0.03928) .* c / 12.92 + (c > 0.03928) .* ((c + 0.055) / 1.055) .^ 2.4));
x = sort([L(a) L(b)], 'descend'); r = (x(1) + 0.05) / (x(2) + 0.05);
end

function log(fid, varargin)
fprintf(fid, varargin{:}); fprintf(fid, '\n');
end
