function tests = testV22Wording
%TESTV22WORDING V22-T10: standard wording, and no forbidden result words in any user-visible text of the v2_2 views.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'matlab')));
tc.TestData.root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function testStandardWordingSaysSuspectedAndSimulation(tc)
w = mgv22.wording();
verifySubstring(tc, w.suspected, "SIMULATION");
verifySubstring(tc, w.suspected, "suspected");
verifySubstring(tc, w.suspected, "indirect evidence");
verifySubstring(tc, w.suspected, "not for operational use");
for s = [w.suspected, w.scope, w.no_detection]
    verifyFalse(tc, any(arrayfun(@(f) contains(lower(s), f), w.forbidden)), s);
end
end

function testNoForbiddenWordInUserVisibleStrings(tc)
% every quoted string literal in v2_2/matlab is user-visible text or a message; comments are excluded
w = mgv22.wording(); bad = strings(0, 1);
files = dir(fullfile(tc.TestData.root, 'v2_2', 'matlab', '**', '*.m'));
for k = 1:numel(files)
    if files(k).name == "wording.m", continue; end
    lines = splitlines(string(fileread(fullfile(files(k).folder, files(k).name))));
    for i = 1:numel(lines)
        code = lines(i);
        if startsWith(strtrim(code), "%"), continue; end
        code = stripComment(code);
        lits = [regexp(code, '"([^"]*)"', 'tokens'), regexp(code, '(?<![\w\)\]\}''.])''([^'']*)''', 'tokens')];
        for j = 1:numel(lits)
            s = lower(string(lits{j}));
            for f = w.forbidden
                if ~isempty(regexp(s, "\<" + regexprep(f, '([\-])', '\\$1') + "\>", 'once'))
                    bad(end+1, 1) = files(k).name + ":" + i + " """ + lits{j} + """"; %#ok<AGROW>
                end
            end
        end
    end
end
verifyEmpty(tc, bad, strjoin(bad, newline));
end

function code = stripComment(code)
% drop a trailing % comment that is not inside a string literal (so comments cannot cause false failures)
c = char(code); inD = false; inS = false;
for k = 1:numel(c)
    ch = c(k);
    if ch == '"' && ~inS, inD = ~inD;
    elseif ch == '''' && ~inD && (inS || k == 1 || ~isempty(regexp(c(k-1), '[\s(,=\[{;:]', 'once'))), inS = ~inS;
    elseif ch == '%' && ~inD && ~inS, code = string(c(1:k-1)); return
    end
end
end
