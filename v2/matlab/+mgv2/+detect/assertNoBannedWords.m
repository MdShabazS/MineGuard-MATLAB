function assertNoBannedWords(x, where)
%ASSERTNOBANNEDWORDS Throw mgv2:BannedWording if any text in x uses a banned certainty word (SC-22).
%   mgv2.detect.assertNoBannedWords(x, where)    x: struct / cell / string / char (scanned recursively)
%   Whole-word, case-insensitive match against mgv2.detect.contract().banned_words (safe, cleared, clearance,
%   confirmed, mine-free, hazard-free, "probability of"). Words such as "safety" or "unconfirmed" do not match.
if nargin < 2, where = "record"; end
bad = mgv2.detect.contract().banned_words;
scan(x, string(where));
    function scan(v, path)
        if isstruct(v)
            f = fieldnames(v);
            for k = 1:numel(v), for q = 1:numel(f), scan(v(k).(f{q}), path + "." + f{q}); end, end
        elseif iscell(v)
            for k = 1:numel(v), scan(v{k}, path + "{" + k + "}"); end
        elseif isstring(v) || ischar(v)
            t = lower(strjoin(string(v), " "));
            for b = bad
                if ~isempty(regexp(t, "(?<![a-z-])" + regexptranslate('escape', b) + "(?![a-z-])", 'once'))
                    error('mgv2:BannedWording', '%s: banned wording "%s".', path, b);
                end
            end
        end
    end
end
